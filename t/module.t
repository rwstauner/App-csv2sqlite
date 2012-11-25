use strict;
use warnings;
use Test::More 0.96;
use File::Spec::Functions qw( catfile ); # core
use File::Temp 0.19 qw( tempdir );

my $mod = 'App::csv2sqlite';
eval "require $mod" or die $@;

my $dir = tempdir('csv2sqlite.XXXXXX', TMPDIR => 1, CLEANUP => 1);

{
  my @csvf = map { catfile(corpus => $_) } qw( chips.csv pretzels.csv );
  my $db = catfile($dir, 'snacks.sqlite');
  my $app = $mod->new_from_argv([ @csvf, $db ]);

  is_deeply $app->csv_files, [ @csvf ], 'input csv files';
  is $app->dbname, $db, 'last arg is output database';

  $app->load_tables;

  # TODO: fix encoding so spicy can be jalapeño

  my $dbh = DBI->connect('dbi:SQLite:dbname=' . $db);
  is_deeply
    $dbh->selectall_arrayref('SELECT flavor, size FROM chips ORDER BY size'),
    [
      ['plain', 'large'],
      ['spicy', 'medium'],
      ['bbq', 'small'],
    ],
    'database populated from csv';
}

done_testing;
