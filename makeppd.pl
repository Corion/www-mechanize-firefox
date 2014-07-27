#makeppd.pl 2.0
use FileHandle;
use File::DosGlob qw(bsd_glob);
#use Win32::FileOp;
use Config;

$make=$Config{make};

my $has_xs = 0;

system('perl Makefile.PL');
system($make) and die "Failed to make!\n";

system($make, 'dist'); # this creates the ordinary distribution
# I need the archive to find the version number!
# If you comment this out, always copy the archive to current directory.

# this part of code finds the latest distribution, I don't have time to
# explore how to find the version number
@archives = grep {!/-PPM\.tar\.gz$/i} bsd_glob('*.tar.gz');
$archive = findNewest (@archives);

($name = $archive) =~ s/\.tar\.gz$//;
($module = $name) =~ s/-[\d.]+$//;
($file = $module) =~ s/^.*-(.*?)$/$1/;

$ppd = $module.".ppd";
$module =~ s/-/\\/g;

print "Module name : $file\n";
print "Newest archive is $archive\n";

system('perl','Makefile.PL', "BINARY_LOCATION=$name-PPM.tar.gz");
#system($make, 'ppd');
# you may do something like
system($make, 'ppd', "BINARY_LOCATION=$name-PPM.tar.gz");
# if you do not apply my patch to ExtUtils\MM_Unix.pm

system("tar cvf $name-PPM.tar blib");
system("gzip --best $name-PPM.tar");

Delete qw(blib pod2html-dircache pod2html-itemcache pm_to_blib pod2htmd.x~~ pod2htmi.x~~);

if (! $has_xs) {
        open $PPD, "<$ppd" or die "Can't open the $ppd file: $!\n";
        open $NEWPPD, ">$ppd.tmp" or die "Can't create the $ppd.tmp file: $!\n";
        while (<$PPD>) {
                next if (/<ARCHITECTURE/);
                print $NEWPPD $_;
        }
        close $PPD; close $NEWPPD;
        unlink $ppd;
        rename $ppd.'.tmp' => $ppd;
}

exit;

#==================

sub findNewest {
        my $maxitem;
        my $maxver = pack('C4',0,0,0,0);
        foreach my $item (@_) {
                $item =~ /-(\d+)\.(\d+)\.(?:(\d+)\.(?:(\d+)\.)?)?tar\.gz/;
                my $ver = pack('C4',$1,$2,$3,$4);

                if ($ver gt $maxver) {
                        $maxver = $ver;
                        $maxitem = $item;
                }
        }
        return $maxitem;
}

