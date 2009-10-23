use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'    => 'WWW::Mechanize::FireFox',
    'VERSION_FROM'  => 'lib/WWW/Mechanize/FireFox.pm', # finds $VERSION
    'PREREQ_PM'    => { 'MozRepl::RemoteObject' => 0.01,
                        'URI' => 0,
                      }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'lib/WWW/Mechanize/FireFox.pm', # retrieve abstract from module
       AUTHOR     => 'Max Maischein <corion@cpan.org>') : ()),
);

1;
