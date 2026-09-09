package Test::MockAsyncHTTP;

use strict;
use warnings;
use parent 'IO::Async::Notifier';

use HTTP::Response;
use Future;

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

1;
