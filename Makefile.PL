use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

use Apache::test;
use Cwd;
my %params = Apache::test->get_test_params();

# Note, we can't use a relative path for the .par files because 
# it could be different than the current directory
my $par_path = Cwd::abs_path("t/par");
Apache::test->write_httpd_conf(%params, 
	include => "
PerlSetVar PARFile $par_path/registry.par
PerlAddVar PARFile $par_path/static.par
PerlAddVar PARFile $par_path/perlrun.par
PerlAddVar PARFile $par_path/module.par
PerlModule Apache::PAR"
);
*MY::test = sub { Apache::test->MM_test(%params) };

WriteMakefile(
    'NAME'		=> 'Apache::PAR',
    'VERSION_FROM'	=> 'PAR.pm', # finds $VERSION
    'PREREQ_PM'		=> {PAR => .49, MIME::Types => 1.004, Archive::Zip => 1.05, Cwd => 2.04 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'PAR.pm', # retrieve abstract from module
       AUTHOR     => 'Nathan Byrd <nathan@byrd.net>') : ()),
);

