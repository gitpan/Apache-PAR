package Apache::PAR;

use 5.005;
use strict;

require mod_perl; # For version detection

# Since we don't use exporter, only export what we need
use vars qw($VERSION %PARFILE_LIST);

$VERSION = '0.20';

unless ($mod_perl::VERSION < 1.99) {
	require Apache::ServerUtil;
	require APR::Table;
}
else {
	require Apache;
	require Apache::Server;
}

use Archive::Zip ();
Archive::Zip::setErrorHandler(sub {});

my @pardir      = Apache->server->dir_config->get('PARDir');
my @parfiles    = Apache->server->dir_config->get('PARFile');
my @parloc      = Apache->server->dir_config->get('PARInclude');

sub import {
	shift;
	my @parentries = @_;
	my $parext    = Apache->server->dir_config('PARExt') || 'par';
	my $conf_file = Apache->server->dir_config('PARConf') || 'web.conf';

	my %parlist = ();
	foreach my $parentry (@parentries) {
		$parentry = Apache->server_root_relative($parentry);
		$parentry =~ s/\/$//;
		if(!(-e $parentry)) {
			print STDERR "PAR: No such file or directory: $parentry\n";
			next;
		}
		if(-f _) {
			$parlist{$parentry} = 1;
		}
		elsif(-d _) {
			opendir(DIR, $parentry);
			my @files = readdir(DIR);
			closedir(DIR);
			foreach my $file (@files) {
				next if($file !~ /\.$parext$/);
				next if(!-f "$parentry/$file");
				$parlist{"$parentry/$file"} = 1;
			}
		}
		else {
			print STDERR "PAR: Bad file type: $parentry\n";
		}
	}
	my @pars = keys(%parlist);
	eval 'require PAR; import PAR (@pars,keys(%PARFILE_LIST));';
	die "Could not load PAR, $@\n" if($@);


	foreach my $file (@pars) {
		my $zip = Archive::Zip->new($file);
		unless(defined($zip)) {
			print STDERR "$file does not seem to be a valid PAR (Zip) file. Skipping.\n";
			next;
		}
		my $conf_member = $zip->memberNamed($conf_file);
		next if(!defined($conf_member));
		print STDERR "Including configuration from $file\n";
		my $conf = $conf_member->contents;
		my $err = undef;
	
		$conf =~ s/##PARFILE##/$file/g;


		unless ($mod_perl::VERSION < 1.99) {
			$err = Apache->server->add_config([split /\n/, $conf]);
		} else
		{
			Apache->httpd_conf($conf);
		}
		die $err if $err;
	}

	map {$PARFILE_LIST{$_} = 1;} @pars;

}

import(__PACKAGE__,@pardir,@parfiles,@parloc);

1;
__END__

=head1 NAME

Apache::PAR - Perl extension for including Perl ARchive files in a mod_perl (1.x or 2.x) environment.

=head1 SYNOPSIS

  Inside Apache configuration:
    PerlSetVar PARInclude /path/to/par/archive/directory
    ...
    PerlAddVar PARInclude /path/to/a/par/file.par
    ...
    PerlModule Apache::PAR

  In Apache/mod_perl 1.x environments on Win32 platforms, the following should be used instead:
    PerlSetVar PARInclude /path/to/par/archive/directory
    ...
    PerlSetVar PARInclude /path/to/a/par/file.par
    ...
    <PERL>
    use Apache::PAR;
    </PERL>


  Alternative configuration, inside a startup.pl script or PERL section:
    use Apache::PAR qw(
      /path/to/par/archive/directory
      /path/to/a/par/file.par
    );

  Inside a web.conf file:

    Alias /myapp/static/ ##PARFILE##/
    <Location /myapp/static>
      SetHandler perl-script
      PerlHandler Apache::PAR::Static
      PerlSetVar PARStaticDirectoryIndex index.htm
      PerlAddVar PARStaticDirectoryIndex index.html
      PerlSetVar PARStaticDefaultMIME text/html
    </Location>

    Alias /myapp/cgi-perl/ ##PARFILE##/
    <Location /myapp/cgi-perl>
      Options +ExecCGI
      SetHandler perl-script
      PerlHandler Apache::PAR::Registry
    </Location>

    Alias /myapp/cgi-run/ ##PARFILE##/
    <Location /myapp/cgi-run>
      Options +ExecCGI
      SetHandler perl-script
      PerlHandler Apache::PAR::PerlRun
    </Location>

    PerlModule MyApp::TestMod
    Alias /myapp/mod/ ##PARFILE##/
    <Location /myapp/mod>
      SetHandler perl-script
      PerlHandler TestMod
    </Location>


=head1 DESCRIPTION

Apache::PAR is a framework for including Perl ARchive files in a mod_perl (1.x or 2.x) environment.  It allows an author to package up a web application, including configuration, static files, Perl modules, and Registry and PerlRun scripts to include in a single file.  This archive can then be moved to other locations on the same system or distributed, and loaded with a single set of configuration options in the Apache configuration.

These modules are based on PAR.pm by Autrijus Tang and Archive::Zip by Ned Konz, as well as the mod_perl modules.  They extend the concept of PAR files to mod_perl, similar to how WAR archives work for Java. An archive (which is really a zip file), contains one or more elements which can be served to clients making requests to an Apache web server.  Scripts, modules, and static content should then be able to be served from within the .par archive without modifications.

Apache::PAR itself performs the work of specifying the location of PAR archives and allowing the loading of modules from these archives.  The files and paths can be specified at load time.  Once an archive has been located, an optional web.conf (filename configurable) is then loaded and included into the main web configuration.  Once Apache::PAR has been loaded, Perl Apache modules within these .par files can then be loaded.

The following steps are performed on any .par files which are found within a PARInclude:

=over 4

=item * If the PARInclude is a directory, all PAR files within that directory are loaded

=item * Any .par files defined are loaded with PAR.pm, making any modules defined within it visible to Apache

=item * Apache::PAR checks for the existence of a web.conf file within each .par archive and, if found, includes that configuration into the main Apache configuration.

=back

=head2 Some things to note:

PerlSetVar/AddVar configuration for PARInclude B<MUST> be before the PerlModule Apache::PAR (or use Apache::PAR;) line in the Apache configuration.  Any PARInclude variables (or PARDir and PARFile) after the PerlModule line will be ignored.

PARDir and PARFile directives may be used to specify the location of PAR archives, however their use is deprecated.  For new configurations, use PARInclude instead.  PARInclude works both as PARDir and PARFile by first expanding directories to include any PAR archives found within.

The arguments for PARInclude can be either an absolute path, or a relative path from Apache's server_root.  For example, if your Apache's server_root is /usr/local/apache, and you would like to load .par files from a parfiles/ subdirectory, use:
  PerlSetVar PARInclude parfiles/

This will then look for .par files in the /usr/local/apache/parfiles directory.

The name of the configuration file which is loaded is configurable via PARConf (default is 'web.conf'.)  For example, to set the include filename to 'include.conf' for all .par files:
  PerlSetVar PARConf include.conf

The extensions used when searching for .par archives in any directories set via PARInclude is set using the PARExt variable in the Apache configuration (the default is 'par').  For example, to set the par extension to 'zip':
  PerlSetVar PARExt zip

There is currently no way to limit which .par archive a module is loaded out of.  To ensure that the correct module is being loaded, I suggest the following convention: begin module names with the name of the archive.  For instance, a MailForm module within the MyApp.par archive should be named MyApp::MailForm

Currently, which directory inside a .par archive modules are loaded out of is not configurable, and is the same as defined in PAR.pm:

=over 4

=item 1. /

=item 2. /lib/

=item 3. /arch/

=item 4. /i386-freebsd/       # i.e. $Config{archname}

=item 5. /5.8.0/              # i.e. $Config{version}

=item 6. /5.8.0/i386-freebsd/ # both of the above

=back

=head1 PLATFORM SPECIFIC

In general, Apache::PAR should function on most platforms without changes, as it is (currently) a perl only module.  Below are notes for any known exceptions.  If you have any problems with Apache::PAR on your platform, please contact me through one of the methods in the CONTACT section.

=head2 Windows 32 bit

Some testing has been performed on Apache::PAR using WIN32 platforms, with both mod_perl 1.x and 2.x.  Apache::PAR should function as normal on these platforms, however, an alternate configuration method is required due to differences in the Apache/mod_perl startup sequence on that platform.

inside a PERL section or startup.pl:

    use Apache::PAR qw(
      /path/to/par/archive/directory
      /path/to/a/par/file.par
      ...
    );

Additionally, you can still use PerlSetVar PARInclude, etc lines in Win32 - the Apache::PAR include must be via a use however (not a PerlModule directive):

inside httpd.conf (example for mod_perl 1.x, for 2.x use <PERL > instead):

  PerlSetVar PerlInclude /path/to/par/archive/directory
  PerlAddVar PerlInclude /path/to/a/par/file.par
  ...
  <PERL>
    use Apache::PAR;
  </PERL>

=head1 EXPORT

None by default.

=head1 CONTACT

For questions regarding the installation or use of Apache::PAR, either post a message on the PAR list E<lt>par@perl.orgE<gt>, on the sourceforge project page at L<http://www.sourceforge.net/projects/apache-par> or send an email to the author directly at E<lt>nathan@byrd.netE<gt>.

=head1 AUTHOR

Nathan Byrd, E<lt>nathan@byrd.netE<gt>

=head1 SEE ALSO

L<perl>.

L<PAR>.

L<Apache::PAR::Registry>, L<Apache::PAR::PerlRun>, and L<Apache::PAR::Static>.

=head1 COPYRIGHT

Copyright 2002 by Nathan Byrd, E<lt>nathan@byrd.netE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
