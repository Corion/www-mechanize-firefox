package HTTP::Cookies::MozRepl;
use strict;
use HTTP::Date qw(time2str);
use MozRepl::RemoteObject 'as_list';
use parent 'HTTP::Cookies';
use Carp qw[croak];

use vars qw[$VERSION];
$VERSION = '0.78';

=head1 NAME

HTTP::Cookies::MozRepl - retrieve cookies from a live Firefox instance

=head1 SYNOPSIS

  use HTTP::Cookies::MozRepl;
  my $cookie_jar = HTTP::Cookies::MozRepl->new();
  # use just like HTTP::Cookies

=head1 DESCRIPTION

This package overrides the load() and save() methods of HTTP::Cookies
so it can work with a live Firefox instance.

Note: To use this module, Firefox must be running and it must
have the C<mozrepl> extension installed.

See L<HTTP::Cookies>.

=head1 Reusing an existing connection

If you already have an existing connection to Firefox
that you want to reuse, just pass the L<MozRepl::RemoteObject>
instance to the cookie jar constructor in the C<repl> parameter:

  my $cookie_jar = HTTP::Cookies::MozRepl->new(
      repl => $repl
  );

=cut

sub load {
    my ($self,$repl) = @_;
    $repl ||= $self->{'file'} || $self->{'repl'} || return;
    
    # Get cookie manager
    my $cookie_manager = $repl->expr(<<'JS');
        Components.classes["@mozilla.org/cookiemanager;1"]
                 .getService(Components.interfaces.nsICookieManager)
JS

    my $nsICookie = $repl->expr(<<'JS');
        Components.interfaces.nsICookie
JS

    my $nsICookieManager = $repl->expr(<<'JS');
        Components.interfaces.nsICookieManager
JS
    $cookie_manager = $cookie_manager->QueryInterface($nsICookieManager);
    
    my $e = $cookie_manager->{enumerator};
    my $fetch_cookies = $e->bridge->declare(<<'JS', 'list');
    function(e,nsiCookie) {
        var r=[];
        while (e.hasMoreElements()) {
            var cookie = e.getNext().QueryInterface(nsiCookie);
            r.push([1,cookie.name,cookie.value,cookie.path,cookie.host,null,null,cookie.isSecure,cookie.expires]);
        };
        return r
    };
JS
    # This could be even more efficient by fetching the whole result
    # as one huge data structure
    for my $c ($fetch_cookies->($e,$nsICookie)) {
        my @v = as_list $c;
        if( $v[8] > 0) {
            $v[8] -= time;
        } elsif( $v[8] == 0 ) {
            # session cookie, we never let it expire within HTTP::Cookie
            $v[8] += 3600; # well, "never"
        };
        $self->SUPER::set_cookie(@v);
    };

    # This code is pure Perl, but involves far too many roundtrips :-(
    #$e->bridge->queued(sub{
    #    while ($e->hasMoreElements) {
    #        my $cookie = $e->getNext()->QueryInterface($nsICookie);
    #        
    #        my @values = map { $cookie->{$_} } (qw(name value path host                      isSecure expires));
    #        $self->set_cookie( undef,       @values[0,   1,    2,   3, ], undef, undef, $values[ 4 ],    time-$values[5], 0 );
    #    };
    #});
}

sub set_cookie {
    my ($self, $version, $key, $val, $path, $domain, $port, $path_spec, $secure, $maxage, $discard, $rest ) = @_;
    $rest ||= {};
    my $repl = $rest->{repl} || $self->{repl};
    
    my $uri = URI->new("http://$domain",'http');
    #$uri->protocol('http'); # ???
    $uri->host($domain);
    $uri->path($path) if $path;
    $uri->port($port) if $port;
    
    my $set = $repl->declare(<<'JS');
        function (host,path,name,value,secure,httponly,session,expiry) {
            var cookieMgr = Components.classes["@mozilla.org/cookiemanager;1"].getService(Components.interfaces.nsICookieManager2);

            cookieMgr.add(host,path,name,value,secure,httponly,session,expiry);
        };
JS
    $set->($uri->host, $uri->path, $key, $val, 0, 0, 0, $maxage ? time+$maxage : 0);
};

sub save {
    croak 'save is not yet implemented'
}

1;

__END__

=head1 SEE ALSO

L<https://developer.mozilla.org/en/nsICookieManager> -
nsICookieManager documentation

L<HTTP::Cookies> - the interface used

=head1 REPOSITORY

The public repository of this module is 
L<http://github.com/Corion/www-mechanize-firefox>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2009-2014 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
