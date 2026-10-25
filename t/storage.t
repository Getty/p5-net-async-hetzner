#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use IO::Async::Loop;
use Future;
use Net::Async::Hetzner::Storage;

use lib 't/lib';
use Test::MockAsyncHTTP;

subtest 'configuration' => sub {
    my $storage = Net::Async::Hetzner::Storage->new(
        token    => 'my-token',
        base_url => 'https://custom.api/v1',
    );

    isa_ok($storage, 'Net::Async::Hetzner::Base');
    is($storage->token, 'my-token', 'token configured');
    is($storage->base_url, 'https://custom.api/v1', 'custom base_url');
    is($storage->timeout, 30, 'default timeout');
};

subtest 'default base_url' => sub {
    my $storage = Net::Async::Hetzner::Storage->new(token => 'test');
    is($storage->base_url, 'https://api.hetzner.com/v1', 'storage API host');
};

subtest '_sync creates sync client and reconfigure drops it' => sub {
    my $storage = Net::Async::Hetzner::Storage->new(token => 'a');
    my $sync = $storage->_sync;
    isa_ok($sync, 'WWW::Hetzner::Storage');
    is($sync->token, 'a', 'sync client has same token');

    $storage->configure(token => 'b');
    is($storage->_sync->token, 'b', 'new token after configure');
};

subtest 'missing token croaks before any request' => sub {
    local $ENV{HETZNER_API_TOKEN};
    my $loop = IO::Async::Loop->new;
    my $mock_http = Test::MockAsyncHTTP->new(responses => [{ content => '{}' }]);

    my $storage = Net::Async::Hetzner::Storage->new;
    $storage->{_http} = $mock_http;
    $loop->add($storage);

    eval { $storage->get('/storage_boxes') };
    like($@, qr/No Storage API token/, 'croaks without token');
    is(scalar @{$mock_http->requests}, 0, 'nothing sent');
};

subtest 'async get' => sub {
    my $loop = IO::Async::Loop->new;
    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 200,
            content => '{"storage_boxes":[{"id":7,"name":"box"}]}',
        }],
    );

    my $storage = Net::Async::Hetzner::Storage->new(token => 'test-token');
    $storage->{_http} = $mock_http;
    $loop->add($storage);

    my $future = $storage->get('/storage_boxes', params => { name => 'box' });
    isa_ok($future, 'Future', 'get returns Future');
    is($future->get->{storage_boxes}[0]{name}, 'box', 'parsed response data');

    my $req = $mock_http->requests->[0]{request};
    is($req->method, 'GET', 'correct HTTP method');
    like($req->uri, qr{^https://api\.hetzner\.com/v1/storage_boxes\?name=box$}, 'storage host and path');
    is($req->header('Authorization'), 'Bearer test-token', 'auth header set');
    is($mock_http->requests->[0]{timeout}, 30, 'default timeout sent');
};

subtest 'async post sends JSON body' => sub {
    my $loop = IO::Async::Loop->new;
    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{ status => 201, content => '{"storage_box":{"id":8}}' }],
    );

    my $storage = Net::Async::Hetzner::Storage->new(token => 'test-token');
    $storage->{_http} = $mock_http;
    $loop->add($storage);

    my $data = $storage->post('/storage_boxes', { name => 'new-box' })->get;
    is($data->{storage_box}{id}, 8, 'parsed POST response');

    my $req = $mock_http->requests->[0]{request};
    is($req->method, 'POST', 'correct HTTP method');
    is($req->header('Content-Type'), 'application/json', 'JSON content type');
    like($req->content, qr/"name"\s*:\s*"new-box"/, 'JSON body');
};

subtest 'async put and delete' => sub {
    my $loop = IO::Async::Loop->new;
    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{ status => 200, content => '{}' }],
    );

    my $storage = Net::Async::Hetzner::Storage->new(token => 'test-token');
    $storage->{_http} = $mock_http;
    $loop->add($storage);

    $storage->put('/storage_boxes/7', { name => 'renamed' })->get;
    $storage->delete('/storage_boxes/7')->get;

    is($mock_http->requests->[0]{request}->method, 'PUT', 'PUT sent');
    is($mock_http->requests->[1]{request}->method, 'DELETE', 'DELETE sent');
};

subtest 'async error handling' => sub {
    my $loop = IO::Async::Loop->new;
    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 404,
            content => '{"error":{"message":"Storage Box not found"}}',
        }],
    );

    my $storage = Net::Async::Hetzner::Storage->new(token => 'test-token');
    $storage->{_http} = $mock_http;
    $loop->add($storage);

    my $future = $storage->get('/storage_boxes/999');
    ok($future->is_failed, 'future failed');
    like(($future->failure)[0], qr/Storage Box not found/, 'error message propagated');
};

subtest 'configurable timeout' => sub {
    my $loop = IO::Async::Loop->new;
    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{ status => 200, content => '{}' }],
    );

    my $storage = Net::Async::Hetzner::Storage->new(token => 't', timeout => 5);
    $storage->{_http} = $mock_http;
    $loop->add($storage);

    $storage->get('/storage_boxes')->get;
    is($mock_http->requests->[0]{timeout}, 5, 'configured timeout sent');

    $storage->configure(timeout => 0);
    $storage->get('/storage_boxes')->get;
    ok(!exists $mock_http->requests->[1]{timeout}, 'timeout 0 sends no timeout');
};

done_testing;
