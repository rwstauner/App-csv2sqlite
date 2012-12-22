use strict;
use warnings;
use Test::More 0.96;
use Try::Tiny 0.09;
use File::Spec::Functions qw( catfile ); # core
use File::Temp 0.19 qw( tempdir );

my $mod = 'App::csv2sqlite';
eval "require $mod" or die $@;

my $dir = tempdir('csv2sqlite.XXXXXX', TMPDIR => 1, CLEANUP => 1);

my @chips_rows = (
  ['bbq', ' small'],
  ['plain', 'large'],
  ['spicy', 'medium'],
);

test_import('basic', {
  csvs => [qw( chips.csv pretzels.csv )],
  args => [],
  rs   => {
    'SELECT flavor, size FROM chips ORDER BY flavor' => [
      @chips_rows,
    ],
    'SELECT shape, "flavor|color" FROM pretzels ORDER BY shape' => [
      ['knot', 'doughy|golden brown'],
      ['ring', 'salty|brown'],
      ['rod', 'salty| brown'],
    ]
  },
});

test_import('csv_opts: alternate separator', {
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

{
  my $exp_rows = [ @chips_rows ];
  my $test_args = {
    desc => 'basic',
    csvs => [qw( chips.csv )],
    args => [],
    rs   => {
      'SELECT flavor, size FROM chips ORDER BY flavor' => $exp_rows,
    },
  };

  test_import('success on the first run', {
    %$test_args,
    keep_db => 1,
  });

  test_import('reloading into the same db fails', {
    %$test_args,
    # NOTE: this message could easily change and we may need to be more robust
    error => qr/table "chips" already exists/,
    keep_db => 1,
  });

  # double the rows (in the right order) but keep the reference
  splice(@$exp_rows, 0, 3, map { ($_, $_) } @chips_rows);

  test_import('disable creation in loader to import more rows', {
    %$test_args,
    args => [ '--loader-opt=create=0' ],
    attr => {
      loader_options => {
        create => 0,
      },
    },
    keep_db => 0,
  });
}

sub test_import {
  my ($desc, $self) = @_;

  subtest $desc, sub {

    my @csvf = map { catfile(corpus => $_) } @{ $self->{csvs} };
    my $db = catfile($dir, 'snacks.sqlite');
    my $app = $mod->new_from_argv([ @{ $self->{args} || [] }, @csvf, $db ]);

    is_deeply $app->csv_files, [ @csvf ], 'input csv files';
    is $app->dbname, $db, 'last arg is output database';

    while( my ($k, $v) = each %{ $self->{attr} } ){
      is_deeply $app->$k, $v, "attribute $k set";
    }

    try {
      $app->load_tables;
    }
    catch {
      if( $self->{error} ){
        like $_[0], $self->{error}, 'caught expected error';
      }
      else {
        # unexpected; rethrow
        die $_[0];
      }
    };

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
