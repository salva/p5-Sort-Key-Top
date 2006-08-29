package Sort::Key::Top;

our $VERSION = '0.01';

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw( top
                     ltop
                     ntop
                     itop
                     utop
                     rtop
                     rltop
                     rntop
                     ritop
                     rutop
                     keytop
                     lkeytop
                     nkeytop
                     ikeytop
                     ukeytop
                     rkeytop
                     rlkeytop
                     rnkeytop
                     rikeytop
                     rukeytop
                     topsort
                     ltopsort
                     ntopsort
                     itopsort
                     utopsort
                     rtopsort
                     rltopsort
                     rntopsort
                     ritopsort
                     rutopsort
                     keytopsort
                     lkeytopsort
                     nkeytopsort
                     ikeytopsort
                     ukeytopsort
                     rkeytopsort
                     rlkeytopsort
                     rnkeytopsort
                     rikeytopsort
                     rukeytopsort );





require XSLoader;
XSLoader::load('Sort::Key::Top', $VERSION);

1;
__END__

=head1 NAME

Sort::Key::Top - select and sort top n elements

=head1 SYNOPSIS

  use Sort::Key::Top (nkeytop top);

  # select 5 first numbers by absolute value:
  @top = nkeytop { abs $_ } 5 => 1, 2, 7, 5, 5, 1, 78, 0, -2, -8, 2;
         # ==> @top = (1, 2, 1, 0, -2)

  # select 5 first words by lexicographic order:
  @a = qw(cat fish bird leon penguin horse rat elephant squirrel dog);
  @top = top 5 => @a;
         # ==> @top = qw(cat fish bird elephant dog);

=head1 DESCRIPTION

The functions available from this module select the top n elements from a list
using several common orderings and custom key extraction procedures.

They are all variations around

  keytopsort { CALC_KEY($_) } $n => @data;

This function calculates the ordering key for every element in
C<@data> using the expression inside the block. Then it selects and
orders the C<$n> elements with the lower keys when compared
lexicographically.

It is equivalent to the pure Perl expression:

  (sort { CALC_KEY($a) cmp CALC_KEY($b) } @data)[0 .. $n-1];

Variations allow to:

=over 4

=item - use the own values as the ordering keys

  topsort 5 => qw(a b ab t uu g h aa aac);

     ==> a aa aac ab b


=item - return the selected values in the original order

  top 5 => qw(a b ab t uu g h aa aac);

     ==> a b ab aa aac


=item - use a different ordering

For instance comparing the keys as numbers, using the locale
configuration or in reverse order:

  rnkeytop { length $_ } 3 => qw(a ab aa aac b t uu g h);

     ==> ab aa aac

  rnkeytopsort { length $_ } 3 => qw(a ab aa aac b t uu g h);

     ==> aac ab aa


A prefix is used to indicate the required ordering:

=over 4

=item (no prefix)

lexicographical ascending order

=item r

lexicographical descending order

=item l

lexicographical ascending order obeying locale configuration

=item r

lexicographical descending order obeying locale configuration

=item n

numerical ascending order

=item rn

numerical descending order

=item i

numerical ascending order but converting the keys to integers first

=item ri

numerical descending order but converting the keys to integers first

=item u

numerical ascending order but converting the keys to unsigned integers first

=item ru

numerical descending order but converting the keys to unsigned integers first

=back



=back

The full list of available functions is:

  top ltop ntop itop utop rtop rltop rntop ritop rutop

  keytop lkeytop nkeytop ikeytop ukeytop rkeytop rlkeytop rnkeytop
  rikeytop rukeytop

  topsort ltopsort ntopsort itopsort utopsort rtopsort rltopsort
  rntopsort ritopsort rutopsort

  keytopsort lkeytopsort nkeytopsort ikeytopsort ukeytopsort
  rkeytopsort rlkeytopsort rnkeytopsort rikeytopsort rukeytopsort

=head1 SEE ALSO

L<Sort::Key>, L<perlfunc/sort>.

The Wikipedia article about selection algorithms
L<http://en.wikipedia.org/wiki/Selection_algorithm>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Salvador FandiE<ntilde>o

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
