# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;

package App::csv2sqlite;
# ABSTRACT: Import CSV files into a SQLite database

use Moo 1;

use DBI 1.6 ();
use DBD::SQLite 1 ();
use DBIx::TableLoader::CSV 1.101 (); # catch csv errors and close transactions
use Getopt::Long 2.34 ();

sub new_from_argv {
  my ($class, $args) = @_;
  $class->new( $class->getopt($args) );
}

has csv_files => (
  is         => 'ro',
  coerce     => sub { ref $_[0] eq 'ARRAY' ? $_[0] : [ $_[0] ] },
);

has csv_options => (
  is         => 'ro',
  default    => sub { +{} },
);

has loader_options => (
  is         => 'ro',
  default    => sub { +{} },
);

has dbname => (
  is         => 'ro',
);

has dbh => (
  is         => 'lazy',
);

sub _build_dbh {
  my ($self) = @_;
  # TODO: does the dbname need to be escaped in some way?
  my $dbh = DBI->connect('dbi:SQLite:dbname=' . $self->dbname, undef, undef, {
    RaiseError => 1,
    PrintError => 0,
  });
  return $dbh;
}

sub help { Getopt::Long::HelpMessage(2); }

=head1 OPTIONS

=for :list
= --csv-file (or --csv)
The csv files to load
= --csv-opt (or -o)
A hash of key=value options to pass to L<Text::CSV>
= --dbname (or --database)
The file path for the SQLite database
= --loader-opt (or -l)
A hash of key=value options to pass to L<DBIx::TableLoader::CSV>

=cut

sub getopt {
  my ($class, $args) = @_;
  my $opts = {};

  {
    local @ARGV = @$args;
    my $p = Getopt::Long::Parser->new(
      config => [qw(pass_through auto_help auto_version)],
    );
    $p->getoptions($opts,
      'csv_files|csv-file|csvfile|csv=s@',
      # TODO: 'named_csv_files=s%'
      # or maybe --csv and --named should be subs that append to an array ref to keep order?
      'csv_options|csv-opt|csvopt|o=s%',
      # TODO: tableloader options like 'drop' or maybe --no-create
      'loader_options|loader-opt|loaderopt|l=s%',
      'dbname|database=s',
    ) or $class->help;
    $args = [@ARGV];
  }

  # last arguments
  $opts->{dbname} ||= pop @$args;

  # first argument
  if( @$args ){
    push @{ $opts->{csv_files} ||= [] }, @$args;
  }

  return $opts;
}

sub load_tables {
  my ($self) = @_;

  # TODO: option for wrapping the whole loop in a transaction rather than each table

  foreach my $file ( @{ $self->csv_files } ){
    my %opts = (
      %{ $self->loader_options },
      csv_opts => { %{ $self->csv_options } },
      file => $file,
    );

    # TODO: This could work but i hate the escaping thing.
    # Allow table=file (use "=file" for files with an equal sign).
    #if( $file =~ /^([^=:]*)[=:](.+)$/ ){ $opts{name} = $1 if $1; $opts{file} = $2; }

    DBIx::TableLoader::CSV->new(
      %opts,
      dbh  => $self->dbh,
    )->load;
  }

  return;
}

sub run {
  my $class = shift || __PACKAGE__;
  my $args = @_ ? shift : [@ARGV];

  my $self = $class->new_from_argv($args);
  $self->load_tables;
}

1;

=for Pod::Coverage
new_from_argv
help
getopt
load_tables
run
csv_files
csv_options
loader_options
dbname
dbh

=head1 SYNOPSIS

  csv2sqlite doggies.csv kitties.csv pets.sqlite

  # configure CSV parsing as necessary:
  csv2sqlite -o sep_char=$'\t' plants.tab plants.sqlite

=head1 DESCRIPTION

Import CSV files into a SQLite database
(using L<DBIx::TableLoader::CSV>).

Each csv file specified on the command line
will became a table in the resulting sqlite database.

=head1 TODO

=for :list
* specific L<DBIx::TableLoader> options?
* confirm using a pre-existing database?
* more tests
* allow specifying table names for csv files

=cut
