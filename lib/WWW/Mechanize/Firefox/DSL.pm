package WWW::Mechanize::Firefox::DSL;
use strict;
use WWW::Mechanize::Firefox;
use Carp qw(croak);

use vars qw($VERSION);
$VERSION = '0.34';

=head1 NAME

WWW::Mechanize::Firefox::DSL - Domain Specific Language for short scripts

=head1 SYNOPSIS

    use WWW::Mechanize::Firefox::DSL '$mech';

    get 'http://google.de';
    
    my @links = selector('a');
    print $_->{innerHTML},"\n" for @links;
    
    click($links[0]);

This module exports all methods of one WWW::Mechanize::Firefox
object as subroutines. That way, you can write short scripts without
cluttering every line with C<< $mech-> >>.

This module is highly experimental and might vanish from the distribution
again if I find that it is useless.

=cut

sub import {
    my $target = caller;
    my ($class, %options) = @_;
    my $name = delete $options{ name } || '$mech';
    my $mech = WWW::Mechanize::Firefox->new(%options);
    
    $name =~ s/^[\$]//
        or croak 'Variable name must start with $';
    {
        no strict 'refs';
        *{"$target\::$name"} = \$mech;
        Object::Wrapobj->import( \${"$target\::$name"}, $target );
    };
};

package # hide from CPAN indexer
    Object::Wrapobj;
our $VERSION # hide from my standard VERSION test
  = 1.000;
use Scalar::Util "blessed";
use mro;
sub import {
    my($_u, $o_r, $en) = @_;
    $en ||= caller;
    my $ens = $en . "::";
    my $ep = do {no strict 'refs'; \%{ +$ens } };
    my $c = blessed($$o_r) || $$o_r;
    for my $n (@{mro::get_linear_isa($c)}) {
        my $p = do { no strict 'refs'; \%{ $n . "::" }};
        for my $s (sort keys %$p) {
            if (exists(&{$$p{$s}})) {
                if (!$$ep{$s} || !exists(&{$$ep{$s}})) {
                    no strict 'refs';
                    *{$ens . $s} = sub (@) { ${$o_r}->${\$s}(@_) };
                }
            }
        }
    }
}

1;

=head1 AUTHORS

Max Maischein C<corion@cpan.org> and Zsban Ambrus

=head1 COPYRIGHT (c)

Copyright 2009-2010 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
