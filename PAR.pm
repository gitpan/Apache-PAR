package Apache::PAR;

use 5.005;
use strict;
use warnings;

require Exporter;

use vars qw(@ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION);
@ISA = qw(Exporter);

%EXPORT_TAGS = ( 'all' => [ qw( ) ] ); 

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

@EXPORT = qw( );

$VERSION = '0.02';

use Apache;
use Apache::Server;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);

my @pardir      = Apache->server->dir_config->get('PARDir');
my @parfiles    = Apache->server->dir_config->get('PARFile');
my $parext      = Apache->server->dir_config('PARExt') || 'par';
my $conf_file   = Apache->server->dir_config('PARConf') || 'web.conf';

print STDERR "PAR starting...\n";
@parfiles = () if (!@parfiles);
my @pars = ();
foreach my $parfile (@parfiles) {
	$parfile = Apache->server_root_relative($parfile);
	if(!(-f $parfile)) {
		print STDERR "Bad PARFile: $parfile\n";
		next;
	}
	push(@pars, $parfile);
}

foreach my $dir (@pardir)
{
	$dir = Apache->server_root_relative($dir);
	$dir =~ s/\/$//;
	if(!-d $dir) {
		print STDERR "Bad PARDir: $dir\n";
		next;
	}
	opendir(DIR, $dir);
	my @files = readdir(DIR);
	closedir(DIR);
	foreach my $file (@files) {
		next if($file !~ /\.$parext$/);
		next if(!-f "$dir/$file");
		push(@pars, "$dir/$file");
	}
}

my $parstr = join(' ', @pars);
eval "use PAR qw($parstr);";
die "Could not load PAR, $@\n" if($@);


foreach my $file (@pars) {
	my $zip = Archive::Zip->new($file);
	next unless(defined($zip));
	my $conf_member = $zip->memberNamed($conf_file);
	next if(!defined($conf_member));
	print STDERR "Including configuration from $file\n";
	my $conf = $conf_member->contents;
	$conf =~ s/##PARFILE##/$file/g;
	Apache->httpd_conf($conf);

}


1;
__END__

=head1 NAME

Apache::PAR - Perl extension for including Perl ARchive files in a mod_perl environment.

=head1 SYNOPSIS

  Inside Apache configuration:
    PARDir /path/to/par/archive/directory
    ...
    PARFile /path/to/a/par/file.par
    ...
    PerlModule Apache::PAR

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

Apache::PAR is a framework for including Perl ARchive files in a mod_perl environment.  It allows an author to package up a web application, including configuration, static files, Perl modules, and Registry and PerlRun scripts to include in a single file.  This archive can then be moved to other locations on the same system or distributed, and loaded with a single set of configuration options in the Apache configuration.

These modules are based on PAR.pm by Autrijus Tang and Archive::Zip by Ned Konz, as well as the mod_perl modules.  They extend the concept of PAR files to mod_perl, similar to how WAR archives work for Java. An archive (which is really a zip file), contains one or more elements which can be served to clients making requests to an Apache web server.  Scripts, modules, and static content should then be able to be served from within the .par archive without modifications.

Apache::PAR itself performs the work of specifying the location of PAR archives and allowing the loading of modules from these archives.  The files and paths can be specified at load time.  Once an archive has been located, an optional web.conf (filename configurable) is then loaded and included into the main web configuration.  Once Apache::PAR has been loaded, Perl Apache modules within these .par files can then be loaded.

The following steps are performed on any .par files which are found within either a PARDir or PARFile variable:

=over 4

=item * The .par file is loaded with PAR.pm, making any modules defined within it visible to Apache

=item * Apache::PAR checks for the existence of a web.conf file within each .par archive and, if found, includes that configuration into the main Apache configuration.

=back

=head2 Some things to note:

PerlSetVar configuration for PARDir and PARFile B<MUST> be before the PerlModule Apache::PAR line in the Apache configuration.  Any PARDir and PARFile variables after the PerlModule line will be ignored.

The arguments for PARDir and PARFile can be either an absolute path, or a relative path from Apache's server_root.  For example, if your Apache's server_root is /usr/local/apache, and you would like to load .par files from a parfiles/ subdirectory, use:
  PerlSetVar PARDir parfiles/

This will then look for .par files in the /usr/local/apache/parfiles directory.

The name of the configuration file which is loaded is configurable via PARConf (default is 'web.conf'.  For example, to set the include filename to 'include.conf' for all .par files:
  PerlSetVar PARConf include.conf

The extensions used when searching for .par archives in any PARDir is set using the PARExt variable in the Apache configuration (the default is 'par').  For example, to set the par extension to 'zip':
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

=head1 EXPORT

None by default.

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
