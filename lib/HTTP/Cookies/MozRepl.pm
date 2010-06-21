package HTTP::Cookies::MozRepl;
use strict;
use MozRepl::RemoteObject;
use parent 'HTTP::Cookies';
use Carp qw[croak];

use vars qw[$VERSION];
$VERSION = '0.21';

=head1 NAME

HTTP::Cookies::MozRepl - retrieve cookies from a live FireFox instance

=head1 SYNOPSIS

  use HTTP::Cookies::MozRepl;
  my $cookie_jar = HTTP::Cookies::MozRepl->new();
  # use just like HTTP::Cookies

=head1 DESCRIPTION

This package overrides the load() and save() methods of HTTP::Cookies
so it can work with a live FireFox instance.

Note: To use this module, FireFox must be running and it must
have the C<mozrepl> extension installed.

See L<HTTP::Cookies>.

=head1 Reusing an existing connection

If you already have an existing connection to FireFox
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
    $e->bridge->queued(sub{
        while ($e->hasMoreElements) {
            my $cookie = $e->getNext()->QueryInterface($nsICookie);
            
            my @values = map { $cookie->{$_} } (qw(name value path host                      isSecure expires));
            $self->set_cookie( undef,       @values[0,   1,    2,   3, ], undef, undef, $values[ 4 ],    time-$values[5], 0 );
        };
    });
}

sub save {
    croak 'save is not yet implemented'
}

1;

__END__

=head1 SEE ALSO

L<https://developer.mozilla.org/en/nsICookieManager> -
nsICookieManager documentation

L<HTTP::Cookies> - the used interface

=head1 REPOSITORY

The public repository of this module is 
L<http://github.com/Corion/www-mechanize-firefox>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2009 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
