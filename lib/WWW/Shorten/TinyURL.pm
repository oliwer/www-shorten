package WWW::Shorten::TinyURL;

use strict;
use warnings;
use Carp ();

our $VERSION  = '4.00';

## Old interface compatibility
use base qw( WWW::Shorten::generic Exporter );
our $_error_message = '';
our @EXPORT         = qw( makeashorterlink makealongerlink );
our $APIKEY         = '';
##


#
# NEW INTERFACE (object oriented)
#

#
# We always need a constructor. In most cases it will be
# a dummy one. But for TinyURL, we have  attribute: apikey.
#
sub new {
    my $class = shift;
    my $args = ref $_[0] eq 'HASH' ? shift : { @_ };

    $APIKEY ||= $args->{apikey};
    $args->{apikey} ||= $APIKEY;

    bless $args, $class;
}

#
# This is the first method called bwhen shortening an URL.
# For a given $link, it returns a hashref containing all
# the information that the user agent needs to start the
# the request. We do not care about the result of the
# HTTP request here.
#
# This sub is called in an eval and errors will be
# catched. $link is guaranteed to be a valid URL.
#
sub shorterlink_start {
    my ($self, $link) = @_;

    if ($self->{api_key}) {
        # Use TinyURL Open API
        return {
            POST => 'http://tiny-url.info/api/v1/create',
            form => [apikey => $self->{apikey}, format => 'text',
                     provider => 'tinyurl_com', url => $link]
        };
    }

    # Use the TinyURL web page: it does not require an API key
    # but is severly rate-limited.
    return {
        POST => 'http://tinyurl.com/api-create.php',
        form => [url => $link, source => __PACKAGE__."/$VERSION"]
    }
}

#
# This sub is called after the user agent has received a
# response from TinyURL. HTTP errors have already been
# handled and $content is guaranteed to be not empty.
#
# Return value: the short url.
#
sub shorterlink_result {
    my ($self, $content) = @_;

    if ($content =~ m!(\Qhttp://tinyurl.com/\E\w+)!x) {
        return $1;
    }

    if ($content =~ /Error/) {
        die 'Error is a html page' if $content =~ /<html/;
        die substr($content, 0, 100);
    }

    die 'Unknown error';
}

#
# Identical to shorterlink_start but to get back the
# original long URL.
#
sub longerlink_start {
    my ($self, $link) = @_;

    $link = "http://tinyurl.com/$link"
        unless $link =~ m!^http://!i;

    return { GET => $link };
}

#
# Identical to shorterlink_result but with a twist!
# This callback is only called in case we were not redirected.
# Otherwise, the caller will return the value of the 'Location'
# header.
#
# In the case of TinyURL, it only handles error cases.
#
sub longerlink_result {
    my ($self, $content) = @_;

    if ($content =~ /Error/) {
        die 'Error is a html page' if $content =~ /<html/;
        die substr($content, 0, 100);
    }

    die 'Unknown error';
}


#
# OLD INTERFACE
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
