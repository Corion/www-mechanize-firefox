package Firefox::Application::API36;
use strict;
use parent 'Firefox::Application';
use Firefox::Application::API35;
use vars qw($VERSION);
$VERSION = '0.78';

=head1 NAME

Firefox::Application::API36 - API wrapper for Firefox 3.6+

=head1 SYNOPSIS

    use Firefox::Application;
    my $ff = Firefox::Application->new(
        # Force the Firefox 3.5 API
        api => 'Firefox::Application::API35',
    );

=head1 METHODS

=head2 C<< $api->updateitems( %args ) >>

  for my $item ($api->updateitems) {
      print sprintf "Name: %s\n", $item->{name};
      print sprintf "Version: %s\n", $item->{version};
      print sprintf "GUID: %s\n", $item->{id};
  };

Returns the list of updateable items. Under Firefox 4,
can be restricted by the C<type> option.

=over 4

=item * C<type> - type of items to fetch

C<ANY> - fetch any item

C<ADDON> - fetch add-ons

C<LOCALE> - fetch locales

C<THEME> - fetch themes

=back

=cut

sub import_from_api35 {
    my ($name) = @_;
    no strict 'refs';
    *{"$name"} = \&{ "Firefox::Application::API35::$name" };
};

import_from_api35($_)
    for (qw(updateitems addons themes locales
            selectedTab addTab autoclose_tab closeTab openTabs
    ));

=head2 C<< $ff->closeTab( $tab [,$repl] ) >>

    $ff->closeTab( $tab );

Close the given tab.

=cut

=head2 C<< $api->element_query( \@elements, \%attributes ) >>

    my $query = $element_query(['input', 'select', 'textarea'],
                               { name => 'foo' });

Returns the XPath query that searches for all elements with C<tagName>s
in C<@elements> having the attributes C<%attributes>. The C<@elements>
will form an C<or> condition, while the attributes will form an C<and>
condition.

=cut

sub element_query {
    my ($self, $elements, $attributes) = @_;
        my $query = 
            './/*[(' . 
                join( ' or ',
                    map {
                        sprintf qq{local-name(.)="%s"}, lc $_
                    } @$elements
                )
            . ') and '
            . join( " and ",
                map { sprintf q{@%s="%s"}, $_, $attributes->{$_} }
                  sort keys(%$attributes)
            )
            . ']';
};

1;

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2009-2014 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
