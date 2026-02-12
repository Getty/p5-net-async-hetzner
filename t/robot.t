#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use IO::Async::Loop;
use Future;
use HTTP::Response;
use Net::Async::Hetzner::Robot;

# ============================================================================
# Mock HTTP notifier (same pattern as cloud.t)
# ============================================================================

{
    package Test::MockAsyncHTTP;
    # Already defined in cloud.t, but tests run independently
    unless (Test::MockAsyncHTTP->can('new')) {
        eval q{
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
                my $http_res = HTTP::Response->new($mock->{status} // 200, 'OK');
                $http_res->content($mock->{content} // '');
                $http_res->header('Content-Type' => 'application/json');
                return Future->done($http_res);
            }

            sub requests { $_[0]->{requests} }
        };
    }
}

# ============================================================================
# Tests
# ============================================================================

subtest 'configuration' => sub {
    my $robot = Net::Async::Hetzner::Robot->new(
        user     => 'myuser',
        password => 'mypass',
    );

    is($robot->user, 'myuser', 'user configured');
    is($robot->password, 'mypass', 'password configured');
    is($robot->base_url, 'https://robot-ws.your-server.de', 'default base_url');
};

subtest 'missing credentials croaks' => sub {
    local $ENV{HETZNER_ROBOT_USER};
    local $ENV{HETZNER_ROBOT_PASSWORD};
    my $robot = Net::Async::Hetzner::Robot->new;
    eval { $robot->_check_auth };
    like($@, qr/No Robot credentials/, 'croaks without credentials');
};

subtest '_robot creates sync client' => sub {
    my $robot = Net::Async::Hetzner::Robot->new(
        user => 'u', password => 'p',
    );
    my $sync = $robot->_robot;
    isa_ok($sync, 'WWW::Hetzner::Robot');
    is($sync->user, 'u', 'sync client has same user');
};

subtest 'async get with Basic auth' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 200,
            content => '[{"server":{"server_number":123}}]',
        }],
    );

    my $robot = Net::Async::Hetzner::Robot->new(
        user => 'testuser', password => 'testpass',
    );
    $robot->{_http} = $mock_http;
    $loop->add($robot);

    my $data = $robot->get('/server')->get;
    is(ref $data, 'ARRAY', 'returns array');

    # Verify Basic auth header
    my $req = $mock_http->requests->[0]{request};
    is($req->method, 'GET', 'correct method');
    like($req->header('Authorization'), qr/^Basic /, 'Basic auth header');
};

subtest 'async post' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 200,
            content => '{"server":{"server_number":123,"server_name":"updated"}}',
        }],
    );

    my $robot = Net::Async::Hetzner::Robot->new(
        user => 'u', password => 'p',
    );
    $robot->{_http} = $mock_http;
    $loop->add($robot);

    my $data = $robot->post('/server/123', { server_name => 'updated' })->get;
    is($data->{server}{server_name}, 'updated', 'parsed response');
};

subtest 'async put' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 200,
            content => '{"server":{"server_number":123,"server_name":"renamed"}}',
        }],
    );

    my $robot = Net::Async::Hetzner::Robot->new(
        user => 'u', password => 'p',
    );
    $robot->{_http} = $mock_http;
    $loop->add($robot);

    my $data = $robot->put('/server/123', { server_name => 'renamed' })->get;
    is($data->{server}{server_name}, 'renamed', 'parsed PUT response');

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

    my $robot = Net::Async::Hetzner::Robot->new(
        user => 'u', password => 'p',
    );
    $robot->{_http} = $mock_http;
    $loop->add($robot);

    my $data = $robot->delete('/server/123/key/abc')->get;
    is_deeply($data, {}, 'DELETE returns empty response');

    my $req = $mock_http->requests->[0]{request};
    is($req->method, 'DELETE', 'correct HTTP method');
};

subtest 'async error handling' => sub {
    my $loop = IO::Async::Loop->new;

    my $mock_http = Test::MockAsyncHTTP->new(
        responses => [{
            status  => 401,
            content => '{"error":{"message":"Unauthorized"}}',
        }],
    );

    my $robot = Net::Async::Hetzner::Robot->new(
        user => 'u', password => 'p',
    );
    $robot->{_http} = $mock_http;
    $loop->add($robot);

    my $future = $robot->get('/server');
    ok($future->is_failed, 'future failed on 401');
    like(($future->failure)[0], qr/Unauthorized/, 'error message');
};

done_testing;
