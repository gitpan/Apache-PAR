# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Apache::Test qw(plan ok have_lwp);
use Apache::TestRequest qw(GET);
use Apache::TestUtil qw(t_cmp);

plan tests => 4, have_lwp;

# Basic request
for(1..2)
{
	my $response = GET '/test/module/';
	if(!$response->is_success) {
		ok(0);
		print STDERR "Received failure code: " . $response->code . "\n";
	}
	else {
		ok(1);
	}
}

# Test extra_path_info
for (1..2)
{
	$response = GET '/test/path/JAPH';
	if(!$response->is_success) {
		ok(0);
		print STDERR "Received failure code: " . $response->code . "\n";
	}
	else {
		my $content = $response->content;
		ok t_cmp('/JAPH', $content);
	}
}

