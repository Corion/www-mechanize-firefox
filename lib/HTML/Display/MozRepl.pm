package HTML::Display::MozRepl;
use strict;
use Carp qw(carp);
use WWW::Mechanize::Firefox;
use parent 'HTML::Display::Common';
use vars qw($VERSION);
$VERSION = '0.78';

=head1 NAME

HTML::Display::MozRepl - use a mozrepl enabled Firefox to display HTML

=head1 SYNOPSIS

  $ENV{PERL_HTML_DISPLAY} = 'HTML::Display::MozRepl';

=cut

sub new {
  my ($class,%options) = @_;
  my $self = $class->SUPER::new();
  my $ff = WWW::Mechanize::Firefox->new(
      autoclose => 0,
      %options,
 );
  $self->{ff} = $ff;
  $self;
};

sub ff { $_[0]->{ff} };

sub display_html {
  my ($self,$html) = @_;
  if ($html) {
    my $browser = $self->ff;
    $browser->update_html($html);
  } else {
    carp "No HTML given" unless $html;
  };
};

=head1 SEE ALSO

L<WWW::Mechanize::Firefox>

=head1 REPOSITORY

The public repository of this module is 
L<http://github.com/Corion/www-mechanize-firefox>.

=head1 AUTHOR

Copyright (c) 2009-2014 Max Maischein C<< <corion@cpan.org> >>

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut

1;
