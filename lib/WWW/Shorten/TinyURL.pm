package WWW::Shorten::TinyURL;

use strict;
use warnings;
use Carp ();

# Old interface compatibility
use base qw( WWW::Shorten::generic Exporter );
our $_error_message = '';
our @EXPORT         = qw( makeashorterlink makealongerlink );

our $VERSION  = '4.00';

our $APIKEY   = '';
our $PROVIDER = 'tinyurl_com';


sub shorterlink_start {
    my ($link, $args) = @_;

    # $link is guaranteed to be not empty by the caller.

    # $args contains optional user-supplied arguments as
    # well as the UserAgent signature.

    if ($APIKEY) {
        # Use TinyURL Open API
        return {
            method => 'POST',
            url    => 'http://tiny-url.info/api/v1/create',
            form   => [apikey => $APIKEY, format => 'text',
                       provider => $PROVIDER, url => $link]
        };
    }

    # Use the TinyURL web page: it does not require an API key
    # but is severly rate-limited.
    return {
        method => 'POST',
        url    => 'http://tinyurl.com/api-create.php',
        form   => [url => $link, source => $args->{ua}]
    }

    #TODO: decide if the 'form' field should be a hashref or an arrayref

    # In case of error, just die. This sub is called inside an eval.
}

sub shorterlink_result {
    my $content = shift;

    # HTTP errors have already been handled by the caller.
    # $content is guaranteed to be not empty.

    if ($content =~ m!(\Qhttp://tinyurl.com/\E\w+)!x) {
        return $1;
    }

    if ($content =~ /Error/) {
        die 'Error is a html page' if $content =~ /<html/;
        die substr($content, 0, 100);
    }

    die 'Unknown error';
}


sub longerlink_start {
    my ($link, $args) = @_;

    $link = "http://tinyurl.com/$link"
        unless $link =~ m!^http://!i;

    return {
        method => 'GET',
        url    => $link,
    };
}

sub longerlink_result {
    my $content = shift;

    # This callback is only called in case we were not redirected.
    # Otherwise, the caller will return the value of the Location
    # header.

    if ($content =~ /Error/) {
        die 'Error is a html page' if $content =~ /<html/;
        die substr($content, 0, 100);
    }

    die 'Unknown error';
}


#
# Old interface
#

sub makeashorterlink {
    my $url = shift or Carp::croak('No URL passed to makeashorterlink');
    $_error_message = '';

    # terrible, bad!  skip live testing for now.
    if ( $ENV{'WWW-SHORTEN-TESTING'} ) {
        return 'http://tinyurl.com/abc12345'
            if ( $url eq 'https://metacpan.org/release/WWW-Shorten' );
        $_error_message = 'Incorrect URL for testing purposes';
        return undef;
    }

    # back to normality.
    my $ua      = __PACKAGE__->ua();
    my $tinyurl = 'http://tinyurl.com/api-create.php';
    my $resp
        = $ua->post($tinyurl, [url => $url, source => "PerlAPI-$VERSION",]);
    return undef unless $resp->is_success;
    my $content = $resp->content;
    if ($content =~ /Error/) {

        if ($content =~ /<html/) {
            $_error_message = 'Error is a html page';
        }
        elsif (length($content) > 100) {
            $_error_message = substr($content, 0, 100);
        }
        else {
            $_error_message = $content;
        }
        return undef;
    }
    if ($resp->content =~ m!(\Qhttp://tinyurl.com/\E\w+)!x) {
        return $1;
    }
    return;
}

sub makealongerlink {
    my $url = shift
        or Carp::croak('No TinyURL key / URL passed to makealongerlink');
    $_error_message = '';
    $url = "http://tinyurl.com/$url"
        unless $url =~ m!^http://!i;

    # terrible, bad!  skip live testing for now.
    if ( $ENV{'WWW-SHORTEN-TESTING'} ) {
        return 'https://metacpan.org/release/WWW-Shorten'
            if ( $url eq 'http://tinyurl.com/abc12345' );
        $_error_message = 'Incorrect URL for testing purposes';
        return undef;
    }

    # back to normality
    my $ua = __PACKAGE__->ua();

    my $resp = $ua->get($url);

    unless ($resp->is_redirect) {
        my $content = $resp->content;
        if ($content =~ /Error/) {
            if ($content =~ /<html/) {
                $_error_message = 'Error is a html page';
            }
            elsif (length($content) > 100) {
                $_error_message = substr($content, 0, 100);
            }
            else {
                $_error_message = $content;
            }
        }
        else {
            $_error_message = 'Unknown error';
        }

        return undef;
    }
    my $long = $resp->header('Location');
    return $long;
}

1;

=head1 NAME

WWW::Shorten::TinyURL - Perl interface to L<http://tinyurl.com>

=head1 SYNOPSIS

  use strict;
  use warnings;

  use WWW::Shorten 'TinyURL';

  my $short_url = makeashorterlink('http://www.foo.com/some/long/url');
  my $long_url  = makealongerlink($short_url);


  # or using Mojo::URL::Shorten to be non-blocking
  use Mojo::URL::Shorten;

  my $shortnr = Mojo::URL::Shorten->new(using => 'TinyURL');
  $shortnr->short_url('http://www.foo.com/some/long/url' => sub {
    my ($shortnr, $short_url, $error) = @_;
    $shortnr->long_url($short_url => sub {
      my ($shortnr, $long_url, $error) = @_;
    });
  });


=head1 DESCRIPTION

A Perl interface to the web site L<http://tinyurl.com>.  The service simply maintains
a database of long URLs, each of which has a unique identifier.

DO NOT USE THIS MODULE DIRECTLY.

=head1 SUPPORT, LICENSE, THANKS and SUCH

See the main L<WWW::Shorten> docs.

=head1 AUTHOR

Iain Truskett <spoon@cpan.org>

=head1 SEE ALSO

L<WWW::Shorten>, L<http://tinyurl.com/>

=cut
