package Firefox::Marionette::Driver;
use 5.010; # for //
use strict;
use Moo 2;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Future;
use Carp qw(croak carp);
use JSON;
use Data::Dumper;
use Firefox::Marionette::Transport;
use Net::Protocol::JSONWire qw( decode_message encode_message );
use Scalar::Util 'weaken', 'isweak';
use Try::Tiny;

our $VERSION = '1.00';
our @CARP_NOT;

sub _build_log( $self ) {
    require Log::Log4perl;
    Log::Log4perl->get_logger(__PACKAGE__);
}

has '_log' => (
    is => 'lazy',
    default => \&_build_log,
);

has 'host' => (
    is => 'ro',
    default => 'localhost',
);

has 'port' => (
    is => 'ro',
    default => 2828,
);

has 'receivers' => (
    is => 'lazy',
    default => sub { {} },
);

has '_on_message' => (
    is => 'rw',
);

has '_one_shot' => (
    is => 'lazy',
    default => sub { [] },
);

has 'listener' => (
    is => 'lazy',
    default => sub { {} },
);

has 'transport' => (
    is => 'rw',
);

has 'remote_info' => (
    is => 'rw',
);

sub tab( $self ) { $self->{tab} }
sub future( $self ) { $self->transport->future }

sub on_message( $self, $new_message=0 ) {
    if( $new_message ) {
        $self->{_on_message} = $new_message
    } elsif( ! defined $new_message ) {
        $self->{_on_message} = undef
    };
    $self->{_on_message}
}

sub add_listener( $self, $event, $callback ) {
    my $listener = Firefox::Marionette::EventListener->new(
        protocol => $self,
        callback => $callback,
        event    => $event,
    );
    $self->listener->{ $event } ||= [];
    push @{ $self->listener->{ $event }}, $listener;
    $listener
}

sub remove_listener( $self, $listener ) {
    my $event = $listener->{event};
    $self->listener->{ $event } ||= [];
    @{$self->listener->{ $event }} = grep { $_ != $listener }
                                     grep { defined $_ }
                                     @{$self->listener->{ $event }};
}

sub log( $self, $level, $message, @args ) {
    my $logger = $self->_log;
    if( !@args ) {
        $logger->$level( $message )
    } else {
        my $enabled = "is_$level";
        $logger->$level( join " ", $message, Dumper @args )
            if( $logger->$enabled );
    };
}

sub connect( $self, %args ) {
    # If we are still connected to a different tab, disconnect from it
    if( $self->transport and ref $self->transport ) {
        $self->transport->close();
    };
    
    my $transport = delete $args{ transport }
                    || $self->transport
                    || 'Firefox::Marionette::Transport'
                    ;
    if( ! ref $transport ) { # it's a classname
        (my $transport_module = $transport) =~ s!::!/!g;
        $transport_module .= '.pm';
        require $transport_module;
        $transport = $transport->new;
    };
    $self->transport( $transport );

    my $connected = $transport->connect(
        handler => $self,
        log     => sub { $self->log( @_ ) },
        host    => $self->host,
        port    => $self->port,
    );

    if( $args{ new_tab }) {
        $connected = $connected->then( sub {
            $self->new_tab()
        })->then(sub( $info ) {
            $self->log('debug', "Created new tab", $info );
            $self->{tab} = $info;
            return Future->done( $info->{webSocketDebuggerUrl} );
        });

    } elsif( defined $args{ tab } and $args{ tab } =~ /^\d+$/ ) {
        $connected = $connected->then( sub {
            $self->list_tabs()
        }) ->then(sub( @tabs ) {
            $self->log('debug', "Attached to tab $args{tab}", @tabs );
            $self->{tab} = $tabs[ $args{ tab }];
            return Future->done( $self->{tab}->{webSocketDebuggerUrl} );
        });

    } elsif( ref $args{ tab } eq 'Regexp') {
        # Let's assume that the tab is a regex:

        $connected = $connected->then(sub {
            $self->list_tabs()
        })->then(sub( @tabs ) {
            (my $tab) = grep { $_->{title} =~ /$args{ tab }/ } @tabs;

            if( ! $tab ) {
                croak "Couldn't find a tab matching /$args{ tab }/";
            } elsif( ! $tab->{webSocketDebuggerUrl} ) {
                local @CARP_NOT = ('Future',@CARP_NOT);
                croak "Found the tab but it didn't have a webSocketDebuggerUrl";
            };
            $self->{tab} = $tab;
            $self->log('debug', "Attached to tab $args{tab}", $tab );
            return Future->done( $self->{tab}->{webSocketDebuggerUrl} );
        });

    } elsif( ref $args{ tab } ) {
        # Let's assume that the tab is a tab object:
        $connected = $connected->then(sub {
            $self->list_tabs()
        })->then(sub( @tabs ) {
            (my $tab) = grep { $_->{id} eq $args{ tab }->{id}} @tabs;
            $self->{tab} = $tab;
            $self->log('debug', "Attached to tab $args{tab}", $tab );
            return Future->done( $self->{tab}->{webSocketDebuggerUrl} );
        });

    } elsif( $args{ tab } ) {
        # Let's assume that the tab is the tab id:
        $connected = $connected->then(sub {
            $self->list_tabs()
        })->then(sub( @tabs ) {
            (my $tab) = grep { $_->{id} eq $args{ tab }} @tabs;
            $self->{tab} = $tab;
            $self->log('debug', "Attached to tab $args{tab}", $tab );
            return Future->done( $self->{tab}->{webSocketDebuggerUrl} );
        });

    } else {
        # Attach to the first available tab we find
            
            #$self->list_tabs()
            #Future->done();
        #})->then(sub( @tabs ) {
        #    (my $tab) = grep { $_->{webSocketDebuggerUrl} } @tabs;
        #    $self->log('debug', "Attached to some tab", $tab );
        #    $self->{tab} = $tab;
        #    return Future->done( $self->{tab}->{webSocketDebuggerUrl} );
        #});
    };
    
    $connected
};

sub close( $self ) {
    if( my $t = $self->transport) {
        $t->close() if ref $t;
    };
};

sub sleep( $self, $seconds ) {
    $self->transport->sleep($seconds);
};

sub DESTROY( $self ) {
    delete $self->{ua};
    $self->close;
}

sub one_shot( $self, @events ) {
    my $result = $self->transport->future;
    my $ref = $result;
    weaken $ref;
    my %events;
    undef @events{ @events };
    push @{ $self->_one_shot }, { events => \%events, future => \$ref };
    $result
};

sub on_response( $self, $response ) {
    if( 'HASH' eq ref $response ) {
        # Maybe that initial "hello" message from the server?
        if( $response->{marionetteProtocol} ) {
            $self->remote_info( $response );
        };

    } elsif( 'ARRAY' eq ref $response ) {
        # A response to a command we sent
        my( $type, $id, $error, $result ) = @$response;
        if( ! $type ) {
            # Generic message/command, dispatch that:
            if( $error ) {
                $self->log('error', "Error response from Firefox", $error );
                return;
            };

            (my $handler) = grep { exists $_->{events}->{ $response->{method} } and ${$_->{future}} } @{ $self->_one_shot};
            my $handled;
            if( $handler ) {
                $self->log( 'trace', "Dispatching one-shot event", $response );
                ${ $handler->{future} }->done( $response );

                # Remove the handler we just invoked
                @{ $self->_one_shot} = grep { $_ and ${$_->{future}} and $_ != $handler } @{ $self->_one_shot};

                $handled++;
            };

            if( my $listeners = $self->listener->{ $response->{method} } ) {
                if( $self->{log}->is_trace ) {
                    $self->log( 'trace', "Notifying listeners", $response );
                } else {
                    $self->log( 'debug', sprintf "Notifying listeners for '%s'", $response->{method} );
                };
                for my $listener (@$listeners) {
                    $listener->notify( $response );
                };

                $handled++;
            };

            if( $self->on_message ) {
                if( $self->{log}->is_trace ) {
                    $self->log( 'trace', "Dispatching message", $response );
                } else {
                    $self->log( 'debug', sprintf "Dispatching message '%s'", $response->{method} );
                };
                $self->on_message->( $response );

                $handled++;
            };

            if( ! $handled ) {
                if( $self->{log}->is_trace ) {
                    $self->log( 'trace', "Ignored message", $response );
                } else {
                    $self->log( 'debug', sprintf "Ignored message '%s'", $response->{method} );
                };
            };
        } else {
            # A response
            my $id = $response->[1];
            my $receiver = delete $self->{receivers}->{ $id };

            if( ! $receiver) {
                $self->log( 'debug', "Ignored response to unknown receiver", $response )

            } elsif( my $error = $response->[2] ) { # error
                $self->log( 'debug', "Replying to error $response->{id}", $response );
                $receiver->die( "remote error", "error" => $error );
            } else {
                $self->log( 'trace', "Got reply to $id", $response->[3] );
                $receiver->done( $response->[3] );
            };
        };
    };
}

has 'message_id' => (
    is => 'rw',
    default => 1,
);

sub next_sequence( $self ) {
    $self->{message_id}++
}

sub current_sequence( $self ) {
    $self->{message_id}
}

sub on_data( $self, $buffer_r ) {
    while( my $msg = decode_message( $buffer_r )) {
        $self->on_response( $msg );
    }
}

sub send_command( $self, $method, @args ) {
    my $id = $self->next_sequence;
    
    my $resp = $self->transport->future;
    
    $self->receivers->{ $id } = $resp;
    my $msg = [ +0, 0+$id, $method, @args ];
    $self->log('trace', "Send message", $msg );
    
    $self->transport->socket_write( encode_message( $msg ));
    $resp
}

sub send_response( $self, @args ) {
    my $id = $self->next_sequence;
    $self->transport->socket_write( encode_message( [ +1, $id, @args ]));
}

=head2 C<< $chrome->send_packet >>

  $chrome->send_packet('????',
      accept => JSON::true,
  );

Sends a JSON packet to the remote end

=cut

sub send_packet( $self, $topic, %params ) {
    $self->_send_packet( $topic, %params )
}

=head2 C<< $chrome->send_message >>

  my $future = $chrome->send_message('DOM.querySelectorAll',
      selector => 'p',
      nodeId => $node,
  );
  my $nodes = $future->get;

This function expects a response. The future will not be resolved until Chrome
has sent a response to this query.

=cut

sub send_message( $self, $method, %params ) {
    my $response = $self->future;
    # We add our response listener before we've even sent our request to
    # Chrome. This ensures that no amount of buffering etc. will make us
    # miss a reply from Chrome to a request
    my $f;
    $f = $self->_send_packet( $response, $method, %params );
    $f->on_ready( sub { undef $f });
    $response
}

=head2 C<< $chrome->evaluate >>

=cut

sub evaluate( $self, $string ) {
    $self->send_message('Runtime.evaluate',
        expression => $string,
        returnByValue => JSON::true
    )
};

=head2 C<< $chrome->eval >>

=cut

sub eval( $self, $string ) {
    $self->evaluate( $string )->then(sub( $result ) {
        Future->done( $result->{result}->{value} )
    });
};

=head2 C<< $chrome->version_info >>

    print $chrome->version_info->get->{"Protocol-Version"};

=cut

sub version_info($self) {
    $self->json_get( 'version' )->then( sub( $payload ) {
        Future->done( $payload );
    });
};

=head2 C<< $chrome->protocol_version >>

    print $chrome->protocol_version->get;

=cut

sub protocol_version($self) {
    $self->version_info->then( sub( $payload ) {
        Future->done( $payload->{"Protocol-Version"});
    });
};

=head2 C<< $chrome->get_domains >>

=cut

sub get_domains( $self ) {
    $self->send_message('Schema.getDomains');
}

=head2 C<< $chrome->list_tabs >>

  my @tabs = $chrome->list_tabs->get();

=cut

sub list_tabs( $self, $type = 'page' ) {
    return $self->json_get('list')->then(sub( $info ) {
        @$info = grep { defined $type ? $_->{type} eq $type : 1 } @$info;
        return Future->done( @$info );
    });
};

=head2 C<< $chrome->new_tab >>

    my $new_tab = $chrome->new_tab('https://www.google.com')->get;

=cut

sub new_tab( $self, $url=undef ) {
    my $u = $url ? '?' . $url : '';
    $self->json_get('new' . $u)
};

=head2 C<< $chrome->activate_tab >>

=cut

sub activate_tab( $self, $tab ) {
    my $url = $self->build_url( domain => 'activate/' . $tab->{id} );
    $self->ua->http_get( $url );
};

=head2 C<< $chrome->close_tab >>

=cut

sub close_tab( $self, $tab ) {
    my $url = $self->build_url( domain => 'close/' . $tab->{id} );
    $self->ua->http_get( $url, headers => { 'Connection' => 'close' } )
    ->catch(
        sub{ #use Data::Dumper; warn Dumper \@_;
             Future->done
        });
};

package
    Chrome::DevToolsProtocol::EventListener;
use strict;
use Carp 'croak';
use Scalar::Util 'weaken';
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';

sub new( $class, %args ) {
    croak "Need a callback" unless $args{ callback };
    croak "Need a DevToolsProtocol in protocol" unless $args{ protocol };

    weaken $args{ protocol };

    bless {
        %args,
    } => $class
}

sub notify( $self, @info ) {
    $self->{callback}->( @info )
}

sub unregister( $self ) {
    $self->{protocol}->remove_listener( $self )
        if $self->{protocol}; # it's a weak ref so it might have gone away already
}

sub DESTROY {
    $_[0]->unregister
}

1;

=head1 SEE ALSO

Chrome DevTools at L<https://chromedevtools.github.io/devtools-protocol/1-2>

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