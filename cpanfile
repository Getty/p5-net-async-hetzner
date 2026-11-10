requires 'perl', '5.020';

requires 'Future', '0.47';
requires 'HTTP::Request';
requires 'IO::Async', '0.80';
requires 'IO::Async::Notifier';
requires 'IO::Async::SSL', '0.12';
requires 'Net::Async::HTTP', '0.49';
requires 'URI';
requires 'WWW::Hetzner', '0.103';

on test => sub {
    requires 'HTTP::Response';
    requires 'IO::Async::Loop';
    requires 'Test::More', '0.98';
};
