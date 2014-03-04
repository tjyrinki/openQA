# Copyright (C) 2014 SUSE Linux Products GmbH
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

package OpenQA::API::V1::Client;

use Mojo::Base 'Mojo::UserAgent';
use Mojo::Util 'hmac_sha1_sum';

use Config::IniFiles;
use Scalar::Util ();

use Carp;

has 'key';
has 'secret';

sub new {
    my $self = shift->SUPER::new;
    my %args = @_;

    for my $i (qw/key secret/) {
        next unless $args{$i};
        $self->$i($args{$i});
    }

    if ($args{api}) {
        for my $file ($ENV{OPENQA_CLIENT_CONFIG}||undef, glob ('~/.config/openqa/client.conf'), '/etc/openqa/client.conf') {
            next unless $file && -r $file;
            my $cfg = Config::IniFiles->new(-file => $file) || last;
            last unless $cfg->SectionExists($args{api});
            for my $i (qw/key secret/) {
                next if $self->$i;
                $self->$i($cfg->val($args{api}, $i));
            }
            last;
        }
    }

    $self->on(start => sub {
            $self->_add_auth_headers(@_);
        });

    return $self;
}

sub _add_auth_headers {
    my ($self, $ua, $tx) = @_;

    unless ($self->secret && $self->key) {
        carp "missing secret and/or key";
        return;
    }

    my $timestamp = time;
    my %headers = (
        Accept => 'application/json',
        'X-API-Key' => $self->key,
        'X-API-Microtime' => $timestamp,
        'X-API-Hash' => hmac_sha1_sum($self->_path_query($tx).$timestamp, $self->secret),
    );

    while (my ($k, $v) = each %headers) {
        $tx->req->headers->header($k, $v);
    }
}

sub _path_query {
    my $self  = shift;
    my $url = shift->req->url;
    my $query = $url->query->to_string;
    my $r = $url->path->to_string . (length $query ? "?$query" : '');
    return $r;
}

1;

=encoding utf8

=head1 NAME

OpenQA::API::V1::Client - special version of Mojo::UserAgent that handles authentication

=head1 SYNOPSIS

  use OpenQA::API::V1::Client;

  # create new UserAgent that is meant to talk to localhost. Reads key
  # and secret from config section [localhost]
  my $ua = OpenQA::API::V1::Client->new(api => 'localhost');

  # specify key and secret manually
  my $ua = OpenQA::API::V1::Client->new(key => 'foo', secret => 'bar');

=head1 DESCRIPTION

L<OpenQA::API::V1::Client> inherits from L<Mojo::UserAgent>. It
automatically sets the correct authentication headers if key and
secret are available.

Key and secret can either be set manually in the constructor, via
attributes or read from a config file. L<OpenQA::API::V1::Client>
tries to find a config file in $OPENQA_CLIENT_CONFIG,
~/.config/openqa/client.conf or /etc/openqa/client.conf and reads
whatever comes first.

See L<Mojo::UserAgent> for more.

=head1 ATTRIBUTES

L<OpenQA::API::V1::Client> implmements the following attributes.

=head2 key

  my $key = $ua->key;
  $ua     = $ua->key('foo');

The authentication public key

=head2 secret

  my $secret = $ua->secret;
  $ua     = $ua->secret('bar');

The authentication secret key

=head1 METHODS

=head2 new

  my $ua = OpenQA::API::V1::Client->new(api => 'localhost');
  my $ua = OpenQA::API::V1::Client->new(key => 'foo', secret => 'bar');

Generate the L<OpenQA::API::V1::Client> object.

=head1 CONFIG FILE FORMAT

The config file is in ini format. The sections are the host name of
the api.

  [openqa.example.com]
  key = foo
  secret = bar

=head1 SEE ALSO

L<Mojo::UserAgent>, L<Config::IniFiles>

=cut
