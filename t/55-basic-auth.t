#!/usr/bin/perl -w
use strict;
use FindBin;

use lib 'inc';
use IO::Catch;
use vars qw( $_STDOUT_ $_STDERR_ );

use WWW::Mechanize::Firefox;

# pre-5.8.0's warns aren't caught by a tied STDERR.
tie *STDOUT, 'IO::Catch', '_STDOUT_' or die $!;

use Test::More;
plan skip_all => "presetting auth does not work yet";

if (! eval { require HTTP::Daemon; 1 }) {
    plan skip_all => "HTTP::Daemon required to test basic authentication";
    exit
};

# We want to be safe from non-resolving local host names
delete @ENV{qw(HTTP_PROXY http_proxy CGI_HTTP_PROXY)};

my $mech = eval { WWW::Mechanize::Firefox->new( 
        autodie => 0,
        #log => [qw[debug]],
    )
};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
};

my $user = 'foo';
my $pass = 'bar';

# Now start a fake webserver, fork, and connect to ourselves
my $server_pid = open SERVER, qq{"$^X" "$FindBin::Bin/401-server" $user $pass |}
  or die "Couldn't spawn fake server : $!";
sleep 1; # give the child some time
my $url = <SERVER>;
chomp $url;
die "Couldn't decipher host/port from '$url'"
    unless $url =~ m!^http://([^/]+)/!;
my $host = $1;
my $res;

# First try with an inline username/password
# FF asks for confirmation to navigate here :(
if (0) {
    my $pwd_url = $url;
    $pwd_url =~ s!^http://!http://$user:$pass\@!;
    $pwd_url .= 'thisshouldpass';
    diag "get $pwd_url";
    my $res = $mech->get( $pwd_url );
    diag $mech->content
        unless is($res->code, 200, "Request with inline credentials gives 200");
    like($mech->content, qr/user = 'foo' pass = 'bar'/, "Credentials are good");
};

# https://developer.mozilla.org/en/XPCOM_Interface_Reference/nsILoginManager
my $passwordManager = $mech->repl->expr(<<'JS');
    Components.classes["@mozilla.org/login-manager;1"].
        getService(Components.interfaces.nsILoginManager)
JS
isa_ok $passwordManager, 'MozRepl::RemoteObject::Instance';

diag $url;
my $u = "$url";
$u =~ s!/$!!;
diag $u;

# https://developer.mozilla.org/en/XPCOM_Interface_Reference/nsILoginInfo
my $nsiLoginInfo = $mech->repl->expr(<<"JS");
    var nsiL = new Components.Constructor("\@mozilla.org/login-manager/loginInfo;1",
        Components.interfaces.nsILoginInfo,
        "init");
    new nsiL("$u",
                       null, 'testing realm',
                       "$user", "$pass", "", "")
JS
isa_ok $nsiLoginInfo, 'MozRepl::RemoteObject::Instance';

$passwordManager->addLogin($nsiLoginInfo);

if (0) {
    # Dump all logins
    my $logins = $mech->repl->expr(<<'JS');
        var pm = Components.classes["@mozilla.org/login-manager;1"].
            getService(Components.interfaces.nsILoginManager);
        pm.getAllLogins({});
JS
    my $count = $logins->{length};
    diag "Logins: $count";
    for (0..$count-1) {
        diag "---";
        diag $logins->[$_]->{formSubmitURL};
        diag $logins->[$_]->{hostname};
        diag $logins->[$_]->{httpRealm};
        diag $logins->[$_]->{password};
        diag $logins->[$_]->{passwordField};
        diag $logins->[$_]->{username};
        diag $logins->[$_]->{usernameField};
    };
};

# Now, prepare to override the dialog:

$mech->repl->expr(<<'JS');
    alert(netscape.security.PrivilegeManager.enablePrivilege('UniversalXPConnect'));
JS

# This is an ugly interactive test :/
# Now try without credentials
$res = $mech->get( $url );

my $got_url;
if (ok $res) {
    my $code = $res->code;
    my $got_url = $mech->uri;

    if (! ok $code == 401 || $got_url ne $url, "Request without credentials gives 401 (or is hidden by a WWW::Mechanize bug)") {
        diag "Page location : " . $mech->uri;
        diag $res->as_string;
    };
};

# Now try the shell command for authentication
#$s->cmd( "auth foo bar" );

# Now remove the added login again:
$passwordManager->removeLogin($nsiLoginInfo);

diag "Shutting down test server at $url";
$mech->get("${url}exit"); # shut down server
sleep 1;
# Kill it if it's still alive:
END {
    kill 9 => $server_pid
        if $server_pid;
};
#close SERVER; # boom
