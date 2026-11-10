#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use IO::Async::Loop;
use Future;
use HTTP::Response;
use Net::Async::Hetzner::Cloud;
use WWW::Hetzner::HTTPRequest;

use lib 't/lib';
use Test::MockAsyncHTTP;

# ============================================================================
# Tests
# ============================================================================

subtest 'configuration' => sub {
    my $cloud = Net::Async::Hetzner::Cloud->new(
        token    => 'my-token',
        base_url => 'https://custom.api/v1',
    );

    is($cloud->token, 'my-token', 'token configured');
    is($cloud->base_url, 'https://custom.api/v1', 'custom base_url');
};

subtest 'default base_url' => sub {
    my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test');
    is($cloud->base_url, 'https://api.hetzner.cloud/v1', 'default base_url');
};

subtest 'missing token croaks' => sub {
    local $ENV{HETZNER_API_TOKEN};
    my $cloud = Net::Async::Hetzner::Cloud->new;
    eval { $cloud->token };
    like($@, qr/No Cloud API token/, 'croaks without token');
};

subtest '_cloud creates sync client' => sub {
    my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test');
    my $sync = $cloud->_cloud;
    isa_ok($sync, 'WWW::Hetzner::Cloud');
    is($sync->token, 'test', 'sync client has same token');
};

subtest 'async get returns Future' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 200,
            content => '{"servers":[{"id":1,"name":"test-server"}]}',
        }],
    );

    my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test-token');
    $cloud->{_http} = $mock_http;
    $loop->add($cloud);

    my $future = $cloud->get('/servers');
    isa_ok($future, 'Future', 'get returns Future');

    my $data = $future->get;
    is(ref $data, 'HASH', 'resolved to hashref');
    is($data->{servers}[0]{name}, 'test-server', 'parsed response data');

    # Verify the HTTP request was correct
    my $req = $mock_http->requests->[0]{request};
    is($req->method, 'GET', 'correct HTTP method');
    like($req->uri, qr{/servers$}, 'correct path');
    is($req->header('Authorization'), 'Bearer test-token', 'auth header set');
};

subtest 'async post sends body' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 201,
            content => '{"server":{"id":42,"name":"new-server"}}',
        }],
    );

    my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test-token');
    $cloud->{_http} = $mock_http;
    $loop->add($cloud);

    my $data = $cloud->post('/servers', {
        name        => 'new-server',
        server_type => 'cx22',
        image       => 'debian-12',
    })->get;

    is($data->{server}{name}, 'new-server', 'parsed POST response');

    my $req = $mock_http->requests->[0]{request};
    is($req->method, 'POST', 'correct HTTP method');
    like($req->content, qr/"name"/, 'request body contains name');
    like($req->content, qr/"server_type"/, 'request body contains server_type');
    is($req->header('Content-Type'), 'application/json', 'cloud body stays JSON');
    like($req->content, qr{^\s*\{}, 'cloud body is a JSON object');
};

subtest 'async put' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 200,
            content => '{"server":{"id":1,"name":"renamed"}}',
        }],
    );

    my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test-token');
    $cloud->{_http} = $mock_http;
    $loop->add($cloud);

    my $data = $cloud->put('/servers/1', { name => 'renamed' })->get;
    is($data->{server}{name}, 'renamed', 'parsed PUT response');

    my $req = $mock_http->requests->[0]{request};
    is($req->method, 'PUT', 'correct HTTP method');
};

subtest 'async delete' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 200,
            content => '{}',
        }],
    );

    my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test-token');
    $cloud->{_http} = $mock_http;
    $loop->add($cloud);

    my $data = $cloud->delete('/servers/1')->get;
    is_deeply($data, {}, 'DELETE returns empty response');

    my $req = $mock_http->requests->[0]{request};
    is($req->method, 'DELETE', 'correct HTTP method');
};

subtest 'async error handling' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 404,
            content => '{"error":{"message":"Server not found"}}',
        }],
    );

    my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test-token');
    $cloud->{_http} = $mock_http;
    $loop->add($cloud);

    my $future = $cloud->get('/servers/999');
    ok($future->is_ready, 'future resolved');
    ok($future->is_failed, 'future failed');
    like(($future->failure)[0], qr/Server not found/, 'error message propagated');
};

subtest 'async error is a WWW::Hetzner::Error object' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 404,
            content => '{"error":{"code":"not_found","message":"Server not found"}}',
        }],
    );

    my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test-token');
    $cloud->{_http} = $mock_http;
    $loop->add($cloud);

    my $future = $cloud->get('/servers/999');
    ok($future->is_failed, 'future failed');
    my $error = ($future->failure)[0];
    isa_ok($error, 'WWW::Hetzner::Error', 'failure');
    is($error->status, 404, 'status');
    is($error->code, 'not_found', 'code');
    is($error->api_message, 'Server not found', 'api_message');
    like("$error", qr/Server not found.*404 not_found/s, 'stringified form');
};

subtest 'parallel requests' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [
            { status => 200, content => '{"servers":[]}' },
            { status => 200, content => '{"volumes":[]}' },
        ],
    );

    my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test-token');
    $cloud->{_http} = $mock_http;
    $loop->add($cloud);

    my @futures = (
        $cloud->get('/servers'),
        $cloud->get('/volumes'),
    );

    my @results = map { $_->get } Future->wait_all(@futures)->get;

    is(scalar @{$mock_http->requests}, 2, 'two requests made');
};

subtest 'get with query params' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 200,
            content => '{"servers":[]}',
        }],
    );

    my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test-token');
    $cloud->{_http} = $mock_http;
    $loop->add($cloud);

    $cloud->get('/servers', params => { label_selector => 'env=prod' })->get;

    my $req = $mock_http->requests->[0]{request};
    like($req->uri, qr{label_selector=env%3Dprod}, 'query value is URI-encoded');
};

subtest 'query unicode value encoded' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 200,
            content => '{"servers":[]}',
        }],
    );

    my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test-token');
    $cloud->{_http} = $mock_http;
    $loop->add($cloud);

    $cloud->get('/servers', params => { name => "M\x{fc}nchen" })->get;

    my $req = $mock_http->requests->[0]{request};
    like($req->uri, qr{name=M%C3%BCnchen}, 'unicode query value UTF-8 percent-encoded');
};

subtest 'query arrayref becomes repeated params' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 200,
            content => '{"servers":[]}',
        }],
    );

    my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test-token');
    $cloud->{_http} = $mock_http;
    $loop->add($cloud);

    $cloud->get('/servers', params => { sort => ['name:asc', 'id:desc'] })->get;

    my $req = $mock_http->requests->[0]{request};
    like($req->uri, qr{sort=name%3Aasc&sort=id%3Adesc}, 'arrayref -> repeated params');
    unlike($req->uri, qr{sort%5B%5D}, 'no bracket form for query arrays');
};

subtest 'request timeout defaults to 30s and is passed to the transport' => sub {
    my $loop = IO::Async::Loop->new;
    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{ status => 200, content => '{}' }],
    );

    my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test-token');
    $cloud->{_http} = $mock_http;
    $loop->add($cloud);

    is($cloud->timeout, 30, 'default timeout');
    $cloud->get('/servers')->get;
    is($mock_http->requests->[0]{timeout}, 30, 'default timeout sent with request');

    $cloud->configure(timeout => 5);
    is($cloud->timeout, 5, 'timeout configurable');
    $cloud->get('/servers')->get;
    is($mock_http->requests->[1]{timeout}, 5, 'configured timeout sent with request');

    $cloud->configure(timeout => 0);
    $cloud->get('/servers')->get;
    ok(!exists $mock_http->requests->[2]{timeout}, 'timeout 0 sends no timeout');
};

done_testing;
