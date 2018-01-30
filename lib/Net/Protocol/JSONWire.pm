package Net::Protocol::JSONWire;
use strict;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';

use JSON qw(encode_json decode_json);

use Exporter 'import';
our @EXPORT_OK = qw(decode_message encode_message valid_input);

=head1 NAME

Net::Protocol::JSONWire - parse the JSON Wire / Mozilla Marionette protocol (v2 and v3)

=head1 SYNOPSIS

  use Net::Protocol::JSONWire qw(decode_message encode_message);

  my $buffer = '';
  NEED_MORE_INPUT:
      $buffer .= read_data_from( $fh );
      while( my $msg = decode_message( \$buffer )) {
	      print $msg->[0], "\n"; # type
		  # Reply with "Hello World"
		  print $client encode_message( [ 1, $msg->[1], undef, { value => 'Hello World' }]);
	  }
  redo NEED_MORE_INPUT;

=head1 FUNCTIONS

=head2 C<< decode_message >>

  while( $buffer and my $decoded = decode_message( \$buffer )) {
  };

Removes the next message from the start of C<$buffer> and returns the decoded
payload.

=cut

sub decode_message( $buffer_r ) {
    if( defined( my $msg = valid_input( $buffer_r ))) {
        $$buffer_r =~ s!^[0-9]+:!!;
        substr $$buffer_r, 0, length $msg, '';
	    return decode_json( $msg )
	} else {
	    return undef
	}
}

=head2 C<< encode_message >>

  print $out_fh encode_message( 1, $messageId++, undef, {value => "Hello World"} )

Returns a string that represents the encoded message.

=cut

sub encode_message( $data ) {
    my $payload = encode_json( $data );
	return sprintf "%d:%s", length $payload, $payload;
}

=head2 C<< valid_input >>

  my $buffer = '35:[0,"echo",{ value: "Hello World" }]';
  while( my $msg = valid_input( \$buffer )) {
      print "Found $msg\n";

	  # Remove message from the start of the buffer
	  substr $buffer, 0, length $msg+1+length(length($msg)), '';
  }

=cut

sub valid_input( $buffer_r ) {
    if(
        $$buffer_r =~ /^\s*([0-9]+)\s*:([\[\{\"0-9].*)/
	and length $2 >= $1
	) {
        return substr $2, 0, $1
    } else {
        return undef
    }
}

1;

=head1 SEE ALSO

L<Firefox::Marionette> - drive Firefox using the JSONWire/Marionette
protocol directly



L<Marionette homepage|https://firefox-source-docs.mozilla.org/testing/marionette/marionette/index.html>

L<Marionette protocol|https://firefox-source-docs.mozilla.org/testing/marionette/marionette/Protocol.html>
What sparse documentation of the protocol there is

=cut