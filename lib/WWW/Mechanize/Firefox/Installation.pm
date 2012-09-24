=pod

=head1 NAME

WWW::Mechanize::Firefox::Installation - How to install the components

=head1 Installation

If you notice that tests get skipped and/or the module installs
but "does not seem to work", there are some more steps required
to configure Firefox:

=over 4

=item 1.

Install mozrepl 1.1.0 available from

L<http://wiki.github.com/bard/mozrepl/>

respectively

L<https://github.com/bard/mozrepl/tags>

You will need to edit the C<.zip> file into a C<.xpi> file. You
may or may not need to enable the "show file extensions" setting
in your operating system for this.

=item 2.

Launch Firefox

=item 3.

Start C<mozrepl> in Firefox by going to the menu:

   "Tools" -> "MozRepl" -> "Start"

You may want to tick the "Activate on startup" item.

Alternatively, launch the Firefox binary with the C<-mozrepl> command line
switch:

  firefox -repl

If tests still fail, especially t/50-click.t and 51-mech-submit.t ,
this might be because you use the NoScript Mozilla extension
and have it blocking Javascript for file:// URLs. While this is good,
the tests need Javascript enabled.

Solution:

=over 4

=item 1.

Open t/50-click.html in Firefox

=item 2.

Allow Javascript for all file:// URLs

=item 3.

Re-run tests

    perl Makefile.PL
    nmake

or if you are using Strawberry Perl or Citrus Perl

    perl Makefile.PL
    dmake

=item 4.

No test should fail

=back

If tests fail with an error from Firefox that a file could not
be found, check that the test suite and the Firefox process are
run using the same user. Otherwise, the Firefox process might not
have the permissions to access the files created by the test suite.

=back

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT

Copyright 2010-2012 by Max Maischein C<corion@cpan.org>.

All Rights Reserved. This module is free software. It may be used,
redistributed and/or modified under the same terms as Perl itself.

=cut