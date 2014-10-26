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
$VERSION = '0.78';

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

The following is a list of the 12 example programs that are included in the WWW::Mechanize::Firefox distribution.

=over

=item * L<Example: open-local-file.pl> Open a local file in Firefox

=item * L<Example: open-url.pl> Open an URL in Firefox

=item * L<Example: screenshot.pl> Take a screenshot of a website

=item * L<Example: dump-links.pl> Dump links on a webpage

=item * L<Example: bcat.pl> Send console text to the browser

=item * L<Example: manipulate-javascript.pl> Make changes to Javascript values in a webpage

=item * L<Example: javascript.pl> Execute Javascript in the webpage context

=item * L<Example: js-console.pl> Send messages to the Error Console

=item * L<Example: tail-console.pl> Display messages from the Error Console to STDOUT

=item * L<Example: urlbar.pl> Listen to changes in the location bar

=item * L<Example: fullscreen.pl> Switch the browser to full screen

=item * L<Example: proxy-settings.pl> Change the proxy settings and other settings in Firefox

=back

=head2 Example: open-local-file.pl

    #!perl -w
    use strict;
    use WWW::Mechanize::Firefox;
    
    my $mech = WWW::Mechanize::Firefox->new();
    $mech->get_local('datei.html');
    
    <>;

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.78/examples/open-local-file.pl>

=head2 Example: open-url.pl

    #!perl -w
    use strict;
    use WWW::Mechanize::Firefox;
    
    my $mech = WWW::Mechanize::Firefox->new(
        activate => 1, # bring the tab to the foreground
    );
    $mech->get('http://www.perlworkshop.de');
    
    <>;

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.78/examples/open-url.pl>

=head2 Example: screenshot.pl

    #!perl -w
    use strict;
    use WWW::Mechanize::Firefox;
    use Getopt::Long;
    use Pod::Usage;
    
    GetOptions(
        'mozrepl|m:s' => \my $mozrepl,
        'outfile|o:s' => \my $outfile,
        'tab|t:s' => \my $tab,
        'target-width|tw:s' => \my $target_w,
        'target-height|th:s' => \my $target_h,
        'target-scale|s:s' => \my $target_scale,
        'target-scale-x|sx:s' => \my $target_scale_w,
        'target-scale-y|sy:s' => \my $target_scale_h,
        'current|c' => \my $current,
    ) or pod2usage();
    $outfile ||= 'screenshot.png';
    
    my @args;
    if (! @ARGV) {
        push @args, tab => 'current';
    };
    
    if ($tab) {
        $tab = qr/$tab/;
    } elsif ($current) {
        $tab = $current
    };
    
    my $mech = WWW::Mechanize::Firefox->new(
        launch => 'firefox',
        create => 1,
        tab => $tab,
        autoclose => (!$tab),
        @args
    );
    
    if (@ARGV) {
        $mech->get($ARGV[0]);
    };
    
    my $png = $mech->content_as_png(undef,undef,
        {
            width => $target_w,
            height => $target_h,
            scalex => ($target_scale_w||$target_scale),
            scaley => ($target_scale_h||$target_scale),
        }
    );
    
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
       --tab            name of the tab title to use
       --current        use currently active tab
       --target-width   width of target image (in pixels)
       --target-height  height of target image (in pixels)
       --target-scale   scale of target image (ratio)
    
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

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.78/examples/screenshot.pl>

=head2 Example: dump-links.pl

    #!perl -w
    use strict;
    use WWW::Mechanize::Firefox;
    
    my $mech = WWW::Mechanize::Firefox->new();
    $mech->get_local('links.html');
    
    $mech->highlight_node(
      $mech->selector('a.download'));
      
    print $_->{href}, " - ", $_->{innerHTML}, "\n"
      for $mech->selector('a.download');
    
    <>;
    
    =head1 NAME
    
    dump-links.pl - Dump links on a webpage
    
    =head1 SYNOPSIS
    
    dump-links.pl
    
    =head1 DESCRIPTION
    
    This program demonstrates how to read elements out of the Firefox
    DOM and how to get at text within nodes.
    
    It also demonstrates how you can modify elements in a webpage.
    
    =cut

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.78/examples/dump-links.pl>

=head2 Example: bcat.pl

Find out whether we have HTML:
if (! $encode_type) {
    #!perl -w
    use strict;
    use WWW::Mechanize::Firefox;
    use Getopt::Long;
    use Pod::Usage;
    use Cwd qw(getcwd);
    
    GetOptions(
        'mozrepl|m:s' => \my $mozrepl,
        'tab:s' => \my $tab,
        'current|c' => \my $use_current_tab,
        'close|q' => \my $close,
        'title|t:s' => \my $title,
        'type:s' => \my $encode_type,
        #'focus|f' => \my $focus,
    ) or pod2usage();
    
    $tab = $use_current_tab ? 'current'
           : $tab ? qr/$tab/
           : undef
           ;
    
    $title ||= getcwd;
    
    my $mech = WWW::Mechanize::Firefox->new(
        tab     => $tab,
        repl    => $mozrepl,
        create  => 1,
        autoclose => $close,
    );
    
    local $/;
    binmode STDIN;
    my $html = <>;
    
    # Find out whether we have HTML:
    if (! $encode_type) {
        if ($html =~ /^\s*</sm) {
            $encode_type = 'html'
        } else {
            $encode_type = 'text',
        };
    };
    
    if ('text' eq $encode_type) {
        my %map = (
        '<' => '&lt;',
        '>' => '&gt;',
        '&' => '&amp;',
        );
        $html =~ s/([<>&])/$map{$1} || $1/ge;
        $html =~ s/\r?\n/<br>/g;
        $html = "<html><head><title>$title</title><body><pre>$html</pre></body></html>";
    };
    
    $mech->update_html($html);
    
    =head1 NAME
    
    bcat.pl - cat HTML to browser
    
    =head1 SYNOPSIS
    
      bcat.pl <index.html
    
    Options:
       --tab            title of tab to reuse (regex)
       --current        reuse current tab
       --title          title of the page
       --mozrepl        connection string to Firefox
       --close          automatically close the tab at the end of input
       --type TYPE      Fix the type to 'html' or 'text'
    
    =head1 OPTIONS
    
    =over 4
    
    =item B<--tab>
    
    Name of the tab to (re)use. A substring is enough.
    
    =item B<--current>
    
    Use the currently focused tab.
    
    =item B<--title>
    
    Give the title of the page that is shown.
    
    =item B<--close>
    
    Automatically close the tab when the input closes. This is good
    for displaying intermediate information.
    
    =item B<--type TYPE>
    
    Force the type to be either C<html> or C<text>. If the type is
    C<text>, line wrapping will be added.
    
    =item B<--mozrepl>
    
    Connection information for the mozrepl instance to use.
    
    =back
    
    =head1 DESCRIPTION
    
    B<This program> will display HTML read from STDIN
    in a browser tab.
    
    =head1 SEE ALSO
    
    The original C<bcat> utility which inspired this program
    at L<http://rtomayko.github.com/bcat/>.
    
    =cut

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.78/examples/bcat.pl>

=head2 Example: manipulate-javascript.pl

    #!perl -w
    use strict;
    use WWW::Mechanize::Firefox;
    
    my $mech = WWW::Mechanize::Firefox->new();
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
    
    =head1 NAME
    
    manipulate-javascript.pl - demonstrate how to manipulate Javascript in a page
    
    =head1 SYNOPSIS
    
    manipulate-javascript.pl
    
    =head1 DESCRIPTION
    
    This program demonstrates that you have write access to Javascript
    variables in Firefox and in webpages displayed through Firefox.
    
    =cut

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.78/examples/manipulate-javascript.pl>

=head2 Example: javascript.pl

    #!perl -w
    use strict;
    use WWW::Mechanize::Firefox;
    
    my $mech = WWW::Mechanize::Firefox->new();
    $mech->get_local('links.html');
    
    $mech->eval_in_page(<<'JS');
        alert('Hallo Frankfurt.pm');
    JS
    
    <>;
    
    =head1 NAME
    
    javascript.pl - execute Javascript in a page
    
    =head1 SYNOPSIS
    
    javascript.pl
    
    =head1 DESCRIPTION
    
    B<This program> demonstrates how to execute simple
    Javascript in a page.
    
    =cut

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.78/examples/javascript.pl>

=head2 Example: js-console.pl

    #!perl -w
    use strict;
    use WWW::Mechanize::Firefox;
    use Time::HiRes;
    use Getopt::Long;
    use Pod::Usage;
    
    GetOptions(
        'clear|c' => \my $clear,
        'mozrepl|m:s' => \my $mozrepl,
        'text|t:s' => \my $text,
    ) or pod2usage();
    
    my $mech = WWW::Mechanize::Firefox->new(
        #log => ['debug'],
        mozrepl => $mozrepl,
    );
    
    my $console = $mech->js_console;
    
    $mech->clear_js_errors
        if ($clear);
    
    if ($text) {
            $console->logStringMessage($text);
    } else {
        while (<>) {
            $console->logStringMessage($_);
        };
    };
    
    =head1 NAME
    
    js-console.pl - send STDIN to the Javascript Console
    
    =head1 SYNOPSIS
    
        echo "Hello World" | js-console.pl
    
    Options:
       --clear          Clear console before sending text
       --mozrepl        connection string to Firefox
       --close          automatically close the tab at the end of input
       --type TYPE      Fix the type to 'html' or 'text'
    
    =head1 OPTIONS
    
    =over 4
    
    =item B<--clear>
    
    Clear the console before sending the text.
    
    =item B<--text TEXT>
    
    Send the text TEXT instead of reading from STDIN.
    
    =item B<--mozrepl>
    
    Connection information for the mozrepl instance to use.
    
    =back
    
    =head1 DESCRIPTION
    
    This program sends text read from standard input to the
    Javascript Console in Firefox. This can be convenient
    if you want to do testing and log the start or stop
    of a test run to the console.
    
    =head1 SEE ALSO
    
    L<https://developer.mozilla.org/en/Error_Console>
    
    L<https://developer.mozilla.org/en/nsIConsoleService> - the underlying
    Console Service that also shows how to listen to events getting
    added.
    
    =cut

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.78/examples/js-console.pl>

=head2 Example: tail-console.pl

    #!perl -w
    use strict;
    use WWW::Mechanize::Firefox;
    use Time::HiRes;
    use Getopt::Long;
    use Pod::Usage;
    
    GetOptions(
        'mozrepl|m:s' => \my $mozrepl,
        'follow|f'    => \my $install_listener,
        'clear|c'     => \my $clear,
        'number|n:i'  => \my $lines,
    ) or pod2usage(2);
    $lines ||= 5;
    
    my $mech = WWW::Mechanize::Firefox->new(
        #log => ['debug'],
        mozrepl => $mozrepl,
    );
    
    sub install_listener {
        warn "Creating logListener";
        my $logListener = $mech->repl->declare(<<'JS');
        function(callback) {
            return {
                observe: callback,
                QueryInterface: function (iid) {
                    if (!iid.equals(Components.interfaces.nsIConsoleListener) &&
                        !iid.equals(Components.interfaces.nsISupports)) {
                            throw Components.results.NS_ERROR_NO_INTERFACE;
                    }
                    return this;
                },
            };
        }
    JS
    
        warn "Creating registerListener";
    
        my $registerListener = $mech->repl->declare(<<'JS');
            function (listener) {
                var aConsoleService = Components.classes["@mozilla.org/consoleservice;1"]
                    .getService(Components.interfaces.nsIConsoleService);
                aConsoleService.registerListener(listener);
            };
    JS
    
        my $listener = $logListener->(sub {output_message($_[0])});
        $registerListener->($listener);
    };
    
    sub output_message {
        print "$_[0]->{message}\n";
    };
    
    my $console = $mech->js_console;
    
    $mech->clear_js_errors
        if ($clear);
    
    output_message $_ for reverse (grep {defined} ($mech->js_errors)[-$lines..0]);
    
    if ($install_listener) {
        my $l = install_listener;
        while (1) {
            $mech->repl->poll;
            sleep 0.25;
        };
    };
    
    =head1 NAME
    
    js-console.pl - send STDIN to the Javascript Console
    
    =head1 SYNOPSIS
    
        tail-console.pl -f
    
    Options:
       --clear          Clear console before receiving new messages
       --follow         Read more messages as they are being added
       --mozrepl        connection string to Firefox
    
    =head1 OPTIONS
    
    =over 4
    
    =item B<--clear>
    
    Clear the console before sending the text.
    
    =item B<--follow>
    
    Keep watching the console and output text as it gets added.
    
    =item B<--mozrepl>
    
    Connection information for the mozrepl instance to use.
    
    =back
    
    =head1 DESCRIPTION
    
    This program reads messages from the Error Console and sends them
    to STDOUT.
    
    =head1 SEE ALSO
    
    L<https://developer.mozilla.org/en/Error_Console>
    
    L<https://developer.mozilla.org/en/nsIConsoleService> - the underlying
    Console Service that also shows how to listen to events getting
    added.
    
    =cut

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.78/examples/tail-console.pl>

=head2 Example: urlbar.pl

    #!perl -w
    use strict;
    use WWW::Mechanize::Firefox;
    use Time::HiRes;
    
    my $mech = WWW::Mechanize::Firefox->new(
        #log => ['debug'],
    );
    $mech->get('http://www.cpan.org');
    
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


Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.78/examples/urlbar.pl>

=head2 Example: fullscreen.pl

    #!perl -w
    use strict;
    use WWW::Mechanize::Firefox;
    use Time::HiRes;
    
    my $mech = WWW::Mechanize::Firefox->new(
        #log => ['debug'],
    );
    
    my ($window, $type) = $mech->eval('window');
    
    print "Going fullscreen\n";
    $window->{fullScreen} = 1;
    
    sleep 10;
    
    print "Going back to normal\n";
    $window->{fullScreen} = 0;
    
    =head1 NAME
    
    fullscreen.pl - toggle fullscreen mode of Firefox
    
    =head1 SYNOPSIS
    
    fullscreen.pl
    
    =head1 DESCRIPTION
    
    This program switches Firefox into fullscreen mode. It shows
    how to access Firefox-internal variables and how to manipulate them.
    
    =cut

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.78/examples/fullscreen.pl>

=head2 Example: proxy-settings.pl

Check the network proxy settings
my $prefs = $ff->repl->expr(<<'JS');
    #!perl -w
    use strict;
    use Getopt::Long;
    use Firefox::Application;
    
    my $ff = Firefox::Application->new();
    
    # Check the network proxy settings
    my $prefs = $ff->repl->expr(<<'JS');
      Components.classes["@mozilla.org/preferences-service;1"]
        .getService(Components.interfaces.nsIPrefBranch);
    JS
    
    print "Your proxy settings are\n";
    print "Proxy type\t",  $prefs->getIntPref('network.proxy.type'),"\n";
    print "HTTP  proxy\t", $prefs->getCharPref('network.proxy.http'),"\n";
    print "HTTP  port\t",  $prefs->getIntPref('network.proxy.http_port'),"\n";
    print "SOCKS proxy\t", $prefs->getCharPref('network.proxy.socks'),"\n";
    print "SOCKS port\t",  $prefs->getIntPref('network.proxy.socks_port'),"\n";
    
    # Switch off the proxy
    if ($prefs->getIntPref('network.proxy.type') != 0) {
        $prefs->setIntPref('network.proxy.type',0);
    };
    
    # Switch on the manual proxy configuration
    $prefs->setIntPref('network.proxy.type',1);
    
    
    =head1 NAME
    
    proxy-settings.pl - display and change the proxy settings of Firefox
    
    =head1 SYNOPSIS
    
    proxy-settings.pl
    
    =head1 DESCRIPTION
    
    This shows how to read and write configuration settings
    from L<about:config> . Particularly, it shows how
    to switch the proxy settings in Firefox on and off.
    
    =cut

Download this example: L<http://cpansearch.perl.org/src/CORION/WWW-Mechanize-Firefox-0.78/examples/proxy-settings.pl>

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

Contributed examples contain the original author's name.

=head1 COPYRIGHT

Copyright 2009-2012 by Max Maischein C<corion@cpan.org>.

All Rights Reserved. This module is free software. It may be used, redistributed and/or modified under the same terms as Perl itself.

=cut
