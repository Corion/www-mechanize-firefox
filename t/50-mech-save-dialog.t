#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan skip_all => 'Not yet implemented';
    exit 0;
    
    plan tests => 1;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

# This is if we implement our own "overlay" for the SaveAs dialog
#    // Now, "close" the dialog
#    document.documentElement.removeAttribute('ondialogaccept');
#    document.documentElement.cancelDialog();


$mech->repl->expr(<<'JS');
var observer = {
  observe: function(subject,topic,data){
   if (topic != "http-on-examine-response") {
       return
   };

   var httpChannel =
   subject.QueryInterface(Components.interfaces.nsIHttpChannel);
   var contentType = httpChannel.getResponseHeader("Content-Type");

   var channel = subject.QueryInterface(Components.interfaces.nsIChannel);
   var url = channel.URI.spec;
   url = url.toString();
   
   // alert(topic + " | " + url);
      
   if ( contentType.indexOf("html") == -1 ){

       channel.cancel();
       alert("Wait a moment!\n"+ url );
   }
   
  }
};

var observerService =
    Components.classes["@mozilla.org/observer-service;1"]
    .getService(Components.interfaces.nsIObserverService);
observerService.addObserver(observer,"http-on-examine-response",false);

JS


my ($site,$estatus) = ('http://www.firefox-start.com/download/Firefox%20Setup%203.0.3.exe',200);
my $res = $mech->get($site);
sleep 10;

#$mech->repl->expr(<<'JS');
#    unregisterMockFilePickerFactory();
#//window.getTargetFile = this.oldGetTargetFile;
#JS
