package Firefox::Marionette::Transport::Role;
use strict;

use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Net::Protocol::JSONWire qw(decode_message encode_message );

use Moo::Role;

requires 'socket_write';
requires 'handler';


1;