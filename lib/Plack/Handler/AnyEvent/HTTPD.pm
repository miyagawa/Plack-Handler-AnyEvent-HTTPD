package Plack::Handler::AnyEvent::HTTPD;

use strict;
use 5.008_001;
our $VERSION = '0.01';

use AnyEvent::HTTPD;
use Plack::Util;
use HTTP::Status;
use URI::Escape;

my %_sockets;

sub new {
    my($class, %args) = @_;
    bless {%args}, $class;
}

sub register_service {
    my($self, $app) = @_;

    my $httpd = AnyEvent::HTTPD->new(
        port => $self->{port} || 9000,
        host => $self->{host},
        connection_class => 'Plack::Handler::AnyEvent::HTTPD::Connection',
        request_timeout => $self->{request_timeout},
    );

    $httpd->reg_cb(client_disconnected => sub {
        my($httpd, $host, $port) = @_;
        delete $_sockets{join(":", $host, $port)};
    });

    $httpd->reg_cb(
        '' => sub {
            my($httpd, $req) = @_;

            my $env = {
                REMOTE_ADDR         => $req->client_host,
                SERVER_PORT         => $httpd->port,
                SERVER_NAME         => $httpd->host,
                SCRIPT_NAME         => '',
                REQUEST_METHOD      => $req->method,
                PATH_INFO           => URI::Escape::uri_unescape($req->{url}->path),
                REQUEST_URI         => $req->{url}->as_string,
                QUERY_STRING        => $req->{url}->query,
                SERVER_PROTOCOL     => 'HTTP/1.0', # no way to get this from HTTPConnection
                'psgi.version'      => [ 1, 1 ],
                'psgi.errors'       => *STDERR,
                'psgi.url_scheme'   => 'http',
                'psgi.nonblocking'  => Plack::Util::TRUE,
                'psgi.streaming'    => Plack::Util::TRUE,
                'psgi.run_once'     => Plack::Util::FALSE,
                'psgi.multithread'  => Plack::Util::FALSE,
                'psgi.multiprocess' => Plack::Util::FALSE,
                'psgi.input'        => do {
                    open my $input, "<", \(defined $req->content ? $req->content : '');
                    $input;
                },
                'psgix.io'          => delete $_sockets{join(":", $req->client_host, $req->client_port)},
            };

            my $hdr = $req->headers;
            $env->{CONTENT_TYPE}   = delete $hdr->{'content-type'};
            $env->{CONTENT_LENGTH} = delete $hdr->{'content-length'};

            while (my($key, $val) = each %$hdr) {
                $key =~ tr/-/_/;
                $env->{"HTTP_" . uc $key} = $val;
            }

            my $res = Plack::Util::run_app($app, $env);

            my $respond = sub {
                my $res = shift;

                my @res = ($res->[0], HTTP::Status::status_message($res->[0]), {@{$res->[1]}});

                if (defined $res->[2]) {
                    my $content;
                    Plack::Util::foreach($res->[2], sub { $content .= $_[0] });

                    # Work around AnyEvent::HTTPD bugs that it sets
                    # Content-Length even when it's not necessary
                    if (!$content && Plack::Util::status_with_no_entity_body($res->[0])) {
                        $content = sub { $_[0]->(undef) if $_[0] };
                    }

                    $req->respond([ @res, $content ]);

                    return;
                } else {
                    # Probably unnecessary, but in case ->write is
                    # called before the poll callback is execute.
                    my @buf;
                    my $data_cb = sub { push @buf, $_[0] };
                    $req->respond([
                        @res,
                        sub {
                            # TODO $data_cb = undef -> Client Disconnect
                            $data_cb = shift;
                            if ($data_cb && @buf) {
                                $data_cb->($_) for @buf;
                                @buf = ()
                            }
                        }
                    ]);

                    return Plack::Util::inline_object
                        write => sub { $data_cb->($_[0]) if $data_cb },
                        close => sub { $data_cb->(undef) if $data_cb };
                }
            };

            ref $res eq 'CODE' ? $res->($respond) : $respond->($res);
        }
    );

    $self->{_httpd} = $httpd;
}

sub run {
    my $self = shift;
    $self->register_service(@_);

    $self->{_httpd}->run;
}

package Plack::Handler::AnyEvent::HTTPD::Connection;
use parent qw(AnyEvent::HTTPD::HTTPConnection);

# Don't parse content
sub handle_request {
    my($self, $method, $uri, $hdr, $cont) = @_;

    Scalar::Util::weaken(
        $_sockets{join(":", $self->{host}, $self->{port})} = $self->{hdl}->{fh}
    );

    $self->{keep_alive} = ($hdr->{connection} =~ /keep-alive/io);
    $self->event(request => $method, $uri, $hdr, $cont);
}

package Plack::Handler::AnyEvent::HTTPD;

1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

Plack::Handler::AnyEvent::HTTPD - Plack handler to run PSGI apps on AnyEvent::HTTPD

=head1 SYNOPSIS

  plackup -s AnyEvent::HTTPD --port 9090

=head1 DESCRIPTION

Plack::Handler::AnyEvent::HTTPD is a Plack handler to run PSGI apps on AnyEvent::HTTPD module.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<AnyEvent::HTTPD>

=cut
