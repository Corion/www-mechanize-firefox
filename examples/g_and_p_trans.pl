#!/usr/bin/env perl
######################################
# $URL: http://mishin.narod.ru $
# $Date: Wed Oct 9 18:52:21 2011 $
# $Author: Nikolay Mishin $
# $Revision: 0.02 $
# $Source: g_and_p_trans.pl $
# $Description: Use translate.google.com and translate.ru to translate between languages. $
##############################################################################

use strict;
use warnings;

use Modern::Perl;
use LWP::UserAgent;

use Getopt::Long;
use Pod::Usage;

use WWW::Mechanize::Firefox;
use HTML::Entities;
use Carp;

use open ':locale';

our $VERSION = '0.02';
our $EMPTY   = q{};

my $man         = 0;
my $help        = 0;
my $from        = 'en';
my $to          = 'ru';
my $text        = 'yapc';
my $url_mashine = 'http://translate.google.com/translate_t?langpair=';

GetOptions(
    'help|?' => \$help,
    'man'    => \$man,
    'from=s' => \$from,
    'to=s'   => \$to,
    'text=s' => \$text,
) or pod2usage( -verbose => 2 );

if ($help) { pod2usage(1) }
if ($man) { pod2usage( -verbose => 2 ) }

my @translate_param = ( $from, $to, $text, $url_mashine );
main( \@translate_param );
exit;

sub main {
    my ($in_param) = @_;
    my @out;
    my $google_text = translate_text($in_param);
    push @out, "google say:\n";
    push @out, $google_text;

    my $translate_ru_text = translate_ru_text($in_param);
    push @out, "\ntranslate.ru say:\n";
    push @out, $translate_ru_text;
    my $out = join $EMPTY, @out;
    say $out;
    return 1;
}

sub translate_text {
    my ($translate_param) = @_;
    my ( $src, $trg, $words, $url_translate ) = @{$translate_param};
    my $url = "${url_translate}${src}|${trg}&text=+${words}";
    my $ua  = LWP::UserAgent->new;
    $ua->agent($EMPTY);
    my $res = $ua->get($url);
    if ( $res->is_error ) { croak $res->status_line }
    my $html      = $res->decoded_content;
    my $start_rgx = q{onmouseout="this.style.backgroundColor='#fff'">};
    my $end_rgx   = q{</span>};
    my @matches   = $html =~ m{\Q$start_rgx\E(.*?)\Q$end_rgx\E}xgms;      #sxm;

    my $out = join $EMPTY, @matches;
    return $out;
}

sub translate_ru_text {
    my ($translate_param) = @_;
    my ( $src, $trg, $words, $url_translate ) = @{$translate_param};
    my $url = 'http://www.translate.ru/';
    my $firemech;
    $firemech = WWW::Mechanize::Firefox->new( tab => qr/PROMT/sm, );
    croak "Cannot connect to $url\n" if !$firemech->success();
    return fill_translate_ru_page( $firemech, $words );
}

sub fill_translate_ru_page {
    my $mech          = shift;
    my $words         = shift;
    my $submit_button = 'id="bTranslate"';
    wait_for( $mech, $submit_button );
    $mech->field( 'ctl00$SiteContent$sourceText' => $words );
    $mech->eval_in_page(<<'JS');
key="";
var globalJsonVar;
 uTrType = "";
    visitLink = false;
    closeTranslationLinks();
    var dir = GetDir();
    var text = rtrim($("#ctl00_SiteContent_sourceText").val());
    text = encodeURIComponent(text).split("'").join("\\'");
    var templ = $("#template").val();
  $.ajax({
        type: "POST",
        contentType: "application/json; charset=utf-8",
        url: "/services/TranslationService.asmx/GetTranslateNew",
        data: "{ dirCode:'" + dir + "', template:'" + templ + "', text:'" + text + "', lang:'ru', limit:" + maxlen + ",useAutoDetect:true, key:'" + key + "', ts:'" + TS + "',tid:'',IsMobile:false}",
        dataType: "json",
        success: function (res) {
 $("#editResult_test")[0].innerHTML=res.result;
console.warn('line1 '+res.result);
        },
        error: function (XMLHttpRequest, textStatus, errorThrown) {
            GetErrMsg("К сожалению, сервис временно недоступен. Попробуйте повторить запрос позже.");
            trDirCode = "";
        }
    });


JS

    sleep 1;
    my ( $value, $type ) = $mech->eval(<<'JS');
console.warn('line2 '+$("#editResult_test")[0].innerHTML);	
$("#editResult_test")[0].innerHTML;
JS

    return decode_entities($value);
}

sub wait_for {
    my $mech   = shift;
    my $choice = shift;
    use Readonly;
    Readonly my $NUMBER_OF_RETRIES => 10;
    my $retries = $NUMBER_OF_RETRIES;
    while ( $retries--
        && !$mech->is_visible( xpath => '//*[@' . ${choice} . ']' ) )
    {
        sleep 1;
    }
    croak 'Timeout' if 0 > $retries;
    return 1;
}

__END__

=head1 NAME

g_and_p_trans.pl - command line translator with google, translate.ru 

=head1 SYNOPSIS

g_and_p_trans.pl [options] [text to translate ...]

Options:
-help brief help message
-man full documentation
-from from language
-to to language
-text text to translate

=head1 USAGE

g_and_p_trans.pl --from en --to ru --text "This is a test"

=head1 REQUIRED ARGUMENTS

--text is requied argument, so you can invoke 

perl g_and_p_trans.pl --text "This is a test"

=head1 CONFIGURATION

no special configuration

=head1 DEPENDENCIES

Modern::Perl
LWP::UserAgent
Getopt::Long
Pod::Usage
use WWW::Mechanize::Firefox;
use HTML::Entities;
use Carp;


=head1 OPTIONS

=over 2

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input "text" and translate it to 
 selected language using translate.google.com.
 
=head1 DIAGNOSTICS


=head1 EXIT STATUS

unnown

=head1 INCOMPATIBILITIES

with winXP not work

=head1 BUGS AND LIMITATIONS

1. Windows - not ok
Cannot figure out an encoding to use at g_and_p_trans.pl line 20 
2. Ubuntu - ok
 
=head1 AUTHOR

Nikolay Mishin(mi@ya.ru), Jeremiah LaRocco(only for google)

=head1 LICENSE AND COPYRIGHT
 
Copyright 2013 by Nikolay Mishin M<lt>ishin@cpan.org<gt>.
 
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
 
See F<http://www.perl.com/perl/misc/Artistic.html>
 
=cut
=cut
