package HTML::Display::MozRepl;
use strict;
use Carp qw(carp);
use WWW::Mechanize::FireFox;
use parent 'HTML::Display::Common';
use vars qw($VERSION);
$VERSION = '0.18';

=head1 NAME

HTML::Display::MozRepl - use a mozrepl enabled FireFox to display HTML

=head1 SYNOPSIS

  $ENV{PERL_HTML_DISPLAY} = 'HTML::Display::MozRepl';

=cut

sub new {
  my ($class,%options) = @_;
  my $self = $class->SUPER::new();
  my $ff = WWW::Mechanize::FireFox->new( autoclose => 0 );
  $self->{ff} = $ff;
  $self;
};

sub ff { $_[0]->{ff} };

sub display_html {
  my ($self,$html) = @_;
  if ($html) {
    my $browser = $self->ff;
    my $document = $browser->update_html($html);
  } else {
    carp "No HTML given" unless $html;
  };
};

=head1 AUTHOR

Copyright (c) 2004-2009 Max Maischein C<< <corion@cpan.org> >>

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut

1;
