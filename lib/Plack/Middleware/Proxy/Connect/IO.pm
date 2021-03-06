package Plack::Middleware::Proxy::Connect::IO;

=head1 NAME

Plack::Middleware::Proxy::Connect::IO - CONNECT method

=head1 SYNOPSIS

  # In app.psgi
  use Plack::Builder;
  use Plack::App::Proxy;

  builder {
      enable "Proxy::Connect::IO";
      enable "Proxy::Requests";
      Plack::App::Proxy->new->to_app;
  };

=head1 DESCRIPTION

This middleware handles the C<CONNECT> method. It allows to connect to
C<https> addresses.

The middleware runs on servers supporting C<psgix.io> and provides own
event loop so does not work correctly with C<psgi.nonblocking> servers.

The middleware uses only Perl's core modules: L<IO::Socket::INET> and
L<IO::Select>.

=for readme stop

=cut


use 5.006;

use strict;
use warnings;

our $VERSION = '0.0100';


use parent qw(Plack::Middleware);

use IO::Socket::INET;
use IO::Select;


use constant CHUNKSIZE => 64 * 1024;


sub call {
    my ($self, $env) = @_;

    return $self->app->($env) unless $env->{REQUEST_METHOD} eq 'CONNECT';

    my $client = $env->{'psgix.io'}
        or return [501, [], ['Not implemented CONNECT method']];

    my ($host, $port) = $env->{REQUEST_URI} =~ m{^(?:.+\@)?(.+?)(?::(\d+))?$};

    my $ioset = IO::Select->new;

    sub {
        my ($respond) = @_;

        my $remote = IO::Socket::INET->new(
            PeerAddr => $host,
            PeerPort => $port
        ) or return $respond->([502, [], ['Bad Gateway']]);

        my $writer = $respond->([200, []]);

        $ioset->add($client);
        $ioset->add($remote);

        while (1) {
            for my $socket ($ioset->can_read) {
                my $buffer;

                my $socket2 = do {
                    if ($socket == $remote) {
                        $client;
                    } elsif ($socket == $client) {
                        $remote;
                    }
                } or return $respond->([502, [], ['Bad Gateway']]);

                my $read = $socket->sysread($buffer, CHUNKSIZE);

                if ($read) {
                    $socket2->syswrite($buffer);
                } else {
                    $remote->close;
                    $client->close;
                    return;
                }
            }
        }

    };
}


1;


=for readme continue

=head1 SEE ALSO

L<Plack>, L<Plack::App::Proxy>, L<Plack::Middleware::Proxy::Connect>.

=head1 BUGS

If you find the bug or want to implement new features, please report it at
L<https://github.com/dex4er/perl-Plack-Middleware-Proxy-Connect-IO/issues>

The code repository is available at
L<http://github.com/dex4er/perl-Plack-Middleware-Proxy-Connect-IO>

=head1 AUTHOR

Piotr Roszatycki <dexter@cpan.org>

=head1 LICENSE

Copyright (c) 2014 Piotr Roszatycki <dexter@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

See L<http://dev.perl.org/licenses/artistic.html>
