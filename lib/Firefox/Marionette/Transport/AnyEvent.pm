package Firefox::Marionette::Transport::AnyEvent;
use strict;
use Moo 2;

use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Scalar::Util 'weaken';

use Carp qw(croak);

use AnyEvent;
use AnyEvent::Future qw(as_future_cb);
use AnyEvent::Handle;

our $VERSION = '1.00';
our @CARP_NOT = ();

=head1 SYNOPSIS

    Firefox::Marionette::Transport::AnyEvent->connect( host => $host, port => $port )
    ->then(sub {
        my( $connection ) = @_;
        print "We are connected\n";
    });

=cut

has connection => (
    is => 'rw',
);

has handler => (
    is => 'rw',
);

sub connect( $self, %options ) {

    local @CARP_NOT = (@CARP_NOT, 'Firefox::Marionette::Transport');

    my $result = AnyEvent::Future->new();
    my $handler = delete $options{ handler }
        or croak "Need a handler object";
    $self->handler( $handler );

    my $connection;
    weaken( my $weakself = $self );
    $connection = AnyEvent::Handle->new(
        connect => [$options{ host }, $options{ port }],
        on_connect => sub( $handle, $host, $port, $retry ) {
            undef $connection;
            $weakself->connection( $handle );
            $result->done( $handle )
        },
        on_connect_error => sub( $handle, $message ) {
            $result->fail( $message, connect => $message )
        },
        on_read => sub( $handle ) {
            $handler->on_data( \$handle->{rbuf} );
        },
    );
    
    $result
}

sub socket_write( $self, $str ) {
    $self->connection->push_write( $str );
    $self->future->done(1);
}

sub close( $self ) {
    my $c = delete $self->{connection};
    $c->push_shutdown
        if $c;
}

sub future {
    AnyEvent::Future->new
}

=head2 C<< $transport->sleep( $seconds ) >>

    $transport->sleep( 10 )->get; # wait for 10 seconds

Returns a Future that will be resolved in the number of seconds given.

=cut

sub sleep( $self, $seconds ) {
    AnyEvent::Future->new_delay( after => $seconds );
}

1;

=head1 REPOSITORY

The public repository of this module is
L<https://github.com/Corion/www-mechanize-chrome>.

=head1 SUPPORT

The public support forum of this module is L<https://perlmonks.org/>.

=head1 BUG TRACKER

Please report bugs in this module via the RT CPAN bug queue at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=WWW-Mechanize-Chrome>
or via mail to L<www-mechanize-Chrome-Bugs@rt.cpan.org|mailto:www-mechanize-Chrome-Bugs@rt.cpan.org>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2010-2018 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
