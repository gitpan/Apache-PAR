use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

use Apache::test qw(have_httpd);
use Cwd;
my %params = Apache::test->get_test_params();

# Note, we can't use a relative path for the .par files because 
# it could be different than the current directory
my $par_path = Cwd::abs_path("t/par");
my $extra_conf = <<CONF;
<IfDefine MODPERL2>
PerlModule Apache2
PerlModule Apache::ServerUtil
PerlModule Apache::Server
</IfDefine>
PerlSetVar PARFile $par_path/registry.par
PerlAddVar PARFile $par_path/static.par
PerlAddVar PARFile $par_path/perlrun.par
PerlAddVar PARFile $par_path/module.par

Alias /test/registryroot/ $par_path/registry.par/
<Location /test/registryroot>
Options +ExecCGI
SetHandler perl-script
PerlHandler Apache::PAR::Registry
PerlSetVar PARRegistryPath /
</Location>

Alias /test/registry2/ $par_path/registry.par/
<Location /test/registry2>
Options +ExecCGI
SetHandler perl-script
PerlHandler Apache::PAR::Registry
PerlSetVar PARRegistryPath scripts2/
</Location>

Alias /test/perlrunroot/ $par_path/perlrun.par/
<Location /test/perlrunroot>
Options +ExecCGI
SetHandler perl-script
PerlHandler Apache::PAR::PerlRun
PerlSetVar PARPerlRunPath /
</Location>

Alias /test/perlrun2/ $par_path/perlrun.par/
<Location /test/perlrun2>
Options +ExecCGI
SetHandler perl-script
PerlHandler Apache::PAR::PerlRun
PerlSetVar PARPerlRunPath scripts2/
</Location>

#PerlAddVar PARFile $par_path/bad.par
#PerlAddVar PARFile $par_path/not_found.par
#PerlAddVar PARDir $par_path/not_dir/
PerlModule Apache::PAR
CONF

Apache::test->write_httpd_conf(%params, include => $extra_conf);
*MY::test = sub { Apache::test->MM_test(%params) } if have_httpd();

WriteMakefile(
    'NAME'		=> 'Apache::PAR',
    'VERSION_FROM'	=> 'PAR.pm', # finds $VERSION
    'clean'             => {FILES => 't/httpd.conf t/error_log t/httpd'},
    'PREREQ_PM'		=> {PAR => .49, MIME::Types => 1.004, Archive::Zip => 1.05, Cwd => 2.04, mod_perl => 1.26 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'PAR.pm', # retrieve abstract from module
       AUTHOR     => 'Nathan Byrd <nathan@byrd.net>') : ()),
);

