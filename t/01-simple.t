#!/usr/bin/perl
#
# Copyright (C) 2010 by Mark Hindess

use strict;
use constant {
  DEBUG => $ENV{ANYEVENT_OWNET_TEST_DEBUG}
};

$|=1;

BEGIN {
  require Test::More;
  $ENV{PERL_ANYEVENT_MODEL} = 'Perl' unless ($ENV{PERL_ANYEVENT_MODEL});
  eval { require AnyEvent; import AnyEvent;
         require AnyEvent::Socket; import AnyEvent::Socket };
  if ($@) {
    import Test::More skip_all => 'No AnyEvent::Socket module installed: $@';
  }
  import Test::More;
  use t::Helpers qw/:all/;
}

my @connections =
  (
   [
    {
     desc => q{dirall('/')},
     recv => '00 00 00 00 00 00 00 02  00 00 00 07 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 00',
     send => '00 00 00 00 00 00 00 89  00 00 00 00 00 00 01 0a
              00 00 00 88 00 00 c0 02  2f 31 30 2e 41 30 46 37
              42 31 30 30 30 38 30 30  2c 2f 31 30 2e 36 43 41
              38 45 34 30 30 30 38 30  30 2c 2f 31 30 2e 32 44
              33 41 42 43 30 30 30 38  30 30 2c 2f 32 38 2e 45
              30 36 44 39 42 30 30 30  30 30 30 2c 2f 62 75 73
              2e 30 2c 2f 73 65 74 74  69 6e 67 73 2c 2f 73 79
              73 74 65 6d 2c 2f 73 74  61 74 69 73 74 69 63 73
              2c 2f 73 74 72 75 63 74  75 72 65 2c 2f 73 69 6d
              75 6c 74 61 6e 65 6f 75  73 2c 2f 61 6c 61 72 6d
              00',
    },

    {
     desc => q{present('/settings')},
     recv => '00 00 00 00 00 00 00 0A  00 00 00 06 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 73 65 74 74 69 6E 67
              73 00',
     send => '00 00 00 00 00 00 00 00  00 00 00 00 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    {
     desc => q{present('/notexist')},
     recv => '00 00 00 00 00 00 00 0A  00 00 00 06 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 6E 6F 74 65 78 69 73
              74 00',
     send => '00 00 00 00 00 00 00 00  ff ff ff fe 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    {
     desc => q{read('/28.E06D9B000000/temperature')},
     recv => '00 00 00 00 00 00 00 1D  00 00 00 02 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 32 38 2E 45 30 36 44
              39 42 30 30 30 30 30 30  2F 74 65 6D 70 65 72 61
              74 75 72 65 00',
     send => '00 00 00 00 00 00 00 0c  00 00 00 0c 00 00 01 0a
              00 00 00 0c 00 00 00 00  20 20 20 20 20 20 32 33
              2e 36 32 35',
    },

    {
     desc => q{read('/28.E06D9B000000') (non file)},
     recv => '00 00 00 00 00 00 00 11  00 00 00 02 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 32 38 2E 45 30 36 44
              39 42 30 30 30 30 30 30  00',
     send => '00 00 00 00 00 00 00 00  ff ff ff eb 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    {
     desc => q{write('/05.F7692C000000/PIO', 0)},
     recv => '00 00 00 00 00 00 00 16  00 00 00 03 00 00 01 0E
              00 00 00 01 00 00 00 00  2F 30 35 2E 46 37 36 39
              32 43 30 30 30 30 30 30  2F 50 49 4F 00 30',
     send => '00 00 00 00 00 00 00 00  00 00 00 00 00 00 01 0a
              00 00 00 01 00 00 00 00',
    },

    {
     desc => q{dir('/')},
     recv => '00 00 00 00 00 00 00 02  00 00 00 04 00 00 01 0E
              00 00 00 00 00 00 00 00  2F 00',
     send => '00 00 00 00 00 00 00 11  00 00 00 00 00 00 01 05
              00 00 00 10 00 00 00 00  2f 31 30 2e 41 30 46 37
              42 31 30 30 30 38 30 30  00

              00 00 00 00 00 00 00 11  00 00 00 00 00 00 01 05
              00 00 00 10 00 00 00 00  2f 31 30 2e 36 43 41 38
              45 34 30 30 30 38 30 30  00

              00 00 00 00 00 00 00 11  00 00 00 00 00 00 01 05
              00 00 00 10 00 00 00 00  2f 31 30 2e 32 44 33 41
              42 43 30 30 30 38 30 30  00

              00 00 00 00 00 00 00 00  00 00 00 00 00 00 01 05
              00 00 00 00 00 00 00 00',
    },

    {
     desc => q{dirallslash('/')},
     recv => '00 00 00 00 00 00 00 02  00 00 00 09 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 00',
     send => '00 00 00 00 00 00 00 00  ff ff ff d6 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    {
     desc => q{get('/')},
     recv => '00 00 00 00 00 00 00 02  00 00 00 08 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 00',
     send => '00 00 00 00 00 00 00 89  00 00 00 00 00 00 01 0a
              00 00 00 88 00 00 c0 02  2f 31 30 2e 41 30 46 37
              42 31 30 30 30 38 30 30  2c 2f 31 30 2e 36 43 41
              38 45 34 30 30 30 38 30  30 2c 2f 31 30 2e 32 44
              33 41 42 43 30 30 30 38  30 30 2c 2f 32 38 2e 45
              30 36 44 39 42 30 30 30  30 30 30 2c 2f 62 75 73
              2e 30 2c 2f 73 65 74 74  69 6e 67 73 2c 2f 73 79
              73 74 65 6d 2c 2f 73 74  61 74 69 73 74 69 63 73
              2c 2f 73 74 72 75 63 74  75 72 65 2c 2f 73 69 6d
              75 6c 74 61 6e 65 6f 75  73 2c 2f 61 6c 61 72 6d
              00',
    },

    {
     desc => q{get('/28.55E1B6010000/temperature')},
     recv => '00 00 00 00 00 00 00 1D  00 00 00 08 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 32 38 2E 35 35 45 31
              42 36 30 31 30 30 30 30  2F 74 65 6D 70 65 72 61
              74 75 72 65 00',
     send => '00 00 00 00 00 00 00 0c  00 00 00 0c 00 00 01 0a
              00 00 00 0c 00 00 00 00  20 20 20 20 20 20 31 39
              2e 38 37 35',
    },

    {
     desc => q{getslash('/28.55E1B6010000/temperature')},
     recv => '00 00 00 00 00 00 00 1D  00 00 00 0A 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 32 38 2E 35 35 45 31
              42 36 30 31 30 30 30 30  2F 74 65 6D 70 65 72 61
              74 75 72 65 00',
     send => '00 00 00 00 00 00 00 00  ff ff ff d6 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    {
     desc => q{dir('/') incomplete},
     recv => '00 00 00 00 00 00 00 02  00 00 00 04 00 00 01 0E
              00 00 00 00 00 00 00 00  2F 00',
     send => '00 00 00 00 00 00 00 11  00 00 00 00 00 00 01 05
              00 00 00 10 00 00 00 00  2f 31 30 2e 41 30 46 37
              42 31 30 30 30 38 30 30  00

              00 00 00 00 00 00 00 11  00 00 00 00 00 00 01 05
              00 00 00 10 00 00 00 00  2f',
    },

    {
     desc => q{dir('/') pause},
     sleep => 0.2,
    },

    {
     desc => q{dir('/') complete},
     send => '31 30 2e 36 43 41 38 45  34 30 30 30 38 30 30 00

              00 00 00 00 00 00 00 11  00 00 00 00 00 00 01 05
              00 00 00 10 00 00 00 00  2f 31 30 2e 32 44 33 41
              42 43 30 30 30 38 30 30  00

              00 00 00 00 00 00 00 00  00 00 00 00 00 00 01 05
              00 00 00 00 00 00 00 00',
    },
   ],

   [
    {
     desc => q{read('/28.E06D9B000000/temperature')},
     recv => '00 00 00 00 00 00 00 1D  00 00 00 02 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 32 38 2E 45 30 36 44
              39 42 30 30 30 30 30 30  2F 74 65 6D 70 65 72 61
              74 75 72 65 00',
     send => '00 00 00 00 00 00 00 0c  00 00 00 0c 00 00 01 0a
              00 00 00 0c 00 00 00 00  20 20 20 20 20 20 32 33
              2e 36 32 35',
    },

    {
     desc => q{write('/05.F7692C000000/PIO', 0)},
     recv => '00 00 00 00 00 00 00 16  00 00 00 03 00 00 01 0E
              00 00 00 01 00 00 00 00  2F 30 35 2E 46 37 36 39
              32 43 30 30 30 30 30 30  2F 50 49 4F 00 30',
     send => '00 00 00 00 00 00 00 00  00 00 00 00 00 00 01 0a
              00 00 00 01 00 00 00 00',
    },
   ],

   [
    {
     desc => 'sleep',
     sleep => 0.3,
    },
   ],

   [
    # just close
   ],
  );

my $cv = AnyEvent->condvar;

eval { test_server($cv, @connections) };
plan skip_all => "Failed to create dummy server: $@" if ($@);

my ($host,$port) = @{$cv->recv};
my $addr = join ':', $host, $port;

plan tests => 141;

use_ok('AnyEvent::OWNet');

my $ow = AnyEvent::OWNet->new(host => $host, port => $port);

ok($ow, 'instantiate AnyEvent::OWNet object');

$cv = $ow->dirall('/');

my $res = $cv->recv;

resp($res,
     {
      version => 0,
      return_code => 0,
      flags => 0x0000010a,
      payload_length => 137,
      size => 136,
      offset => 0x0000c002, # TODO: check what this is
      data => [qw{/10.A0F7B1000800 /10.6CA8E4000800 /10.2D3ABC000800
                  /28.E06D9B000000 /bus.0 /settings /system /statistics
                  /structure /simultaneous /alarm}],
     }, q{... directory (all) listing});

$cv = $ow->present('/settings');

$res = $cv->recv;
resp($res,
          {
           version => 0,
           return_code => 0,
           flags => 0x0000010a,
           payload_length => 0,
           size => 0,
           offset => 0,
           data => '',
          }, q{... present check});

$cv = $ow->present('/notexist');

$res = $cv->recv;
resp($res,
          {
           version => 0,
           return_code => 0xfffffffe,
           flags => 0x0000010a,
           payload_length => 0,
           size => 0,
           offset => 0,
          }, q{... not present check});

$cv = $ow->read('/28.E06D9B000000/temperature');

$res = $cv->recv;

resp($res,
          {
           version => 0,
           return_code => 12,
           flags => 0x0000010a,
           payload_length => 12,
           size => 12,
           offset => 0,
           data => '      23.625',
          }, q{... read});

$cv = $ow->read('/28.E06D9B000000');

$res = $cv->recv;
resp($res,
          {
           version => 0,
           return_code => 0xffffffeb,
           flags => 0x0000010a,
           payload_length => 0,
           size => 0,
           offset => 0,
          }, q{... bad read of directory});

$cv = $ow->write('/05.F7692C000000/PIO', 0);
$res = $cv->recv;
resp($res,
          {
           version => 0,
           return_code => 0,
           flags => 0x0000010a,
           payload_length => 0,
           size => 1,
           offset => 0,
           data => '',
          }, q{... write});

$cv = $ow->dir('/');
$res = $cv->recv;
resp($res,
          {
           version => 0,
           return_code => 0,
           flags => 0x00000105,
           payload_length => 0,
           size => 0,
           offset => 0,
           data => [qw{/10.A0F7B1000800 /10.6CA8E4000800 /10.2D3ABC000800}],
          }, q{... directory listing});

$cv = $ow->dirallslash('/');
$res = $cv->recv;
resp($res,
          {
           version => 0,
           return_code => 0xffffffd6,
           flags => 0x0000010a,
           payload_length => 0,
           size => 0,
           offset => 0,
          }, q{... directory with slash listing});

$cv = $ow->get('/');

$res = $cv->recv;

resp($res,
          {
           version => 0,
           return_code => 0,
           flags => 0x0000010a,
           payload_length => 137,
           size => 136,
           offset => 0x0000c002, # TODO: check what this is
           data => [qw{/10.A0F7B1000800 /10.6CA8E4000800 /10.2D3ABC000800
                       /28.E06D9B000000 /bus.0 /settings /system /statistics
                       /structure /simultaneous /alarm}],
          }, q{... get directory});

$cv = $ow->get('/28.55E1B6010000/temperature',
               sub {
                 resp($_[0],
                           {
                            version => 0,
                            return_code => 12,
                            flags => 0x0000010a,
                            payload_length => 12,
                            size => 12,
                            offset => 0,
                            data => '      19.875',
                           }, q{... get temperature (in callback)});
                   });
$res = $cv->recv;
resp($res,
          {
           version => 0,
           return_code => 12,
           flags => 0x0000010a,
           payload_length => 12,
           size => 12,
           offset => 0,
           data => '      19.875',
          }, q{... get temperature});

$cv = $ow->getslash('/28.55E1B6010000/temperature');
$res = $cv->recv;
resp($res,
          {
           version => 0,
           return_code => 4294967254,
           flags => 0x010a,
           payload_length => 0,
           size => 0,
           offset => 0,
          }, q{... getslash temperature});

$cv = $ow->dir('/');
$res = $cv->recv;
resp($res,
          {
           version => 0,
           return_code => 0,
           flags => 0x00000105,
           payload_length => 0,
           size => 0,
           offset => 0,
           data => [qw{/10.A0F7B1000800 /10.6CA8E4000800 /10.2D3ABC000800}],
          }, q{... directory listing});

undef $ow;

$ow = AnyEvent::OWNet->new(host => $host, port => $port);

# make two requests while connect is pending
my ($cbres, $cbres2);
$cv = $ow->read('/28.E06D9B000000/temperature', sub { $cbres = shift });
my $cv2 = $ow->write('/05.F7692C000000/PIO', 0, sub { $cbres2 = shift });

$res = $cv->recv;

resp($res,
          {
           version => 0,
           return_code => 12,
           flags => 0x0000010a,
           payload_length => 12,
           size => 12,
           offset => 0,
           data => '      23.625',
          }, q{queued read});
is($res, $cbres, '... callback and condvar results are equal');

my $res2 = $cv2->recv;

resp($res2,
     {
      version => 0,
      return_code => 0,
      flags => 0x0000010a,
      payload_length => 0,
      size => 1,
      offset => 0,
      data => '',
     }, q{queued write});
is($res2, $cbres2, '... callback and condvar results are equal');

SKIP: {
  skip 'EV traps die', 3 if ($ENV{PERL_ANYEVENT_MODEL} eq 'EV');
  $ow = AnyEvent::OWNet->new(host => $host, port => $port, timeout => 0.1,
                             on_error => sub {die @_});

  is(test_error(sub { my $cv = $ow->dir('/'); $cv->recv; }),
     q{Socket timeout}, 'socket timeout');

  $ow = AnyEvent::OWNet->new(host => $host, port => $port,
                             on_error => sub {die @_});

  like(test_error(sub { my $cv = $ow->dir('/');
                        $ow->dir('/settings'); $cv->recv; }),
       qr/^Error: /, 'closed connection on write');

  $ow = AnyEvent::OWNet->new(host => $host, port => $port);

  like(test_error(sub { my $cv = $ow->dir('/'); $cv->recv }),
     qr/^Can't connect owserver: /, 'connection failure');
}

sub resp {
  my ($res, $exp, $desc) = @_;

  ok($res, $desc);
  foreach (qw/version return_code flags payload_length size offset/) {
    is($res->$_, $exp->{$_}, '... '.$_);
  }
  my $data = $exp->{data};
  if (ref $data) {
    is_deeply([$res->data_list], $data, '... data (list)');
  } else {
    is($res->data, $data, '... data (scalar)');
  }
}
