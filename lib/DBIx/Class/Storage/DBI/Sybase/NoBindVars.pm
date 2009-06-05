package DBIx::Class::Storage::DBI::Sybase::NoBindVars;

use Class::C3;
use base qw/
  DBIx::Class::Storage::DBI::NoBindVars
  DBIx::Class::Storage::DBI::Sybase
/;
use List::Util ();

sub _dbh_last_insert_id {
  my ($self, $dbh, $source, $col) = @_;

  # @@identity works only if not using placeholders
  # Should this query be cached?
  return ($dbh->selectrow_array('select @@identity'))[0];
}

my %noquote = (
    int => sub { /^ -? \d+ \z/x },
    # TODO maybe need to add float/real/etc
);

sub should_quote_data_type {
  my $self = shift;
  my ($type, $value) = @_;

  return $self->next::method(@_) if not defined $value;

  if (my $key = List::Util::first { $type =~ /^$_/i } keys %noquote) {
    local $_ = $value;
    return 0 if $noquote{$key}->();
  }

  return $self->next::method(@_);
}

1;

=head1 NAME

DBIx::Class::Storage::DBI::Sybase::NoBindVars - Storage::DBI subclass for Sybase
without placeholder support

=head1 DESCRIPTION

If you're using this driver than your version of Sybase does not support
placeholders. You can check with:

  $dbh->{syb_dynamic_supported}

You can also enable this driver explicitly using:

  my $schema = SchemaClass->clone;
  $schema->storage_type('::DBI::Sybase::NoBindVars');
  $schema->connect($dsn, $user, $pass, \%opts);

See the discussion in L<< DBD::Sybase/Using ? Placeholders & bind parameters to
$sth->execute >> for details on the pros and cons of using placeholders.

One advantage of not using placeholders is that C<select @@identity> will work
for obtainging the last insert id of an C<IDENTITY> column, instead of having to
do C<select max(col)> as the base Sybase driver does.

When using this driver, bind variables will be interpolated (properly quoted of
course) into the SQL query itself, without using placeholders.

The caching of prepared statements is also explicitly disabled, as the
interpolation renders it useless.

=head1 AUTHORS

See L<DBIx::Class/CONTRIBUTORS>.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
# vim:sts=2 sw=2:
