# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
use Apache::test qw(skip_test have_httpd);
skip_test unless have_httpd;

BEGIN { plan tests => 5 };

# Basic request
my $response = Apache::test->fetch('/test/static/index.html');
if(!$response->is_success) {
	ok(0);
	print STDERR "Received failure code: " . $response->code . "\n";
}
else {
	ok(1);
}

# Test indexing
$response = Apache::test->fetch('/test/static/');
if(!$response->is_success) {
	ok(0);
	print STDERR "Received failure code: " . $response->code . "\n";
}
else {
	ok(1);
}

# Test default mime type
$response = Apache::test->fetch('/test/static/test/test.tst');
if(!$response->is_success) {
	ok(0);
	print STDERR "Received failure code: " . $response->code . "\n";
}
else {
	my $content_type = $response->header('Content-Type');
	if($content_type ne 'text/plain') {
		ok(0);
		print STDERR "Expected text/plain, received $content_type\n";
	}
	else {
		ok(1);
	}
}

# Test bad request (not found)
my $response = Apache::test->fetch('/test/static/test/doc.txt');
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

# Test bad request (no directory indexing)
my $response = Apache::test->fetch('/test/static/test/');
if($response->is_success) {
	ok(0);
	print STDERR "Should have failed, instead received: " . $response->code . "\n";
}
else {
	if($response->code != 403) {
		ok(0);
		print STDERR "Should have received forbidden, instead got: " . $response->code . "\n";
	}
	else {
		ok(1);
	}
}

#use Apache::PAR::Registry;
#ok(1); # If we made it this far, we're ok.


