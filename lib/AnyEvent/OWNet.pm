use strict;
use warnings;
package AnyEvent::OWNet;

# ABSTRACT: Client for 1-wire File System server

=head1 SYNOPSIS

  # IMPORTANT: the API is subject to change

  my $ow = AnyEvent::OWNet->new(host => '127.0.0.1',
                                port => 4304,
                                on_error => sub { warn @_ });

  # Read temperature sensor
  $ow->read('/10.123456789012/temperature', sub { my ($res) = @_; ... });

  # Read the temperatures of all devices that are found
  my $cv;
  $cv = $ow->devices(sub {
                       my $dev = shift;
                       print $dev, "\n";
                       $cv->begin;
                       $ow->get($dev.'temperature',
                                sub {
                                  my $res = shift;
                                  $cv->end;
                                  my $value = $res->{data};
                                  return unless (defined $value);
                                  print $dev, " = ", 0+$value, "\n";
                                });
                     });
  $cv->recv;

=head1 DESCRIPTION

AnyEvent module for handling communication with an owfs 1-wire server
daemon.

=cut

use 5.010;
use constant DEBUG => $ENV{ANYEVENT_OWNET_DEBUG};
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Carp qw/croak/;
use Try::Tiny;

use constant {
  OWNET_BUS_RET     => 0x00000002,
  OWNET_PERSISTENT  => 0x00000004,
  OWNET_ALIAS       => 0x00000008,
  OWNET_SAFEMODE    => 0x00000010,
  OWNET_NET         => 0x00000100,
  OWNET_CENTIGRADE  => 0x00000000,
  OWNET_FAHRENHEIT  => 0x00010000,
  OWNET_KELVIN      => 0x00020000,
  OWNET_RANKINE     => 0x00030000,
  OWNET_MILLIBAR    => 0x00000000,
  OWNET_ATOMOSPHERE => 0x00040000,
  OWNET_MM_MERCURY  => 0x00080000,
  OWNET_IN_MERCURY  => 0x000C0000,
  OWNET_PSI         => 0x00100000,
  OWNET_PASCAL      => 0x00140000,
  OWNET_DISP_F_I    => 0x00000000, # f.i    e.g. /10.67C6697351FF
  OWNET_DISP_FI     => 0x01000000, # fi     e.g. /1067C6697351FF
  OWNET_DISP_F_I_C  => 0x02000000, # f.i.c  e.g. /10.67C6697351FF.8D
  OWNET_DISP_F_IC   => 0x03000000, # f.ic   e.g. /10.67C6697351FF8D
  OWNET_DISP_FI_C   => 0x04000000, # fi.c   e.g. /10.67C6697351FF8D
  OWNET_DISP_F_IC   => 0x05000000, # fic    e.g. /1067C6697351FF8D

# OWNET_MSG_NOP         => 0x1,
  OWNET_MSG_READ        => 0x2,
  OWNET_MSG_WRITE       => 0x3,
  OWNET_MSG_DIR         => 0x4,
# OWNET_MSG_SIZE        => 0x5,
  OWNET_MSG_PRESENT     => 0x6,
  OWNET_MSG_DIRALL      => 0x7,
  OWNET_MSG_GET         => 0x8,
  OWNET_MSG_DIRALLSLASH => 0x9,
  OWNET_MSG_GETSLASH    => 0xa,

  OWNET_DEFAULT_DATA_SIZE => 0x80e8,
};

=method C<new( %parameter_hash )>

Constructs a new L<AnyEvent::OWNet> object.  The parameter hash can contain
values for the following keys:

=over

=item C<host>

The host IP of the running C<owserver> daemon.  Default is the IPv4
loopback address, C<127.0.0.1>.

=item C<port>

The TCP port of the running C<owserver> daemon.  Default is C<4304>.

=item C<timeout>

The timeout in seconds to wait for responses from the server.  Default
is 5 seconds.

=back

=cut

sub new {
  my ($pkg, %p) = @_;
  bless
    {
     connect_queue => [],
     host => '127.0.0.1',
     port => 4304,
     timeout => 5,
     %p,
    }, $pkg;
}

sub _msg {
  my ($self, $req) = @_;
  my $version = $req->{version} // 0;
  my $data = $req->{data} // '';
  my $payload = length $data;
  my $type = $req->{type} // OWNET_MSG_READ; # default to read
  my $sg = $req->{sg} // OWNET_NET | OWNET_BUS_RET | OWNET_ALIAS | OWNET_PERSISTENT;
  my $size = $req->{size} // OWNET_DEFAULT_DATA_SIZE;
  my $offset = $req->{offset} // 0;
  return pack 'N6a*', $version, $payload, $type, $sg, $size, $offset, $data;
}

=method C<read($path, $sub)>

Perform an OWNet C<read> operation for the given path.

=cut

sub read {
  my ($self, $path, $sub) = @_;
  $self->_run_cmd({ data => $path.chr(0), type => OWNET_MSG_READ }, $sub);
}

=method C<write($path, $value, $sub)>

Perform an OWNet C<write> operation of the given value to the given path.

=cut

sub write {
  my ($self, $path, $value, $sub) = @_;
  $self->_run_cmd({ data => $path.chr(0).$value,
                   size => length $value,
                   type => OWNET_MSG_WRITE }, $sub);
}

=method C<dir($path, $sub)>

Perform an OWNet C<dir> operation for the given path.

=cut

sub dir {
  my ($self, $path, $sub) = @_;
  $self->_run_cmd({ data => $path."\0", type => OWNET_MSG_DIR, size => 0 },
                 $sub);
}

=method C<present($path, $sub)>

Perform an OWNet C<present> check on the given path.

=cut

sub present {
  my ($self, $path, $sub) = @_;
  $self->_run_cmd({ data => $path."\0", type => OWNET_MSG_PRESENT }, $sub);
}

=method C<dirall($path, $sub)>

Perform an OWNet C<dirall> operation on the given path.

=cut

sub dirall {
  my ($self, $path, $sub) = @_;
  $self->_run_cmd({ data => $path."\0", type => OWNET_MSG_DIRALL }, $sub);
}

=method C<get($path, $sub)>

Perform an OWNet C<get> operation on the given path.

=cut

sub get {
  my ($self, $path, $sub) = @_;
  $self->_run_cmd({ data => $path."\0", type => OWNET_MSG_GET }, $sub);
}

=method C<dirallslash($path, $sub)>

Perform an OWNet C<dirall> operation on the given path.

=cut

sub dirallslash {
  my ($self, $path, $sub) = @_;
  $self->_run_cmd({ data => $path."\0", type => OWNET_MSG_DIRALLSLASH }, $sub);
}

=method C<getslash($path, $sub)>

Perform an OWNet C<get> operation on the given path.

=cut

sub getslash {
  my ($self, $path, $sub) = @_;
  $self->_run_cmd({ data => $path."\0", type => OWNET_MSG_GETSLASH }, $sub);
}

sub _run_cmd {
  my $self = shift;
  my $cmd  = shift;

  print STDERR 'Running command, ', $cmd->{type}, "\n" if DEBUG;
  $self->{cmd_cb} or return $self->connect($cmd, @_);
  $self->{cmd_cb}->($cmd, @_);
}

sub DESTROY { }

=method C<all_cv( [ $condvar ] )>

This method returns the L<AnyEvent> condvar that is used to track all
outstanding operations.  It can also be used to set the initial value
but this is only sensible when no operations are currently outstanding
and is not normally necessary.

=cut

sub all_cv {
  my $self = shift;
  $self->{all_cv} = shift if @_;
  unless ($self->{all_cv}) {
    $self->{all_cv} = AnyEvent->condvar;
  }
  $self->{all_cv};
}

=method C<cleanup( @error )>

This method is called on error or when the closing the connection to
free up resources and notify any receivers of errors.

=cut

sub cleanup {
  my $self = shift;
  print STDERR "cleanup\n" if DEBUG;
  $self->{all_cv}->croak(@_) if ($self->{all_cv});
  while (@{$self->{connect_queue}}) {
    my $queue = shift @{$self->{connect_queue}};
    my($cv, @args) = @$queue;
    $cv->croak(@_);
  }
  delete $self->{all_cv};
  delete $self->{cmd_cb};
  delete $self->{sock};
  $self->{on_error}->(@_) if $self->{on_error};
}

=method C<connect( [ $command, $callback|$condvar ] )>

This method connects to the C<owserver> daemon.  It is called automatically
when the first command is attempted.

=cut

sub connect {
  my $self = shift;

  my $cv;
  if (@_) {
    $cv = AnyEvent->condvar;
    push @{$self->{connect_queue}}, [ $cv, @_ ];
  }

  return $cv if $self->{sock};

  $self->{sock} = tcp_connect $self->{host}, $self->{port}, sub {

    my $fh = shift
      or do {
        my $err = "Can't connect owserver: $!";
        $self->cleanup($err);
        $cv->croak($err);
        return
      };

    warn "Connected\n" if DEBUG;

    my $hd =
      AnyEvent::Handle->new(
                            fh => $fh,
                            on_error => sub {
                              print STDERR "handle error $_[2]\n" if DEBUG;
                              $_[0]->destroy;
                              if ($_[1]) {
                                $self->cleanup($_[2]);
                              }
                            },
                            on_eof => sub {
                              print STDERR "handle eof\n" if DEBUG;
                              $_[0]->destroy;
                              $self->cleanup('Connection closed');
                            },
                            on_timeout => sub {
                              print STDERR "handle timeout\n" if DEBUG;
                              $_[0]->destroy;
                              $self->cleanup('Socket timeout');
                            }
                           );
    $self->{cmd_cb} = sub {
      $self->all_cv->begin;
      my $command = shift;

      my ($cv, $cb);
      if (@_) {
        $cv = pop if UNIVERSAL::isa($_[-1], 'AnyEvent::CondVar');
        $cb = pop if ref $_[-1] eq 'CODE';
      }

      my $msg = $self->_msg($command);
      print STDERR "sending command ", $command->{type}, "\n" if DEBUG;
      warn 'Sending: ', (unpack 'H*', $msg), "\n" if DEBUG;

      $hd->push_write($msg);
      $hd->timeout($self->{timeout});

      $cv ||= AnyEvent->condvar;

      print STDERR "using condvar $cv\n" if DEBUG;

      $cv->cb(sub {
                my $cv = shift;
                print STDERR "calling callback $cv\n" if DEBUG;
                try {
                  my $res = $cv->recv;
                  $cb->($res);
                } catch {
                  ($self->{on_error} || sub { die "ARGH: @_\n"; })->($_);
                }
              }) if $cb;

      $hd->push_read(ref $self, $command => sub {
                       my($handle, $res, $err) = @_;
                       $hd->timeout(0);
                       print STDERR "read finished $cv\n" if DEBUG;
                       print STDERR "read ",
                         ($cv->ready ? "ready" : "not ready"), "\n" if DEBUG;
                       $self->all_cv->end;
                       if ($err) {
                         print STDERR "returning error $err\n" if DEBUG;
                         return $cv->croak($res)
                       }
                       if (defined $res->{data} &&
                           ($command->{type} == OWNET_MSG_DIRALL ||
                            $command->{type} == OWNET_MSG_DIRALLSLASH ||
                            ( ( $command->{type} == OWNET_MSG_GET ||
                                $command->{type} == OWNET_MSG_GETSLASH ) &&
                              $res->{data} =~ /,/))) {
                         $res->{data} = [split /,/, substr $res->{data}, 0, -1];
                       }
                       print STDERR "Sending $res\n" if DEBUG;
                       $cv->send($res);
                     });
      return $cv;
    };

    while (@{$self->{connect_queue}}) {
      my $queue = shift @{$self->{connect_queue}};
      my($cv, @args) = @$queue;
      $self->{cmd_cb}->(@args, $cv);
    }
#    $cv->send(1);
  };

  return $cv;
}

=method C<devices( $callback, [ $path, [ $condvar ] ] )>

This method identifies all devices below the given path (or '/' if the
path is not given).  An C<AnyEvent> condvar may also be supplied that
will be used to track C<begin> and C<end> of all actions carried out
during the identification process.  If no condvar is provided then one
will be created.  The condvar used is returned by this method.

The supplied callback is called for each device with the path to each
device as the first argument and the condvar for the operation as the
second argument.  The intention of passing the callback the condvar
(that if not provided is created by the initial call) is to enable the
callbacks that need to make further asynchronous calls to use C<begin>
calls and C<end> calls (in the async callback) on the condvar so that
the complete operation may be tracked.  See the L<SYNOPSIS> for an
example.

This method currently assumes that the C<owserver> supports the C<getslash>
function and if this is not the case it will fail.

=cut

sub devices {
  my ($self, $cb, $offset, $cv) = @_;
  $offset ||= '/';
  $cv ||= AnyEvent->condvar;
  print STDERR "devices: $offset\n" if DEBUG;
  $cv->begin;
  $self->getslash($offset, sub {
                    my $res = shift;
                    my $data = $res->{data} || [];
                    $data = [$data] unless (ref $data);
                    foreach my $d (@$data) {
                      if ($d =~ m!^.*/[0-9a-f]{2}\.[0-9a-f]{12}/$!i) {
                        $cb->($d, $cv);
                        $self->devices($cb, $d, $cv);
                      } elsif ($d =~ m!/(?:main|aux)/$!) {
                        $self->devices($cb, $d, $cv);
                      }
                    }
                    $cv->end;
                  });
  $cv;
}

=method C<anyevent_read_type()>

This method is used to register an L<AnyEvent::Handle> read type
to read C<OWNet> replies from an C<owserver> daemon.

=cut

sub anyevent_read_type {
  my ($handle, $cb, $command) = @_;

  my $MAX_RETURN = 66000;
  my @data;
  sub {
    my $rbuf = \$handle->{rbuf};

  REDO:
    return unless (defined $$rbuf);
    my $len;

    my %result;
    my $header;
    do {
      $len = length $$rbuf;
      print STDERR "read_type has $len bytes\n" if DEBUG;
      print STDERR "read_type has ", (unpack 'H*', $$rbuf), "\n" if DEBUG;
      return unless ($len >= 24);
      @result{qw/version payload ret sg size offset/} = unpack 'N6', $$rbuf;
      $header = substr $$rbuf, 0, 24, '';
      print STDERR "read_type header ", (unpack 'H*', $header), "\n" if DEBUG;
      if ($result{'ret'} > $MAX_RETURN) {
        $cb->($handle, \%result);
        return 1;
      }
    } while ($result{payload} > $MAX_RETURN);

    my $total_len = 24 + $result{payload};
    print STDERR "read_type have ", $len, " need ", $total_len, "\n" if DEBUG;
    unless ($len >= $total_len) {
      $$rbuf = $header.$$rbuf;
      return;
    }

    my $data = substr $$rbuf, 0, $result{payload}, '';
    if ($command->{type} == OWNET_MSG_DIR) {
      if ($data eq '') {
        $result{data} = \@data;
      } else {
        push @data, substr $data, 0, -1;
        goto REDO;
      }
    } else {
      $result{data} = $data;
    }
    print STDERR "read_type complete\n" if DEBUG;
    $cb->($handle, \%result);
    return 1;
  }
}

1;

=head1 TODO

The result hash will be replaced by a module with simple API.

The code assumes that the C<owserver> supports persistence and does
not check the response flags to recognize when it is not.

=head1 SEE ALSO

AnyEvent(3)

OWFS Website: http://owfs.org/

OWFS Protocol Document: http://owfs.org/index.php?page=owserver-protocol
