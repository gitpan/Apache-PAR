package Apache::PAR::Registry;

use 5.006;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter Apache::RegistryNG);

our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( );

our $VERSION = '0.01';

use Apache::RegistryNG;
use Apache::Constants qw(:common);
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);

sub readscript {
	my $pr = shift;
	
	my $contents = $pr->{_member}->contents;
	$pr->{'code'} = \$contents;
}

sub can_compile {
	my $pr = shift;

	my $status = $pr->SUPER::can_compile();
	return $status unless $status eq OK;

	my $r = $pr->{r};
	my $filename  = $r->filename;
	my $path_info = $r->path_info;

	unless ($pr->_find_file_parts()) {
		my $msg = "$path_info not found or unable to stat inside $filename";
		$r->log_error($msg);
		$r->notes('error-notes', $msg);
		return NOT_FOUND;
	}

	if(defined($pr->{_member}) && $pr->{_member}->isDirectory()) {
		$r->log_reason("Unable to serve directory from PAR file", $filename);
		return FORBIDDEN;
	}

	$pr->{'mtime'} = $pr->{_member}->lastModTime();
	return wantarray ? (OK, $pr->{'mtime'}) : OK;
}


sub namespace_from {
	shift->{_script_path};
}

sub set_script_name {
	my $pr = shift;
	my $r  = $pr->{r};

	my @file_parts = split(/\//, $pr->{_script_path});
	my $filename = $file_parts[-1];
	*0 = \$filename;
}

sub _find_file_parts {
	my $pr          = shift;
	my $r           = $pr->{r};
	my $path_info   = $r->path_info;
	my $filename    = $r->filename;

	$path_info      =~ s/^\///;
	my @path_broken = split(/\//, $path_info);
	my $cur_path    = $r->dir_config('PARRegistryPath') || 'scripts/';
	$cur_path =~ s/\/$//;

	my $zip = Archive::Zip->new($filename);
	unless(defined($zip)) {
		$r->log_error("Unable to open file $filename");
		return undef;
	}

	my $cur_member  = undef;
	while(defined(($cur_member = $zip->memberNamed($cur_path) || $zip->memberNamed("$cur_path/"))) && @path_broken) {
		last if(!$cur_member->isDirectory());
		$cur_path .= '/' . shift(@path_broken);
	}
	$cur_member = $zip->memberNamed($cur_path);
	return undef unless(defined($cur_member));

	$pr->{_zip}             = $zip;
	$pr->{_member}          = $cur_member;
	$pr->{_script_path}     = $cur_path;
	$pr->{_extra_path_info} = join('/', @path_broken);
	return $cur_path;
}

sub run {
	my $pr = shift;
	my $r  = $pr->{r};
	
	my $path_info = $pr->{_extra_path_info} ? "/$pr->{_extra_path_info}" : '';
	$r->path_info($path_info);
	$r->filename($pr->{_script_path});

	return $pr->SUPER::run();
}

1;
__END__

=head1 NAME

Apache::PAR::Registry - Apache::Registry subclass which serves Apache::Registry scripts to clients from within .par files.

=head1 SYNOPSIS

A sample configuration (within a web.conf) is below:

  Alias /myapp/cgi-perl/ ##PARFILE##/
  <Location /myapp/cgi-perl>
    Options +ExecCGI
    SetHandler perl-script
    PerlHandler Apache::PAR::Registry
    PerlSetVar PARRegistryPath registry/
  </Location>

=head1 DESCRIPTION

Subclass of Apache::Registry to serve Apache::Registry scripts to clients from within .par files.  Registry scripts should continue to operate as they did before when inside a .par archive.

To use, add Apache::PAR::Registry into the Apache configuration, either through an Apache configuration file, or through a web.conf file (discussed in more detail in the Apache::PAR manpage.)


=head2 Some things to note:

Options +ExecCGI B<must> be turned on in the configuration in order to serve Registry scripts.

.par files must be executable by the web server user in order to serve Registry scripts.

File modification testing is performed on the script itself.  Otherwise modifying the surrounding package should not cause mod_perl to reload the module.

Modules can be loaded from within the .par archive as if they were physically on the filesystem.  However, because of the way PAR.pm works, your scripts can also load modules within other .par packages, as well as modules from your @INC.

By default, scripts are served under the scripts/ directory within a .par archive.  This value can be changed using the PARRegistryPath variable, for instance:

PerlSetVar PARRegistryPath registry/

=head1 EXPORT

None by default.

=head1 AUTHOR

Nathan Byrd, E<lt>nathan@byrd.netE<gt>

=head1 SEE ALSO

L<perl>.

L<PAR>, L<Apache::PAR>, and L<Apache::Registry>.

=head1 COPYRIGHT

Copyright 2002 by Nathan Byrd E<lt>nathan@byrd.netE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
