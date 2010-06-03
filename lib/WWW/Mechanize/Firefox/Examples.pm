package WWW::Mechanize::Firefox::Examples;

###############################################################################
#
# Examples - WWW::Mechanize::Firefox examples.
#
# A documentation only module showing the examples that are
# included in the WWW::Mechanize::Firefox distribution. This
# file was generated automatically via the gen_examples_pod.pl
# program that is also included in the examples directory.
#
# Copyright 2000-2010, John McNamara, jmcnamara@cpan.org
#
# Documentation after __END__
#

use strict;
use vars qw($VERSION);
$VERSION = '0.19';

1;

__END__

=pod

=head1 NAME

Examples - WWW::Mechanize::Firefox example programs.

=head1 DESCRIPTION

This is a documentation only module showing the examples that are
included in the L<WWW::Mechanize::Firefox> distribution.

This file was auto-generated via the C<gen_examples_pod.pl>
program that is also included in the examples directory.

=head1 Example programs

The following is a list of the 7 example programs that are included in the WWW::Mechanize::Firefox distribution.

=over

=item * L<Example: open-local-file.pl> Open a local file in Firefox

=item * L<Example: open-url.pl> Open an URL in Firefox

=item * L<Example: screenshot.pl> Take a screenshot of a website

=item * L<Example: dump-links.pl> Dump links on a webpage

=item * L<Example: manipulate-javascript.pl> Make changes to Javascript values in a webpage

=item * L<Example: javascript.pl> Execute Javascript in the webpage context

=item * L<Example: urlbar.pl> Listen to changes in the location bar

=back

=head2 Example: open-local-file.pl

    use strict;
    use WWW::Mechanize::FireFox;
    
    my $mech = WWW::Mechanize::FireFox->new();
    $mech->get_local('datei.html');
    
    <>;

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.18/examples/open-local-file.pl>

=head2 Example: open-url.pl

    use strict;
    use WWW::Mechanize;
    
    my $mech = WWW::Mechanize::FireFox->new();
    $mech->get('http://www.perlworkshop.de');
    
    <>;

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.18/examples/open-url.pl>

=head2 Example: screenshot.pl

    #!perl -w
    use strict;
    use WWW::Mechanize::Firefox;
    use Getopt::Long;
    use Pod::Usage;
    
    GetOptions(
        'mozrepl|m:s' => \my $mozrepl,
        'outfile|o:s' => \my $outfile,
    ) or pod2usage();
    $outfile ||= 'screenshot.png';
    
    my @args;
    if (! @ARGV) {
        push @args, tab => 'current';
    };
    
    my $mech = WWW::Mechanize::Firefox->new(
        launch => 'firefox',
        @args
    );
    
    if (@ARGV) {
        $mech->get($ARGV[0]);
    };
    my $png = $mech->content_as_png();
    
    open my $out, '>', $outfile
        or die "Couldn't create '$outfile': $!";
    binmode $out;
    print {$out} $png;
    
    =head1 NAME
    
    screenshot.pl - take a screenshot of a webpage
    
    =head1 SYNOPSIS
    
    screenshot.pl [options] [url]
    
    Options:
       --outfile        name of output file
       --mozrepl        connection string to Firefox
    
    =head1 OPTIONS
    
    =over 4
    
    =item B<--outfile>
    
    Name of the output file. The image will always be written
    in PNG format.
    
    =item B<--mozrepl>
    
    Connection information for the mozrepl instance to use.
    
    =back
    
    =head1 DESCRIPTION
    
    B<This program> will take a screenshot
    of the given URL (including plugins) and
    write it to the given file or the file C<screenshot.png>.
    
    =cut

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.18/examples/screenshot.pl>

=head2 Example: dump-links.pl

    use strict;
    use WWW::Mechanize::FireFox;
    
    my $mech = WWW::Mechanize::FireFox->new();
    $mech->get_local('links.html');
    
    $mech->highlight_node(
      $mech->selector('a.download'));
      
    print $_->{href}, " - ", $_->{innerHTML}, "\n"
      for $mech->selector('a.download');
    
    <>;

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.18/examples/dump-links.pl>

=head2 Example: manipulate-javascript.pl

    use strict;
    use WWW::Mechanize::FireFox;
    
    my $mech = WWW::Mechanize::FireFox->new();
    $mech->get_local('javascript.html');
    
    my ($val,$type) = $mech->eval_in_page(<<'JS');
        secret
    JS
    
    if ($type ne 'string') {
        die "Unbekannter Ergebnistyp: $type";
    };
    print "Das Kennwort ist $val";
    
    $mech->value('pass',$val);
    
    <>;

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.18/examples/manipulate-javascript.pl>

=head2 Example: javascript.pl

    use strict;
    use WWW::Mechanize::FireFox;
    
    my $mech = WWW::Mechanize::FireFox->new();
    $mech->get_local('links.html');
    
    $mech->eval_in_page(<<'JS');
        alert('Hallo Frankfurt.pm');
    JS
    
    <>;

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.18/examples/javascript.pl>

=head2 Example: urlbar.pl

    use strict;
    use lib 'C:/Projekte/MozRepl-RemoteObject/lib';
    use WWW::Mechanize::FireFox;
    use Time::HiRes;
    
    my $mech = WWW::Mechanize::FireFox->new(
        #log => ['debug'],
    );
    $mech->get_local('datei.html');
    
    my $mk_listener = $mech->repl->declare(<<'JS');
    function (myListener,source) {
        myListener.source = source;
        const STATE_START = Components.interfaces.nsIWebProgressListener.STATE_START;
        const STATE_STOP = Components.interfaces.nsIWebProgressListener.STATE_STOP;
        var callbacks = ['onStateChange',
                       'onLocationChange',
                       "onProgressChange",
    		   "onStatusChange",
    		   "onSecurityChange",
                            ];
        for (var h in callbacks) {
            var e = callbacks[h];
            if (! myListener[e]) {
                myListener[e] = function(){}
            };
        };
        myListener.QueryInterface = function(aIID) {
    	if (aIID.equals(Components.interfaces.nsIWebProgressListener) ||
    	   aIID.equals(Components.interfaces.nsISupportsWeakReference) ||
    	   aIID.equals(Components.interfaces.nsISupports))
    	    return this;
    	throw Components.results.NS_NOINTERFACE;
        };
        return myListener
    }
    JS
    
    =begin JSDoc
    
          "onStateChange": handlers[
          function(aWebProgress, aRequest, aFlag, aStatus)
          {
           // If you use myListener for more than one tab/window, use
           // aWebProgress.DOMWindow to obtain the tab/window which triggers the state change
           if(aFlag & STATE_START)
           {
    	 // This fires when the load event is initiated
            onLoadStart(aWebProgress,aRequest,aStatus);
           }
           if(aFlag & STATE_STOP)
           {
    	 // This fires when the load finishes
            onLoadStop(aWebProgress,aRequest,aStatus);
           }
          },
    
          "onLocationChange": function(aProgress, aRequest, aURI)
          {
           // This fires when the location bar changes; i.e load event is confirmed
           // or when the user switches tabs. If you use myListener for more than one tab/window,
           // use aProgress.DOMWindow to obtain the tab/window which triggered the change.
          },
    
          // For definitions of the remaining functions see related documentation
          "onProgressChange": function(aWebProgress, aRequest, curSelf, maxSelf, curTot, maxTot) { },
          "onStatusChange": function(aWebProgress, aRequest, aStatus, aMessage) { },
          "onSecurityChange": function(aWebProgress, aRequest, aState) { },
        };
    =cut
    
    sub onStateChange {
        my ($progress,$request,$flag,$status) = @_;
        print "@_\n";
    }
    
    sub onLocationChange {
        my ($progress,$request,$uri) = @_;
        print "Location :", $uri->{spec},"\n";
    }
    
    my $NOTIFY_STATE_DOCUMENT = $mech->repl->expr('Components.interfaces.nsIWebProgress.NOTIFY_STATE_DOCUMENT');
    sub event_listener {
        my ($source,%handlers) = @_;
        my ($obj) = $mech->repl->expr('new Object');
        for my $key (keys %handlers) {
            $obj->{$key} = $handlers{$key};
        };
        my $lsn = $mk_listener->($obj,$source);
        $lsn->__release_action('self.source.removeEventListener(self)');
        $source->addProgressListener($lsn,$NOTIFY_STATE_DOCUMENT);
        $lsn;
    };
    
    my $browser = $mech->repl->expr('window.getBrowser()');
    
    my $eventlistener = event_listener(
        $browser,
        onLocationChange => \&onLocationChange,
    );
    
    while (1) {
        $mech->repl->poll();
        sleep 1;
    };


Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.18/examples/urlbar.pl>

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

Contributed examples contain the original author's name.

=head1 COPYRIGHT

Copyright 2010, Max Maischein.

All Rights Reserved. This module is free software. It may be used, redistributed and/or modified under the same terms as Perl itself.

=cut
