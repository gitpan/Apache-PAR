package Apache::PAR::Registry;

use 5.005;
use strict;
use warnings;

require Exporter;
use vars qw(@ISA %EXPORT_TAGS @EXPORT_OK @EXPORT $VERSION);
@ISA = qw(Exporter Apache::PAR::ScriptBase Apache::RegistryNG);

%EXPORT_TAGS = ( 'all' => [ qw( ) ] );

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

@EXPORT = qw( );

$VERSION = '0.02';

use Apache::RegistryNG;
use Apache::Constants qw(:common);
use Apache::PAR::ScriptBase;

sub can_compile {
	my $pr = shift;

	my $status = $pr->SUPER::can_compile();
	return $status unless $status eq OK;
	return $pr->_can_compile();
}

sub namespace_from {
	shift->{_script_path};
}

sub run {
	my $pr = shift;
	$pr->_set_path_info();	
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
