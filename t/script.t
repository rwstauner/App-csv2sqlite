use strict;
use warnings;
use Test::More 0.96;
use File::Spec;

my $dir = (grep { /blib.lib/ } @INC)
  ? [qw( blib script )]
  : ['bin'];

my $script = File::Spec->catfile(@$dir, 'csv2sqlite');

# TODO: tempdir, 2 csv's, 1 db
# TODO: qx/$script/
local $TODO = 'actually test this';
ok 0;

done_testing;
