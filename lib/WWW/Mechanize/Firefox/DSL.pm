package WWW::Mechanize::Firefox::DSL;
use strict;
use WWW::Mechanize::Firefox;
use Carp qw(croak);

=head1 NAME

WWW::Mechanize::Firefox::DSL - Domain Specific Language for short scripts

=head1 SYNOPSIS

    use WWW::Mechanize::Firefox::DSL '$mech';

    get 'http://google.de';
    
    my @links = selector('a');
    print $_->{innerHTML},"\n" for @links;
    
    click($links[0]);

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
our $VERSION = 1.000;
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