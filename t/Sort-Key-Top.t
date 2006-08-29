# -*- Mode: CPerl -*-

use Test::More tests => 202;

use Sort::Key::Top qw(nkeytop top rnkeytop topsort
                      nkeytopsort rnkeytopsort
                      ikeytopsort rikeytopsort
                      ukeytopsort rukeytopsort);


my @top;

@top = nkeytop { abs $_ } 5 => 1, 2, 7, 5, 5, 1, 78, 0, -2, -8, 2;
is_deeply(\@top, [1, 2, 1, 0, -2], "nkeytop 1");


my @a = qw(cat fish bird leon penguin horse rat elephant squirrel dog);
@top = top 5 => @a;
is_deeply(\@top, [qw(cat fish bird elephant dog)], "top 1");

is_deeply([rnkeytop { length $_ } 3 => qw(a ab aa aac b t uu g h)], [qw(ab aa aac)], "rnkeytop 1");

is_deeply([top 5 => qw(a b ab t uu g h aa aac)], [qw(a b ab aa aac)], "top 2");

is_deeply([topsort 5 => qw(a b ab t uu g h aa aac)], [qw(a aa aac ab b)], "topsort 1");

is_deeply([rnkeytopsort { length $_ } 3 => qw(a ab aa aac b t uu g h)], [qw(aac ab aa)], "rnkeytopsort 1");

my @data = map { join ('', map { ('a'..'f')[rand 6] } 0..(3 + rand  6)) } 0..1000;

for my $n (-1, 0, 1, 2, 3, 4, 10, 16, 20, 50, 100, 200, 500, 900, 990, 996, 997, 998, 999,
           1000, 1001, 1002, 1010, 1020, 2000, 4000, 100000, 2000000) {

  my $max = @data > $n ? $n - 1 : $#data;

  is_deeply([topsort $n => @data], [(sort @data)[0..$max]], "topsort ($n)");
  is_deeply([nkeytopsort { length $_ } $n => @data],
            [ (sort { length $a <=> length $b } @data)[0..$max]], "nkeytopsort ($n)");
  is_deeply([rnkeytopsort { length $_ } $n => @data],
            [ (sort { length $b <=> length $a } @data)[0..$max]], "rnkeytopsort ($n)");
  is_deeply([ikeytopsort { length $_ } $n => @data],
            [ (sort { length $a <=> length $b } @data)[0..$max]], "ikeytopsort ($n)");
  is_deeply([rikeytopsort { length $_ } $n => @data],
            [ (sort { length $b <=> length $a } @data)[0..$max]], "rikeytopsort ($n)");
  is_deeply([ukeytopsort { length $_ } $n => @data],
            [ (sort { length $a <=> length $b } @data)[0..$max]], "ukeytopsort ($n)");
  is_deeply([rukeytopsort { length $_ } $n => @data],
            [ (sort { length $b <=> length $a } @data)[0..$max]], "rukeytopsort ($n)");
}
