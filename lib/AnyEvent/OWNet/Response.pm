use strict;
use warnings;
package AnyEvent::OWNet::Response;

# ABSTRACT: Module for responses from 1-wire File System server

=head1 SYNOPSIS

  # normally instantiated by AnyEvent::OWNet command methods

=head1 DESCRIPTION

Module to represent responses from owfs 1-wire server daemon.

=method C<new()>

Constructs a new L<AnyEvent::OWNet::Response> object.  It is called by
L<AnyEvent::OWNet> in response to messages received from the
C<owserver> daemon.

=cut

sub new {
  my ($pkg, %p) = @_;
  bless { %p }, $pkg;
}

=method C<is_success()>

Returns true if the response object represents a successful request.

=cut

sub is_success {
  shift->{ret} == 0
}

=method C<return_code()>

Returns the return code of the response from the C<owserver> daemon.

=cut

sub return_code {
  shift->{ret}
}

=method C<version()>

Returns the protocol version number of the response from the
C<owserver> daemon.

=cut

sub version {
  shift->{version}
}

=method C<flags()>

Returns the flags field of the response from the C<owserver> daemon.
The L<AnyEvent::OWNet::Constants::ownet_temperature_units()|AnyEvent::OWNet::Constants/"ownet_temperature_units( $flags )">,
L<AnyEvent::OWNet::Constants::ownet_pressure_units()|AnyEvent::OWNet::Constants/"ownet_pressure_units( $flags )">,
and
L<AnyEvent::OWNet::Constants::ownet_display_format()|AnyEvent::OWNet::Constants/"ownet_display_format( $flags )">
functions can be used to extract some elements from this value.

=cut

sub flags {
  shift->{sg}
}

=method C<payload_length()>

Returns the payload length field of the response from the C<owserver>
daemon.

=cut

sub payload_length {
  shift->{payload}
}

=method C<size()>

Returns the size of the data element of the response from the
C<owserver> daemon.

=cut

sub size {
  shift->{size}
}

=method C<offset()>

Returns the offset field of the response from the C<owserver> daemon.

=cut

sub offset {
  shift->{offset}
}

=method C<data_list()>

Returns the data from the response as a list.  This is a intend for use
when the response corresponds to a directory listing request.

=cut

sub data_list {
  my $self = shift;
  unless (ref $self->{data}) {
    $self->{data} = [ split /,/, substr $self->{data}, 0, -1 ];
  }
  @{$self->{data}}
}

=method C<data()>

Returns the data from the response as a scalar.  This is a intend for
use when the response corresponds to a file C<read>.  However, it
returns the raw data for any request so while for a C<read> it may be
a simple scalar value, it may also be a comma separated list (e.g. for
a C<dirall> request) or an array reference (e.g. for a C<dir> request).

=cut

sub data {
  shift->{data}
}

1;
