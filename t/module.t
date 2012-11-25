use strict;
use warnings;
use Test::More 0.96;

my $mod = 'App::csv2sqlite';
eval "require $mod" or die $@;

{
  my @csvf = qw( chips.csv pretzels.csv candy.csv );
  my $db   = 'snacks.sqlite';
  my $app = $mod->new_from_argv([ @csvf, $db ]);

  is_deeply $app->csv_files, [ @csvf ], 'input csv files';
  is $app->dbname, $db, 'last arg is output database';
}

done_testing;
