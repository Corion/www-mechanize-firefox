package IO::Catch;
use strict;
use Carp qw(croak);

=head1 NAME

IO::Catch - capture STDOUT and STDERR into global variables

=head1 AUTHOR

Max Maischein ( corion at cpan.org )
All code ripped from pod2test by M. Schwern

=head1 SYNOPSIS

  # pre-5.8.0's warns aren't caught by a tied STDERR.
  use vars qw($_STDOUT_, $_STDERR_);
  tie *STDOUT, 'IO::Catch', '_STDOUT_' or die $!;
  tie *STDERR, 'IO::Catch', '_STDERR_' or die $!;

  # now you can access $main::_STDOUT_ and $_STDERR_
  # to see the output.

=cut

use vars qw($VERSION);

$VERSION = '0.02';

sub TIEHANDLE {
    my($class, $var) = @_;
    croak "Need a variable name to tie to" unless $var;
    return bless { var => $var }, $class;
}

sub PRINT  {
    no strict 'refs';
    my($self) = shift;
    ${'main::'.$self->{var}} = ""
      unless defined ${'main::'.$self->{var}};
    ${'main::'.$self->{var}} .= join '', @_;
}

sub PRINTF {
    no strict 'refs';
    my($self) = shift;
    my $tmpl = shift;
    ${'main::'.$self->{var}} = ""
      unless defined ${'main::'.$self->{var}};
    ${'main::'.$self->{var}} .= sprintf $tmpl, @_;
}

sub OPEN  {}    # XXX Hackery in case the user redirects
sub CLOSE {}    # XXX STDERR/STDOUT.  This is not the behavior we want.

sub READ {}
sub READLINE {}
sub GETC {}
sub BINMODE {}

1;
