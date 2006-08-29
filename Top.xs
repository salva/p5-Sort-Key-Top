/* -*- Mode: C -*- */

#define PERL_NO_GET_CONTEXT 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#if (PERL_VERSION < 7)
#include "sort.h"
#endif

static I32
ix_sv_cmp(pTHX_ SV **a, SV **b) {
    return sv_cmp(*a, *b);
}

static I32
ix_rsv_cmp(pTHX_ SV **a, SV **b) {
    return sv_cmp(*b, *a);
}

static I32
ix_lsv_cmp(pTHX_ SV **a, SV **b) {
    return sv_cmp_locale(*a, *b);
}

static I32
ix_rlsv_cmp(pTHX_ SV **a, SV **b) {
    return sv_cmp_locale(*b, *a);
}

static I32
ix_n_cmp(pTHX_ NV *a, NV *b) {
    NV nv1 = *a;
    NV nv2 = *b;
    return nv1 < nv2 ? -1 : nv1 > nv2 ? 1 : 0;
}

static I32
ix_rn_cmp(pTHX_ NV *a, NV *b) {
    NV nv1 = *b;
    NV nv2 = *a;
    return nv1 < nv2 ? -1 : nv1 > nv2 ? 1 : 0;
}

static I32
ix_i_cmp(pTHX_ IV *a, IV *b) {
    IV iv1 = *a;
    IV iv2 = *b;
    return iv1 < iv2 ? -1 : iv1 > iv2 ? 1 : 0;
}

static I32
ix_ri_cmp(pTHX_ IV *a, IV *b) {
    IV iv1 = *b;
    IV iv2 = *a;
    return iv1 < iv2 ? -1 : iv1 > iv2 ? 1 : 0;
}

static I32
ix_u_cmp(pTHX_ UV *a, UV *b) {
    UV uv1 = *a;
    UV uv2 = *b;
    return uv1 < uv2 ? -1 : uv1 > uv2 ? 1 : 0;
}

static I32
ix_ru_cmp(pTHX_ UV *a, UV *b) {
    UV uv1 = *b;
    UV uv2 = *a;
    return uv1 < uv2 ? -1 : uv1 > uv2 ? 1 : 0;
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
    *((IV*)to)=SvIV(v);
}

static void u_store(pTHX_ SV *v, void *to) {
    *((UV*)to)=SvUV(v);
}

static void n_store(pTHX_ SV *v, void *to) {
    *((NV*)to)=SvNV(v);
}

static void sv_store(pTHX_ SV *v, void *to) {
    *((SV**)to)=SvREFCNT_inc(v);
}

#define lsizeof(A) (ilog2(sizeof(A)))

static int ilog2(int i) {
    if (i>256) croak("internal error");
    if (i>128) return 8;
    if (i>64) return 7;
    if (i>32) return 6;
    if (i>16) return 5;
    if (i>8) return 4;
    if (i>4) return 3;
    if (i>2) return 2;
    if (i>1) return 1;
    return 0;
}

typedef I32 (*COMPARE_t)(pTHX_ void*, void*);
typedef void (*STORE_t)(pTHX_ SV*, void*);

I32
_keytop(pTHX_ IV type, SV *keygen, IV top, int sort, I32 offset, IV items, I32 ax) {
    if (top < 0) top = 0;
    if (top > items) top = items;
    if (top < 2) sort = 0;

    if (top < items || sort) {
        dSP;
        I32 left, right;
        void *keys;
        void **ixkeys;
        SV *old_defsv;
        U32 lsize;
        COMPARE_t cmp;
        STORE_t store;

        switch(type) {
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

        if (top < items) {
            left = 0;
            right = items - 1;
            while (right > left) {
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
                    int r = cmp(aTHX_ ixkeys[i], pivot_value);
                    if (r < 0 || ((r == 0) && (ixkeys[i] < pivot_value))) {
                        void *swap = ixkeys[i];
                        ixkeys[i] = ixkeys[pivot];
                        ixkeys[pivot] = swap;
                        pivot++;
                    }
                }
                ixkeys[right] = ixkeys[pivot];
                ixkeys[pivot] = pivot_value;

                if (pivot >= top) {
                    /* fprintf(stderr, "%d >= %d\n", pivot, top); */
                    right = pivot - 1;
                }
                if (pivot <= top) {
                    /* fprintf(stderr, "%d <= %d\n", pivot, top); */
                    left = pivot + 1;
                }
            }
            {
                I32 i;
                unsigned char *bitmap;
                Newxz(bitmap, (items / 8) + 1, unsigned char);
                SAVEFREEPV(bitmap);
                for (i = 0; i < top; i++) {
                    I32 j = ( ((char*)(ixkeys[i])) - ((char*)keys) ) >> lsize;
                    bitmap[j / 8] |= (1 << (j & 7));
                }
                if (sort) {
                    I32 to;
                    for (to = i = 0; to < top; i++) {
                        if (bitmap[i / 8] & (1 << (i & 7))) {
                            /* fprintf(stderr, "to: %d => i: %d\n", to, i); */
                            ixkeys[to++] = ((char *)keys) + (i << lsize);
                        }
                    }
                }
                else {
                    I32 to;
                    for (to = i = 0; to < top; i++) {
                        if (bitmap[i / 8] & (1 << (i & 7))) {
                            /* fprintf(stderr, "to: %d => i: %d\n", to, i); */
                            ST(to++) = ST(i+offset);
                        }
                    }
                }
            }
        }
        if (sort) {
            I32 i;
            /*
              for(i = 0; i < top; i++) {
              I32 j = ( ((char*)(ixkeys[i])) - ((char*)keys) ) >> lsize;
              fprintf(stderr, "i: %d => j: %d\n", i, j);
              }
            */
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
        return top;

    }
    else {
        I32 i;
        for (i = 0; i < items; i++)
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

