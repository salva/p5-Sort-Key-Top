/* -*- Mode: C -*- */

#define PERL_NO_GET_CONTEXT 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#if (PERL_VERSION < 7)
#include "sort.h"
#endif

#define INSERTION_CUTOFF 6

static I32
ix_sv_cmp(pTHX_ SV **a, SV **b) {
    int r = sv_cmp(*a, *b);
    return r ? r : a < b ? -1 : 1;
}

static I32
ix_rsv_cmp(pTHX_ SV **a, SV **b) {
    int r = sv_cmp(*b, *a);
    return r ? r : a < b ? -1 : 1;
}

static I32
ix_lsv_cmp(pTHX_ SV **a, SV **b) {
    int r = sv_cmp_locale(*a, *b);
    return r ? r : a < b ? -1 : 1;
}

static I32
ix_rlsv_cmp(pTHX_ SV **a, SV **b) {
    int r = sv_cmp_locale(*b, *a);
    return r ? r : a < b ? -1 : 1;
}

static I32
ix_n_cmp(pTHX_ NV *a, NV *b) {
    NV nv1 = *a;
    NV nv2 = *b;
    return nv1 < nv2 ? -1 : nv1 > nv2 ? 1 : a < b ? -1 : 1;
}

static I32
ix_rn_cmp(pTHX_ NV *a, NV *b) {
    NV nv1 = *b;
    NV nv2 = *a;
    return nv1 < nv2 ? -1 : nv1 > nv2 ? 1 : a < b ? -1 : 1;
}

static I32
ix_i_cmp(pTHX_ IV *a, IV *b) {
    IV iv1 = *a;
    IV iv2 = *b;
    return iv1 < iv2 ? -1 : iv1 > iv2 ? 1 : a < b ? -1 : 1;
}

static I32
ix_ri_cmp(pTHX_ IV *a, IV *b) {
    IV iv1 = *b;
    IV iv2 = *a;
    return iv1 < iv2 ? -1 : iv1 > iv2 ? 1 : a < b ? -1 : 1;
}

static I32
ix_u_cmp(pTHX_ UV *a, UV *b) {
    UV uv1 = *a;
    UV uv2 = *b;
    return uv1 < uv2 ? -1 : uv1 > uv2 ? 1 : a < b ? -1 : 1;
}

static I32
ix_ru_cmp(pTHX_ UV *a, UV *b) {
    UV uv1 = *b;
    UV uv2 = *a;
    return uv1 < uv2 ? -1 : uv1 > uv2 ? 1 : a < b ? -1 : 1;
}

static void *v_alloc(pTHX_ IV n, IV lsize) {
    void *r;
    Newxc(r, n<<lsize, char, void);
    SAVEFREEPV(r);
    return r;
}

static void *av_alloc(pTHX_ IV n, IV lsize) {
    AV *av=(AV*)sv_2mortal((SV*)newAV());
    av_fill(av, n-1);
    return AvARRAY(av);
}

static void i_store(pTHX_ SV *v, void *to) {
    *((IV*)to) = SvIV(v);
}

static void u_store(pTHX_ SV *v, void *to) {
    *((UV*)to) = SvUV(v);
}

static void n_store(pTHX_ SV *v, void *to) {
    *((NV*)to) = SvNV(v);
}

static void sv_store(pTHX_ SV *v, void *to) {
    *((SV**)to) = SvREFCNT_inc(v);
}

#define lsizeof(A) (ilog2(sizeof(A)))

static int ilog2(int i) {
    if (i > 256) croak("internal error");
    if (i > 128) return 8;
    if (i >  64) return 7;
    if (i >  32) return 6;
    if (i >  16) return 5;
    if (i >   8) return 4;
    if (i >   4) return 3;
    if (i >   2) return 2;
    if (i >   1) return 1;
    return 0;
}

typedef I32 (*COMPARE_t)(pTHX_ void*, void*);
typedef void (*STORE_t)(pTHX_ SV*, void*);

I32
_keytop(pTHX_ IV type, SV *keygen, IV top, int sort, I32 offset, IV items, I32 ax) {
    int warray = (GIMME_V == G_ARRAY);
    int deep = (sort && !warray) ? 1 : 0;
    int dir = 1;

    if (top == 0)
        return 0;

    if (top < 0) {
        dir = -1;
        top = -top;
    }

    if (top > items) {
        if (warray)
            top = items;
        else
            return 0;
    }

    if (items == 1) {
        ST(0) = ST(offset);
        return 1;
    }

    if (top < items || sort) {
        dSP;
        void *keys;
        void **ixkeys;
        SV *old_defsv;
        U32 lsize;
        COMPARE_t cmp;
        STORE_t store;
        int already_sorted = 0;

        switch (type) {
        case 0:
            cmp = (COMPARE_t)&ix_sv_cmp;
            lsize = lsizeof(SV*);
            keys = av_alloc(aTHX_ items, lsize);
            store = &sv_store;
            break;
	case 1:
	    cmp = (COMPARE_t)&ix_lsv_cmp;
	    lsize = lsizeof(SV*);
	    keys = av_alloc(aTHX_ items, lsize);
	    store = &sv_store;
	    break;
	case 2:
	    cmp = (COMPARE_t)&ix_n_cmp;
	    lsize = lsizeof(NV);
	    keys = v_alloc(aTHX_ items, lsize);
	    store = &n_store;
	    break;
	case 3:
	    cmp = (COMPARE_t)&ix_i_cmp;
	    lsize = lsizeof(IV);
	    keys = v_alloc(aTHX_ items, lsize);
	    store = &i_store;
	    break;
	case 4:
	    cmp = (COMPARE_t)&ix_u_cmp;
	    lsize = lsizeof(UV);
	    keys = v_alloc(aTHX_ items, lsize);
	    store = &u_store;
	    break;
	case 128:
	    cmp = (COMPARE_t)&ix_rsv_cmp;
	    lsize = lsizeof(SV*);
	    keys = av_alloc(aTHX_ items, lsize);
	    store = &sv_store;
	    break;
	case 129:
	    cmp = (COMPARE_t)&ix_rlsv_cmp;
	    lsize = lsizeof(SV*);
	    keys = av_alloc(aTHX_ items, lsize);
	    store = &sv_store;
	    break;
	case 130:
	    cmp = (COMPARE_t)&ix_rn_cmp;
	    lsize = lsizeof(NV);
	    keys = v_alloc(aTHX_ items, lsize);
	    store = &n_store;
	    break;
	case 131:
	    cmp = (COMPARE_t)&ix_ri_cmp;
	    lsize = lsizeof(IV);
	    keys = v_alloc(aTHX_ items, lsize);
	    store = &i_store;
	    break;
	case 132:
	    cmp = (COMPARE_t)&ix_ru_cmp;
	    lsize = lsizeof(UV);
	    keys = v_alloc(aTHX_ items, lsize);
	    store = &u_store;
	    break;
        default:
            croak("unsupported type %d", type);
        }
        Newx(ixkeys, items, void*);
        SAVEFREEPV(ixkeys);
        if (keygen) {
            I32 i;
            old_defsv = DEFSV;
            SAVE_DEFSV;
            for (i = 0; i<items; i++) {
                I32 count;
                SV *current;
                SV *result;
                void *target;
                ENTER;
                SAVETMPS;
                current = ST(i + offset);
                DEFSV = current ? current : sv_newmortal();
                PUSHMARK(SP);
                PUTBACK;
                count = call_sv(keygen, G_SCALAR);
                SPAGAIN;
                if (count != 1)
                    croak("wrong number of results returned from key generation sub");
                result = POPs;
                ixkeys[i] = target = ((char*)keys) + (i << lsize);
                (*store)(aTHX_ result, target);
                FREETMPS;
                LEAVE;
            }
            DEFSV = old_defsv;
        }
        else {
            I32 i;
            for (i=0; i<items; i++) {
                void *target;
                SV *current = ST(i+offset);
                ixkeys[i] = target = ((char*)keys)+(i<<lsize);
                (*store)(aTHX_
                         current ? current : sv_newmortal(),
                         target);
            }
        }

        if (top == 1) {
            I32 min = 0;
            I32 i;
            for (i = 1; i < items; i++) {
                if (cmp(aTHX_ ixkeys[min], ixkeys[i]) == dir)
                    min = i;
            }
            ST(0) = ST(offset + min);
            return 1;
        }
        
        if (top < items || deep) {

            if (top <= INSERTION_CUTOFF) {
                I32 n, i, j;
                void *current;

                for (n = i = 1; i < items; i++) {
                    current = ixkeys[i];
                    for (j = n; j; j--) {
                        /*
                          printf ("n: %d, i: %d, j: %d, cmp: %d, dir: %d, key: %s, current: %s\n",
                          n, i, j,
                          cmp(aTHX_ ixkeys[j - 1], current), dir,
                          SvPV_nolen(*((SV**)(ixkeys[j - 1]))),
                          SvPV_nolen(*((SV**)current)) );
                          {
                          int k;
                          for (k = 0; k < items; k++) {
                          printf("%s ", (k == j ? "*" : SvPV_nolen(*((SV**)(ixkeys[k])))));
                          }
                          printf("\n"); fflush(stdout);
                          
                          }
                        */
                        if (cmp(aTHX_ ixkeys[j - 1], current) != dir)
                            break;

                        if (j < top)
                            ixkeys[j] = ixkeys[j - 1];
                    }
                    if (j < top) {
                        ixkeys[j] = current;
                        if (n < top)
                            n++;
                    }
                }

                /* if (dir < 0) {
                    I32 i, j;
                    for (i = 0, j = top - 1; i < j; i++, j--) {
                        void *swap = ixkeys[i];
                        ixkeys[i] = ixkeys[j];
                        ixkeys[j] = swap;
                    }
                }
                */

                if (dir == 1)
                    already_sorted = 1;
                
            }
            else {
                I32 left = 0;
                I32 right = items - 1;

                while (1) {
                    I32 pivot = (left + right) >> 1;
                    void *pivot_value = ixkeys[pivot];
                    I32 i;

                    SV *out = sv_newmortal();
                    /*
                      sv_catpvf(out, "left: %d, right: %d, pivot: %d, pivot_value: %s =>", left, right, pivot, SvPV_nolen(*(SV**)pivot_value));
                      for (i = 0; i< items; i++) {
                      sv_catpvf(out, " %s", SvPV_nolen(*(SV**)(ixkeys[i])));
                      }
                      fprintf(stderr, "%s\n", SvPV_nolen(out));
                    */
                
                    ixkeys[pivot] = ixkeys[right];
                    for (pivot = i = left; i < right; i++) {
                        if (cmp(aTHX_ ixkeys[i], pivot_value) != dir) {
                            void *swap = ixkeys[i];
                            ixkeys[i] = ixkeys[pivot];
                            ixkeys[pivot] = swap;
                            pivot++;
                        }
                    }
                    ixkeys[right] = ixkeys[pivot];
                    ixkeys[pivot] = pivot_value;
                    if (deep) {
                        if (pivot >= top)
                            right = pivot - 1;
                        else {
                            if (pivot == top - 1)
                                break;
                            left = pivot + 1;
                        }
                    }
                    else {
                        if (pivot >= top) {
                            /* fprintf(stderr, "%d >= %d\n", pivot, top); */
                            right = pivot - 1;
                            if (right < top)
                                break;
                        }
                        if (pivot <= top) {
                            /* fprintf(stderr, "%d <= %d\n", pivot, top); */
                            left = pivot + 1;
                            if (left >= top)
                                break;
                        }
                    }
                }
            }
            if (!sort) {
                if (warray) {
                    I32 to, i;
                    unsigned char *bitmap;
                    Newxz(bitmap, (items / 8) + 1, unsigned char);
                    SAVEFREEPV(bitmap);
                    for (i = 0; i < top; i++) {
                        I32 j = ( ((char*)(ixkeys[i])) - ((char*)keys) ) >> lsize;
                        bitmap[j / 8] |= (1 << (j & 7));
                    }
                    for (to = i = 0; to < top; i++) {
                        if (bitmap[i / 8] & (1 << (i & 7))) {
                            /* fprintf(stderr, "to: %d => i: %d\n", to, i); */
                            ST(to++) = ST(i+offset);
                        }
                    }
                    return top;
                }
                else {
                    I32 last, i;
                    for (i = 0, last = 0; i < top; i++) {
                        I32 j = ( ((char*)(ixkeys[i])) - ((char*)keys) ) >> lsize;
                        if (j > last)
                            last = j;
                    }
                    ST(0) = ST(offset + last);
                    return 1;
                }
            }
        }

        if (sort) {
            if (warray) {
                I32 i;
                if (!already_sorted)
                    sortsv((SV**)ixkeys, top, (SVCOMPARE_t)cmp);
                for(i = 0; i < top; i++) {
                    I32 j = ( ((char*)(ixkeys[i])) - ((char*)keys) ) >> lsize;
                    /* fprintf(stderr, "i: %d => j: %d\n", i, j); */
                    ixkeys[i] = ST(j + offset);
                }
                for(i = 0; i < top; i++) {
                    ST(i) = (SV*)ixkeys[i];
                }
            }
            else {
                I32 j = ( ((char*)(ixkeys[top - 1])) - ((char*)keys) ) >> lsize;
                ST(0) = ST(offset + j);
                return 1;
            }
        }
        return top;
    }
    else {
        I32 i;
        for (i = 0; i < top; i++)
            ST(i) = ST(i + offset);
        return items;
    }
}


MODULE = Sort::Key::Top		PACKAGE = Sort::Key::Top		
PROTOTYPES: ENABLE

void
keytop(SV *keygen, IV top, ...)
PROTOTYPE: &@
ALIAS:
        lkeytop = 1
        nkeytop = 2
        ikeytop = 3
        ukeytop = 4
        rkeytop = 128
        rlkeytop = 129
        rnkeytop = 130
        rikeytop = 131
        rukeytop = 132
PPCODE:
        XSRETURN(_keytop(aTHX_ ix, keygen, top, 0, 2, items-2, ax));

void
top(IV top, ...)
PROTOTYPE: @
ALIAS:
        ltop = 1
        ntop = 2
        itop = 3
        utop = 4
        rtop = 128
        rltop = 129
        rntop = 130
        ritop = 131
        rutop = 132
PPCODE:
        XSRETURN(_keytop(aTHX_ ix, 0, top, 0, 1, items-1, ax));

void
keytopsort(SV *keygen, IV top, ...)
PROTOTYPE: &@
ALIAS:
        lkeytopsort = 1
        nkeytopsort = 2
        ikeytopsort = 3
        ukeytopsort = 4
        rkeytopsort = 128
        rlkeytopsort = 129
        rnkeytopsort = 130
        rikeytopsort = 131
        rukeytopsort = 132
PPCODE:
        XSRETURN(_keytop(aTHX_ ix, keygen, top, 1, 2, items-2, ax));

void
topsort(IV top, ...)
PROTOTYPE: @
ALIAS:
        ltopsort = 1
        ntopsort = 2
        itopsort = 3
        utopsort = 4
        rtopsort = 128
        rltopsort = 129
        rntopsort = 130
        ritopsort = 131
        rutopsort = 132
PPCODE:
        XSRETURN(_keytop(aTHX_ ix, 0, top, 1, 1, items-1, ax));

