---
name: hetzner-perl
description: "WWW::Hetzner + Net::Async::Hetzner — Hetzner Cloud & Robot API clients for Perl"
user-invocable: false
allowed-tools: Read, Grep, Glob
model: sonnet
---

# Hetzner Perl API Clients

Two distributions: WWW::Hetzner (sync) and Net::Async::Hetzner (async).

## WWW::Hetzner — Synchronous Client

### Cloud API (api.hetzner.cloud)

```perl
use WWW::Hetzner::Cloud;
my $cloud = WWW::Hetzner::Cloud->new(token => $ENV{HETZNER_API_TOKEN});

# Servers
$cloud->servers->list;
$cloud->servers->create(name => 'web', server_type => 'cx22', image => 'debian-12');
$cloud->servers->get($id);
$cloud->servers->delete($id);

# Volumes
$cloud->volumes->create(name => 'data', size => 50, location => 'fsn1');
$cloud->volumes->list;

# Networks
$cloud->networks->create(name => 'mynet', ip_range => '10.0.0.0/8');

# Firewalls
$cloud->firewalls->create(name => 'web-fw');

# DNS Zones
$cloud->zones->create(name => 'example.com');

# Also: load_balancers, floating_ips, primary_ips, ssh_keys,
#        certificates, placement_groups, images, isos, datacenters
```

### Robot API (robot-ws.your-server.de) — Dedicated Servers

```perl
use WWW::Hetzner::Robot;
my $robot = WWW::Hetzner::Robot->new(user => $user, password => $pass);

$robot->servers->list;
$robot->reset->software($server_number);
$robot->traffic->query(ip => '1.2.3.4', from => '2024-01-01', to => '2024-01-31');
```

### Architecture

- **Moo** OOP, namespace::clean
- **Pluggable HTTP** via `WWW::Hetzner::Role::IO` (default: LWP::UserAgent)
- **Log::Any** for logging
- **API controllers** in `WWW::Hetzner::Cloud::API::*` (Servers, Volumes, Networks, etc.)
- **Entity objects** with convenience methods

### CLI Tools

```bash
perl bin/hcloud.pl servers list
perl bin/hrobot.pl servers list
```

## Net::Async::Hetzner — Async Client

Wraps WWW::Hetzner with IO::Async + Net::Async::HTTP. Returns Futures.

```perl
use IO::Async::Loop;
use Net::Async::Hetzner::Cloud;

my $loop = IO::Async::Loop->new;
my $cloud = Net::Async::Hetzner::Cloud->new(token => $ENV{HETZNER_API_TOKEN});
$loop->add($cloud);

# All methods return Futures
my $servers = $cloud->get('/servers')->get;

$cloud->post('/servers', { name => 'test', server_type => 'cx22', image => 'debian-12' })
  ->then(sub { my ($data) = @_; say "Created: $data->{server}{id}" })
  ->get;
```

## Repos

- `p5-www-hetzner/` — WWW::Hetzner (sync)
- `p5-net-async-hetzner/` — Net::Async::Hetzner (async)
