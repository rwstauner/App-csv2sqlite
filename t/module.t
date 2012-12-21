use strict;
use warnings;
use Test::More 0.96;
use File::Spec::Functions qw( catfile ); # core
use File::Temp 0.19 qw( tempdir );

my $mod = 'App::csv2sqlite';
eval "require $mod" or die $@;

my $dir = tempdir('csv2sqlite.XXXXXX', TMPDIR => 1, CLEANUP => 1);

test_import({
  desc => 'basic',
  csvs => [qw( chips.csv pretzels.csv )],
  args => [],
  rs   => {
    'SELECT flavor, size FROM chips ORDER BY flavor' => [
      ['bbq', ' small'],
      ['plain', 'large'],
      ['spicy', 'medium'],
    ],
    'SELECT shape, "flavor|color" FROM pretzels ORDER BY shape' => [
      ['knot', 'doughy|golden brown'],
      ['ring', 'salty|brown'],
      ['rod', 'salty| brown'],
    ]
  },
});

test_import({
  desc => 'csv_opts: alternate separator',
  csvs => [qw( pretzels.csv )],
  args => [
    -o => 'sep_char=|',
    -o => 'allow_whitespace=1',
  ],
  attr => {
    csv_options => {
      sep_char => '|',
      allow_whitespace => 1,
    }
  },
  rs   => {
    'SELECT "shape,flavor", "color" FROM pretzels ORDER BY "shape,flavor"' => [
      ['knot,doughy', 'golden brown'],
      ['ring,salty', 'brown'],
      ['rod,salty', 'brown'],
    ]
  },
});

sub test_import {
  my $self = shift;

  subtest $self->{desc}, sub {

    my @csvf = map { catfile(corpus => $_) } @{ $self->{csvs} };
    my $db = catfile($dir, 'snacks.sqlite');
    my $app = $mod->new_from_argv([ @{ $self->{args} || [] }, @csvf, $db ]);

    is_deeply $app->csv_files, [ @csvf ], 'input csv files';
    is $app->dbname, $db, 'last arg is output database';

    while( my ($k, $v) = each %{ $self->{attr} } ){
      is_deeply $app->$k, $v, "attribute $k set";
    }

    $app->load_tables;

    # TODO: fix encoding so spicy can be jalapeño

    my $dbh = DBI->connect('dbi:SQLite:dbname=' . $db);

    while( my ($sql, $exp) = each %{ $self->{rs} } ){
      is_deeply
        $dbh->selectall_arrayref($sql),
        $exp,
        'database populated from csv';
    }

    #system("sqlite3 $db");
    unlink $db unless $self->{keep_db};
  };
}

done_testing;
