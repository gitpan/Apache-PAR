package Apache::PAR::PerlRun;

use 5.006;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter Apache::PerlRun);

our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( );

our $VERSION = '0.01';

use Apache::PerlRun;
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
	my $pr = shift;
	my $r  = $pr->{r};

	my $uri = $r->uri;

	my $path_info = $pr->{_extra_path_info};
	my $script_name = $path_info && $uri =~ /$path_info$/ ?
		substr($uri, 0, length($uri)-length($path_info)) :
		$uri;

	if($Apache::Registry::NameWithVirtualHost && $r->server->is_virtual) {
		my $name = $r->get_server_name;
		$script_name = join "", $name, $script_name if $name;
	}
	$script_name =~ s:/+$:/__INDEX__:;

	return $script_name;
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
	my $cur_path    = $r->dir_config('PARPerlRunPath') || 'scripts/';
	$cur_path =~ s/\/$//;

	my $zip = Archive::Zip->new($filename);
	unless(defined($zip)) {
		$r->log_error("Unable to open file $filename");
		return undef;
	}

	my $cur_member  = undef;
	while(defined(($cur_member = $zip->memberNamed($cur_path) || $zip->memberNamed("$cur_path/"))) && @path_broken) {
		last unless($cur_member->isDirectory());
		$cur_path .= '/' . shift(@path_broken);
	}
	$cur_member = $zip->memberNamed($cur_path);
	return undef unless (defined($cur_member));
	$pr->{_zip}             = $zip;
	$pr->{_member}          = $cur_member;
	$pr->{_script_path}     = $cur_path;
	$pr->{_extra_path_info} = join('/', @path_broken);
	return $cur_path;
}

sub compile {
	my ($pr, $eval) = @_;
	my $r = $pr->{r};
	my $path_info = $pr->{_extra_path_info} ? "/$pr->{_extra_path_info}" : '';
	$r->path_info($path_info);
	$ENV{PATH_INFO} = $path_info;
	$r->filename($pr->{_script_path});

	return $pr->SUPER::compile($eval);
}


1;
__END__

=head1 NAME

Apache::PAR::PerlRun - Apache::PerlRun subclass which serves Apache::PerlRun scripts to clients from within .par files.

=head1 SYNOPSIS

A sample configuration (within a web.conf) is below:

  Alias /myapp/cgi-run/ ##PARFILE##/
  <Location /myapp/cgi-run>
    Options +ExecCGI
    SetHandler perl-script
    PerlHandler Apache::PAR::PerlRun
    PerlSetVar PARPerlRunPath perlrun/
  </Location>

=head1 DESCRIPTION

Subclass of Apache::PerlRun to serve Apache::PerlRun scripts to clients from within .par files.  PerlRun scripts should continue to operate as they did before when inside a .par archive.

To use, add Apache::PAR::PerlRun into the Apache configuration, either through an Apache configuration file, or through a web.conf file (discussed in more detail in the Apache::PAR manpage.)


=head2 Some things to note:

Options +ExecCGI B<must> be turned on in the configuration in order to serve PerlRun scripts.

.par files must be executable by the web server user in order to serve PerlRun scripts.

File modification testing is performed on the script itself.  Otherwise modifying the surrounding package should not cause mod_perl to reload the module.

Modules can be loaded from within the .par archive as if they were physically on the filesystem.  However, because of the way PAR.pm works, your scripts can also load modules within other .par packages, as well as modules from your @INC.

By default, scripts are served under the scripts/ directory within a .par archive.  This value can be changed using the PARPerlRunPath variable, for instance:

PerlSetVar PARPerlRunPath perlrun/

=head1 EXPORT

None by default.

=head1 AUTHOR

Nathan Byrd, E<lt>nathan@byrd.netE<gt>

=head1 SEE ALSO

L<perl>.

L<PAR>, L<Apache::PAR>, and L<Apache::PerlRun>.

=head1 COPYRIGHT

Copyright 2002 by Nathan Byrd E<lt>nathan@byrd.netE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
