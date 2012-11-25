# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;

package App::csv2sqlite;
# ABSTRACT: Import CSV files into SQLite database

use Moo 1;

use DBI 1.6 ();
use DBD::SQLite 1 ();
use DBIx::TableLoader::CSV 1.100 (); # catch csv errors
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

has dbname => (
  is         => 'ro',
);

has dbh => (
  is         => 'lazy',
);

sub _build_dbh {
  my ($self) = @_;
  my $dbh = DBI->connect('dbi:SQLite:dbname=' . $self->dbname, undef, undef, {
    RaiseError => 1,
    PrintError => 0,
  });
  return $dbh;
}

sub help { Getopt::Long::HelpMessage(2); }

sub getopt {
  my ($class, $args) = @_;
  my $opts = {};

  {
    local @ARGV = @$args;
    my $p = Getopt::Long::Parser->new(
      config => [qw(pass_through auto_help auto_version)],
    );
    $p->getoptions($opts,
      'csv_files|csv_file|csvfiles|csvfile|csv=s@',
      # TODO: 'csv_option|csvoption|o=%',
      # TODO: tableloader options like 'drop' or maybe --no-create
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
    DBIx::TableLoader::CSV->new(
      %{ $self->csv_options },
      file => $file,
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

=head1 SYNOPSIS

  csv2sqlite doggies.csv kitties.csv pets.sqlite

=head1 DESCRIPTION

Import CSV files into a SQLite database
(using L<DBIx::TableLoader::CSV>).

Each csv file specified on the command line
will became a table in the resulting sqlite database.

=head1 TODO

=for :list
* csv options
* various L<DBIx::TableLoader> options
* confirm using a pre-existing database?
* more tests

=cut
