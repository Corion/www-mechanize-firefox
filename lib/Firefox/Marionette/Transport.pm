package Firefox::Marionette::Transport;
use strict;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';

our $VERSION = '1.00';

=head1 NAME

Firefox::Marionette::Transport - choose the best transport backend

=cut

our @loops = (
    ['Mojo/IOLoop.pm' => 'Firefox::Marionette::Transport::Mojo' ],
    ['AnyEvent.pm'    => 'Firefox::Marionette::Transport::AnyEvent'],
    ['AE.pm'          => 'Firefox::Marionette::Transport::AnyEvent'],
    # POE support would be nice
    ['IO::Async.pm'   => 'Firefox::Marionette::Transport::IOAsync' ],
    
    # The fallback, will always catch due to loading strict (for now)
    ['strict.pm'      => 'Firefox::Marionette::Transport::AnyEvent'],
);
our $implementation;

=head1 METHODS

=head2 C<< Firefox::Marionette::Transport->new() >>

    my $ua = Firefox::Marionette::Transport->new();

Creates a new instance of the transport using the "best" event loop
for implementation. The default event loop is currently L<AnyEvent>.

=cut

sub new($factoryclass, @args) {
    $implementation ||= $factoryclass->best_implementation();
    
    # return a new instance
    $implementation->new(@args);
}

sub best_implementation( $class, @candidates ) {
    
    if(! @candidates) {
        @candidates = @loops;
    };

    # Find the currently running/loaded event loop(s)
    #use Data::Dumper;
    #warn Dumper \%INC;
    #warn Dumper \@candidates;
    my @applicable_implementations = map {
        $_->[1]
    } grep {
        $INC{$_->[0]}
    } @candidates;
    
    # Check which one we can load:
    for my $impl (@applicable_implementations) {
        if( eval "require $impl; 1" ) {
            return $impl;
        };
    };
};

1;

=head1 REPOSITORY

The public repository of this module is
L<https://github.com/Corion/www-mechanize-firefox>.

=head1 SUPPORT

The public support forum of this module is L<https://perlmonks.org/>.

=head1 BUG TRACKER

Please report bugs in this module via the RT CPAN bug queue at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=WWW-Mechanize-Firefox>
or via mail to L<www-mechanize-Firefox-Bugs@rt.cpan.org|mailto:www-mechanize-Firefox-Bugs@rt.cpan.org>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2010-2018 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut

package Firefox::Marionette::Transport::Mojolicious;
package Firefox::Marionette::Transport::IOAsync;
1;