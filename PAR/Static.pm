package Apache::PAR::Static;

use 5.005;
use strict;
use warnings;

require Exporter;

use vars qw(@ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION);
@ISA = qw(Exporter);

%EXPORT_TAGS = ( 'all' => [ qw( ) ] );

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

@EXPORT = qw( );

$VERSION = '0.10';

if(eval "Apache::exists_config_define('MODPERL2')") {
	require Apache::Const;
	import Apache::Const qw(OK NOT_FOUND FORBIDDEN);
	require Apache::Response;
	require Apache::RequestRec;
	require Apache::RequestIO;
	require Apache::RequestUtil;
	require APR::Table;
}
else {
	require Apache::Constants;
	import Apache::Constants qw(OK NOT_FOUND FORBIDDEN);
	require Apache::File;
}

use MIME::Types();

sub handler {
	my $r = shift;

	my $filename    = $r->filename;

	(my $path_info = $r->path_info) =~ s/^\///;

	my $file_path    = $r->dir_config->get('PARStaticFilesPath') || 'htdocs/';
	$file_path      .= '/' if ($file_path !~ /\/$/);
	$file_path      .= $path_info;

	my $zip = Archive::Zip->new($filename);
	return NOT_FOUND() unless(defined($zip));

	my $member = $zip->memberNamed($file_path) || $zip->memberNamed("$file_path/");
	return NOT_FOUND() unless(defined($member));

	if($member->isDirectory()) {
		my @index_list = $r->dir_config->get('PARStaticDirectoryIndex');
		unless (@index_list) {
			$r->log_error('Cannot serve directory - set PARStaticDirectoryIndex to enable');
			return FORBIDDEN();
		}
		$file_path =~ s/\/$//;
		foreach my $index_name (@index_list) {
			if(defined($member = $zip->memberNamed("$file_path/$index_name"))) {
				$file_path .= "/$index_name";
				last;
			}
		}
		if(!defined($member) || $member->isDirectory()) {
			$r->log_error('Cannot serve directory.');
			return FORBIDDEN();
		}
	}	

	my $contents = $member->contents;
	return NOT_FOUND() unless defined($contents);

	my $last_modified = $member->lastModTime();

	$r->headers_out->set('Accept-Ranges' => 'bytes');

	$r->content_type(MIME::Types::by_suffix($file_path)->[0] || $r->dir_config->get('PARStaticDefaultMIME') || 'text/plain');
	(my $package = __PACKAGE__) =~ s/::/\//g;
	$r->update_mtime($last_modified);
	$r->update_mtime((stat $INC{"$package.pm"})[9]);
	$r->set_last_modified;

	$r->set_content_length(length($contents));


	if((my $status = $r->meets_conditions) eq OK()) {
		$r->send_http_header;
	}
	else {
		return $status;
	}
	return OK() if $r->header_only;

	my $range_request = 0;
	if(!eval "Apache::exists_config_define('MODPERL2')") {
		$range_request = $r->set_byterange;
	}

	if($range_request) {
		while(my($offset, $length) = $r->each_byterange) {
			$r->print(substr($contents, $offset, $length));
		}
	}
	else {
		$r->print($contents);
	}
	return OK();
}

1;
__END__

=head1 NAME

Apache::PAR::Static - Serve static content to clients from within .par files.

=head1 SYNOPSIS

A sample configuration (within a web.conf) is below:

  Alias /myapp/static/ ##PARFILE##/
  <Location /myapp/static>
    SetHandler perl-script
    PerlHandler Apache::PAR::Static
    PerlSetVar PARStaticDirectoryIndex index.htm
    PerlAddVar PARStaticDirectoryIndex index.html
    PerlSetVar PARStaticDefaultMIME text/html
  </Location>

=head1 DESCRIPTION

The Apache::PAR::Static module allows a .par file creator to place any static content into a .par archive (under a configurable directory in the .par file) to be served directly to clients.

To use, add Apache::PAR::Static into the Apache configuration, either through an Apache configuration file, or through a web.conf file (discussed in more detail in L<Apache::PAR>.)

=head2 Some things to note:

Apache::PAR::Static does not currently use Apache defaults in mod_dir.  Therefore, it is necessary to specify variables for directory index files and the default mime type.  To specify files to use for directory indexes, use the following syntax in the configuration:

  PerlSetVar PARStaticDirectoryIndex index.htm
  PerlAddVar PARStaticDirectoryIndex index.html
  ...

To set the default MIME type for requests, use:
  PerlSetVar PARStaticDefaultMIME text/html

Currently, Apache::PAR::Static does not have the ability to generate directory indexes for directories inside .par files.  Also, other Apache module features, such as language priority, do not take effect for content inside .par archives.

The default directory to serve static content out of in a .par file is htdocs/ to override this, set the PARStaticFilesPath variable.  For example, to set this to serve files from a static/ directory within the .par file, use:
  PerlSetVar PARStaticFilesPath static/

Under mod_perl 1.x, byte range requests are supported, to facilitate the serving of PDF files, etc. For mod_perl 2.x users, use the appropriate Apache filter (currently untested.)

=head1 EXPORT

None by default.

=head1 AUTHOR

Nathan Byrd, E<lt>nathan@byrd.netE<gt>

=head1 SEE ALSO

L<perl>.

L<PAR>.

=head1 COPYRIGHT

Copyright 2002 by Nathan Byrd E<lt>nathan@byrd.netE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
