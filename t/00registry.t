# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
use Apache::test qw(skip_test have_httpd);
skip_test unless have_httpd;

plan tests => 6;

# Basic request
my $response = Apache::test->fetch('/test/registry/test.pl');
if(!$response->is_success) {
	ok(0);
	print STDERR "Received failure code: " . $response->code . "\n";
}
else {
	ok(1);
}

# Basic request (again, just to make sure nothing funny is going on)
my $response = Apache::test->fetch('/test/registry/test.pl');
if(!$response->is_success) {
	ok(0);
	print STDERR "Received failure code: " . $response->code . "\n";
}
else {
	ok(1);
}

# Test indexing
$response = Apache::test->fetch('/test/registry/');
if($response->is_success) {
	ok(0);
	print STDERR "Should have received failure code, instead got: " . $response->code . "\n";
}
else {
	ok(1);
}

# Test extra_path_info
$response = Apache::test->fetch('/test/registry/test/path.pl/JAPH');
if(!$response->is_success) {
	ok(0);
	print STDERR "Received failure code: " . $response->code . "\n";
}
else {
	my $content = $response->content;
	if($content ne  '/JAPH') {
		ok(0);
		print STDERR "Expected /JAPH, received $content\n";
	}
	else {
		ok(1);
	}
}

# Test extra_path_info (again, to make sure nothing funny is going on)
$response = Apache::test->fetch('/test/registry/test/path.pl/JAPH');
if(!$response->is_success) {
	ok(0);
	print STDERR "Received failure code: " . $response->code . "\n";
}
else {
	my $content = $response->content;
	if($content ne  '/JAPH') {
		ok(0);
		print STDERR "Expected /JAPH, received $content\n";
	}
	else {
		ok(1);
	}
}

# Test bad request (not found)
my $response = Apache::test->fetch('/test/registry/test/not_found.pl');
if($response->is_success) {
	ok(0);
	print STDERR "Should have failed, instead received: " . $response->code . "\n";
}
else {
	if($response->code != 404) {
		ok(0);
		print STDERR "Should have gotten file not found, instead received: " . $response->code . "\n";
	}
	else {
		ok(1);
	}
}

