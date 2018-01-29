package Firefox::Marionette::Transport::Role;
use strict;

use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Net::Protocol::JSONWire qw(decode_message encode_message );

use Moo::Role;

requires 'socket_write';
requires 'handler';

has 'message_id' => (
    is => 'rw',
    default => 1,
);

sub get_message_id( $self ) {
    $self->{message_id}++
}

sub send( $self, $type, @args ) {
    my $id = $self->get_message_id;
    $self->socket_write( encode_message( [ $type, $id, @args ]));
    Future->done($id)
}

sub on_response( $self, $buffer_r ) {
    while( my $msg = decode_message( $buffer_r )) {
        $self->handler( $msg );
    }
}

1;