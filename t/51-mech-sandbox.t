#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::FireFox;
use URI::file;
use File::Basename;
use File::Spec;
use Cwd;

my $mech = eval { WWW::Mechanize::FireFox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 9;
};

isa_ok $mech, 'WWW::Mechanize::FireFox';

my $dir = File::Spec->rel2abs( dirname $0, getcwd() );
my $file = File::Spec->catfile( $dir, '51-mech-sandbox.html' );
$file =~ s!\\!/!g; # fakey file:// construction
$file = "file://$file";
my $uri = URI::file->new($file);
$mech->get("$uri");
$mech->allow('javascript' => 1);

# var x = Components.utils.evalInSandbox("let x = 1;", sandbox, "1.8", "http://foo.com/mycode.js", 25);
sub page_eval {
    my ($mech,$str) = @_;
    my $eval_in_sandbox = $mech->repl->declare(<<'JS');
    function (uri,w,d,str) {
        var unsafeWin = w.wrappedJSObject;
        var safeWin = XPCNativeWrapper(unsafeWin);
        var sandbox = Components.utils.Sandbox(safeWin);
        sandbox.window = safeWin;
        sandbox.document = sandbox.window.document;
        sandbox.__proto__ = unsafeWin;
        return Components.utils.evalInSandbox(str, sandbox);
    };
JS
    my $window = $mech->tab->{linkedBrowser}->{contentWindow};
    my $uri = $mech->uri;
    return $eval_in_sandbox->("$uri",$window,$mech->document,$str);
};

sub unsafe_page_property_access {
    my ($mech,$element) = @_;
    my $window = $mech->tab->{linkedBrowser}->{contentWindow};
    my $unsafe = $window->{wrappedJSObject};
    $unsafe->{element}
};

my $get = page_eval($mech,'get');
ok $get, "We found 'get'";

my $v;
eval {
    $v = $get->();
};
is $@, "", "No error when calling get()";
is $v, 'Hello', "We got the initial value";

my $set = page_eval($mech,'set');
ok $set, "We found 'set'";

my $v;
eval {
    $v = $set->('123');
};
is $@, "", "No error when calling set()";
is $v, '123', "We got the set value";

eval {
    $v = $get->();
};
is $@, "", "No error when calling get()";
is $v, '123', "We got the new value";
