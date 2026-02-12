requires 'perl', '5.020';

requires 'IO::Async', '0.80';
requires 'IO::Async::Loop';
requires 'IO::Async::Notifier';
requires 'Net::Async::HTTP', '0.49';
requires 'Future', '0.47';
requires 'URI';
requires 'HTTP::Request';

requires 'WWW::Hetzner';

on test => sub {
    requires 'Test::More', '0.98';
};
