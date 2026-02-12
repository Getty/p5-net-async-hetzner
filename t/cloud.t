#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use IO::Async::Loop;
use Future;
use HTTP::Response;
use Net::Async::Hetzner::Cloud;
use WWW::Hetzner::HTTPRequest;

# ============================================================================
# Mock HTTP notifier for testing async transport
# ============================================================================

{
    package Test::MockAsyncHTTP;
    use parent 'IO::Async::Notifier';

    sub new {
        my ($class, %args) = @_;
        my $self = $class->SUPER::new;
        $self->{responses} = $args{responses} // [];
        $self->{requests}  = [];
        $self->{call_idx}  = 0;
        return $self;
    }

    sub do_request {
        my ($self, %args) = @_;
        push @{$self->{requests}}, \%args;

        my $idx = $self->{call_idx}++;
        my $mock = $self->{responses}[$idx] // $self->{responses}[0];

        my $http_res = HTTP::Response->new(
            $mock->{status} // 200,
            $mock->{reason} // 'OK',
        );
        $http_res->content($mock->{content} // '');
        $http_res->header('Content-Type' => 'application/json');

        return Future->done($http_res);
    }

    sub requests { $_[0]->{requests} }
}

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
    like($req->uri, qr{label_selector=env=prod}, 'query params in URL');
};

done_testing;
