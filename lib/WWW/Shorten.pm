package WWW::Shorten;

use 5.008001;
use strict;
use warnings;

use Carp 'croak';
use LWP::UserAgent;

our $VERSION         = '4.00';

our $DEFAULT_SERVICE = 'TinyURL';
our $USER_AGENT      = __PACKAGE__."/$VERSION";

my %name_sets = (
    default => [qw( makeashorterlink makealongerlink )],
    short   => [qw( short_link long_link )],
);

# List of subs provided by all WWW::Shorten providers
my @provided = qw(shorterlink_start shorterlink_result
                  longerlink_start longerlink_result);

my $provider;

sub import {
    my $class = shift;
    my $caller = caller;

    my $service = $DEFAULT_SERVICE;
    my $set     = 'default';

    for (@_) {
        if (/^:(\w+)$/) { $set = $1 }
        else            { $service = $_ }
    }

    # Load the service provider class (TinyURL)
    $provider = "${class}::${service}";
    eval {
        my $file = $provider;
        $file =~ s/::/\//g;
        require "$file.pm";
    };
    Carp::croak($@) if $@;
    # Import its functions
    no strict 'refs';
    for my $fun (@provided) {
        *{"${class}::$fun"} = *{"${provider}::$fun"}
    }

    # Export the given set of functions
    unless (exists $name_sets{$set}) {
        Carp::croak "Unknown function set '$set'";
    }
    *{"${caller}::$name_sets{$set}[0]"}
        = *{"${class}::$name_sets{default}[0]"};
    *{"${caller}::$name_sets{$set}[1]"}
        = *{"${class}::$name_sets{default}[1]"};
}

my $ua = LWP::UserAgent->new(
    env_proxy             => 1,
    timeout               => 30,
    agent                 => $USER_AGENT,
    requests_redirectable => [],
);

sub makeashorterlink {
    my $link = shift;

    croak "Invalid URL" unless $link and $link =~ /^https?:\/\/\S+/;

    $link = url_escape($link);

    my $args = { @_ };
    $args->{ua} = $USER_AGENT unless exists $args->{ua};

    # Get the instructions to perform the request
    my $instr = eval { shorterlink_start($link, $args) };
    croak $@ if $@;

    my $resp;
    if ($instr->{method} eq 'GET') {
        $resp = $ua->get($instr->{url});
    }
    elsif ($instr->{method} eq 'POST') {
        $resp = $ua->post($instr->{url}, $instr->{form});
    }
    else {
        croak "Invalid HTTP method '$instr->{method}'";
    }

    croak $resp->status_line if $resp->is_error;

    my $content = $resp->content;
    croak "Empty response" unless length $content;

    # Analyze the response
    my $short_url = eval { shorterlink_result($content) };
    croak $@ if $@;

    return $short_url;
}

sub makealongerlink {
    my $link = shift or croak "Invalid URL";

    $link = url_escape($link);

    my $args = { @_ };
    $args->{ua} = $USER_AGENT unless exists $args->{ua};

    # Get the instructions to perform the request
    my $instr = eval { longerlink_start($link, $args) };
    croak $@ if $@;

    my $resp;
    if ($instr->{method} eq 'GET') {
        $resp = $ua->get($instr->{url});
    }
    elsif ($instr->{method} eq 'POST') {
        $resp = $ua->post($instr->{url}, $instr->{form});
    }
    else {
        croak "Invalid HTTP method '$instr->{method}'";
    }

    croak $resp->status_line if $resp->is_error;

    if ($resp->is_redirect) {
        return $resp->header('Location');
    }

    my $content = $resp->content;
    croak "Empty response" unless length $content;

    # Analyze the response
    my $long_url = eval { longerlink_result($content) };
    croak $@ if $@;

    return $long_url;
}

# From Mojo::Util
sub url_escape {
    my $str = shift;
    $str =~ s/([^A-Za-z0-9\-._~])/sprintf '%%%02X', ord $1/ge;
    $str;
}

1;

=head1 NAME

WWW::Shorten - Interface to URL shortening sites.

=head1 SYNOPSIS

  #!/usr/bin/env perl
  use strict;
  use warnings;

  use WWW::Shorten 'TinyURL'; # Recommended
  # use WWW::Shorten 'Bitly'; # or one of the others

  # Individual modules have have their own syntactic variations.
  # See the documentation for the particular module you intend to use for details

  my $url = 'https://metacpan.org/pod/WWW::Shorten';
  my $short_url = makeashorterlink($url);
  my $long_url  = makealongerlink($short_url);

  # - OR -
  # If you don't like the long function names:

  use WWW::Shorten 'TinyURL', ':short';
  my $short_url = short_link($url);
  my $long_url = long_link( $short_url );

=head1 DESCRIPTION

A Perl interface to various services that shorten URLs. These sites maintain
databases of long URLs, each of which has a unique identifier.

=head1 DEPRECATION NOTICE

The following shorten services have been deprecated as the endpoints no longer
exist or function:

=over

=item *

L<WWW::Shorten::LinkToolbot>

=item *

L<WWW::Shorten::Linkz>

=item *

L<WWW::Shorten::MakeAShorterLink>

=item *

L<WWW::Shorten::Metamark>

=item *

L<WWW::Shorten::TinyClick>

=item *

L<WWW::Shorten::Tinylink>

=item *

L<WWW::Shorten::Qurl>

=item *

L<WWW::Shorten::Qwer>

=back

When version C<3.100> is released, these deprecated services will not be part of
the distribution.

=head1 SHORTEN APP

A very simple program called F<shorten> is supplied in the
distribution's F<bin> folder. This program takes a URL and
gives you a shortened version of it.

=head1 BUGS, REQUESTS, COMMENTS

Please submit any L<issues|https://github.com/p5-shorten/www-shorten/issues> you
might have.  We appreciate all help, suggestions, noted problems, and especially patches.

* If you know of a shorten service that we don't already have, make your own
service and release it as a separate module, like L<WWW::Shorten::Googl> or
L<WWW::Shorten::Bitly>.  Alternatively, you can let us know and we'll be happy
to work it up for you.

=head1 AUTHOR

Iain Truskett C<spoon@cpan.org>

=head1 CONTRIBUTORS

=over

=item *

Alex Page -- for the original LWP hacking on which Dave based his code.

=item *

Ask Bjoern Hansen -- providing L<WWW::Shorten::Metamark>

=item *

Chase Whitener C<capoeirab@cpan.org>

=item *

Dave Cross dave@perlhacks.com -- Authored L<WWW::MakeAShorterLink> on which this was based

=item *

Eric Hammond -- writing L<WWW::Shorten::NotLong>

=item *

Jon and William (wjr) -- smlnk services

=item *

Kazuhiro Osawa C<yappo@cpan.org>

=item *

Kevin Gilbertson (Gilby) -- TinyURL API information

=item *

Martin Thurn -- bug fixes

=item *

Matt Felsen (mattf) -- shorter function names

=item *

Neil Bowers C<neilb@cpan.org>

=item *

PJ Goodwin -- code for L<WWW::Shorten::OneShortLink>

=item *

Shashank Tripathi C<shank@shank.com> -- for providing L<WWW::Shorten::SnipURL>

=item *

Simon Batistoni -- giving the `makealongerlink` idea to Dave.

=item *

Everyone else we might have missed.

=back

In 2004 Dave Cross took over the maintenance of this distribution
following the death of Iain Truskett.

In 2016, Chase Whitener took over the maintenance of this distribution.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2002 by Iain Truskett.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<CGI::Shorten>, L<WWW::Shorten::Simple>

=cut
