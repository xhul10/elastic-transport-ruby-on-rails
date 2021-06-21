# Elastic Transport
[![Run tests](https://github.com/elastic/elastic-transport-ruby/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/elastic/elastic-transport-ruby/actions/workflows/tests.yml)

This gem provides a low-level Ruby client for connecting to an [Elastic](http://elastic.co) cluster. It powers both the [Elasticsearch client](https://github.com/elasticsearch/elasticsearch-ruby/) and the [Elastic Enterprise Search](https://github.com/elastic/enterprise-search-ruby/) client.

## Compatibility

This gem is compatible with maintained Ruby versions. See [Ruby Maintenance Branches](https://www.ruby-lang.org/en/downloads/branches/). We don't provide support to versions which have reached their end of life.

The gem's version numbers follow Elastic's Stack major versions. The `master` branch is compatible with the Elastic Stack `master` branch, which is the next major version.

| Client version  | Elastic Stack version | Supported | Tests |
| :-------------: | :-------------------: | :-:       | :---: |
| 7.x             | 7.x                   | :white_check_mark:       |       |
| master          | master                | :x:       |  [![Tests](https://github.com/elastic/elastic-transport-ruby/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/elastic/elastic-transport-ruby/actions/workflows/tests.yml) |


## Installation

Install the package from [Rubygems](https://rubygems.org):

    gem install elastic-transport

To use an unreleased version, either add it to your `Gemfile` for [Bundler](http://gembundler.com):

    gem 'elastic-transport', git: 'git://github.com/elastic/elastic-transport-ruby.git'

or install it from a source code checkout:

```bash
git clone https://github.com/elastic/elastic-transport-ruby.git
cd elastic-transport-ruby
bundle install
rake install
```

## Description

It handles connecting to multiple nodes in the cluster, rotating across connections, logging and tracing requests and responses, maintaining failed connections, discovering nodes in the cluster, and provides an abstraction for
data serialization and transport.

It does not handle calling the Elasticsearch API; see the [`elasticsearch`](https://github.com/elasticsearch/elasticsearch-ruby) library for that.

Features overview:

* Pluggable logging and tracing
* Pluggable connection selection strategies (round-robin, random, custom)
* Pluggable transport implementation, customizable and extendable
* Pluggable serializer implementation
* Request retries and dead connections handling
* Node reloading (based on cluster state) on errors or on demand

For optimal performance, use a HTTP library which supports persistent ("keep-alive") connections, such as [patron](https://github.com/toland/patron) or [Typhoeus](https://github.com/typhoeus/typhoeus).
Just require the library (`require 'patron'`) in your code, and it will be automatically used.

Currently these libraries will be automatically detected and used:
- [Patron](https://github.com/toland/patron)
- [Typhoeus](https://github.com/typhoeus/typhoeus)
- [HTTPClient](https://rubygems.org/gems/httpclient)
- [Net::HTTP::Persistent](https://rubygems.org/gems/net-http-persistent)

**Note on [Typhoeus](https://github.com/typhoeus/typhoeus)**: You need to use v1.4.0 or up since older versions are not compatible with Faraday 1.0.

For detailed information, see example configurations [below](#transport-implementations).

## Example Usage

In the simplest form, connect to Elasticsearch running on <http://localhost:9200>
without any configuration:

```ruby
require 'elastic/transport'

client = Elastic::Transport::Client.new
response = client.perform_request('GET', '_cluster/health')
# => #<Elastic::Transport::Transport::Response:0x007fc5d506ce38 @status=200, @body={ ... } >
```

Full documentation is available at <http://rubydoc.info/gems/elastic-transport>.

## Configuration

* [Setting Hosts](#setting-hosts)
* [Default port](#default-port)
* [Authentication](#authentication)
* [Logging](#logging)
* [Custom HTTP Headers](#custom-http-headers)
* [Setting Timeouts](#setting-timeouts)
* [Randomizing Hosts](#randomizing-hosts)
* [Retrying on Failures](#retrying-on-failures)
* [Reloading Hosts](#reloading-hosts)
* [Connection Selector](#connection-selector)
* [Transport Implementations](#transport-implementations)
* [Serializer implementations](#serializer-implementations)
* [Exception Handling](#exception-handling)
* [Development and Community](#development-and-community)

The client supports many configurations options for setting up and managing connections,
configuring logging, customizing the transport library, etc.

### Setting Hosts

To connect to a specific Elasticsearch host:

```ruby
Elastic::Transport::Client.new host: 'search.myserver.com'
```

To connect to a host with specific port:

```ruby
Elastic::Transport::Client.new host: 'myhost:8080'
```

To connect to multiple hosts:

```ruby
Elastic::Transport::Client.new hosts: ['myhost1', 'myhost2']
```


Instead of Strings, you can pass host information as an array of Hashes:

```ruby
Elastic::Transport::Client.new hosts: [ { host: 'myhost1', port: 8080 }, { host: 'myhost2', port: 8080 } ]
```

**NOTE:** When specifying multiple hosts, you probably want to enable the `retry_on_failure` or `retry_on_status` options to
          perform a failed request on another node (see the _Retrying on Failures_ chapter).

Common URL parts -- scheme, HTTP authentication credentials, URL prefixes, etc -- are handled automatically:
```ruby
Elastic::Transport::Client.new url: 'https://username:password@api.server.org:4430/search'
```

You can pass multiple URLs separated by a comma:
```ruby
Elastic::Transport::Client.new urls: 'http://localhost:9200,http://localhost:9201'
```

Another way to configure the URL(s) is to export the `ELASTICSEARCH_URL` variable.

The client will automatically round-robin across the hosts
(unless you select or implement a different [connection selector](#connection-selector)).

### Default port

The default port is `9200`. Please specify a port for your host(s) if they differ from this default.
Please see below for an exception to this when connecting using an Elastic Cloud ID.

### Authentication

You can pass the authentication credentials, scheme and port in the host configuration hash:

```ruby
Elastic::Transport::Client.new(
    hosts: [
           { host: 'my-protected-host',
    port: '443',
    user: 'USERNAME',
    password: 'PASSWORD',
    scheme: 'https'
  } 
]
```
... or simply use the common URL format:

```ruby
Elastic::Transport::Client.new(url: 'https://username:password@example.com:9200')
```

To pass a custom certificate for SSL peer verification to Faraday-based clients,
use the `transport_options` option:

```ruby
Elastic::Transport::Client.new url: 'https://username:password@example.com:9200',
                          transport_options: { ssl: { ca_file: '/path/to/cacert.pem' } }
```

### Logging

To log requests and responses to standard output with the default logger (an instance of Ruby's {::Logger} class), set the `log` argument to true:

```ruby
Elastic::Transport::Client.new(log: true)
```

You can also use [ecs-logging](https://github.com/elastic/ecs-logging-ruby). `ecs-logging` is a set of libraries that allows you to transform your application logs to structured logs that comply with the [Elastic Common Schema (ECS)](https://www.elastic.co/guide/en/ecs/current/ecs-reference.html):

```ruby
logger = EcsLogging::Logger.new($stdout)
Elastic::Transport::Client.new(logger: logger)
```

To trace requests and responses in the _Curl_ format, set the `trace` argument:

```ruby
Elastic::Transport::Client.new(trace: true)
```

You can customize the default logger or tracer:

```ruby
client.transport.logger.formatter = proc { |s, d, p, m| "#{s}: #{m}\n" }
client.transport.logger.level = Logger::INFO
```

Or, you can use a custom `::Logger` instance:

```ruby
Elastic::Transport::Client.new(logger: Logger.new(STDERR))
```

You can pass the client any conforming logger implementation:

```ruby
require 'logging' # https://github.com/TwP/logging/

log = Logging.logger['elasticsearch']
log.add_appenders Logging.appenders.stdout
log.level = :info

client = Elastic::Transport::Client.new(logger: log)
```

### Custom HTTP Headers

You can set a custom HTTP header on the client's initializer:

```ruby
client = Elastic::Transport::Client.new(
  transport_options: {
    headers:
      {user_agent: "My App"}
  }
)
```

You can also pass in `headers` as a parameter to any of the API Endpoints to set custom headers for the request:

```ruby
client.search(index: 'myindex', q: 'title:test', headers: {user_agent: "My App"})
```

### Setting Timeouts

For many operations in Elasticsearch, the default timeouts of HTTP libraries are too low.
To increase the timeout, you can use the `request_timeout` parameter:

```ruby
Elastic::Transport::Client.new request_timeout: 5*60
```

You can also use the `transport_options` argument documented below.

### Randomizing Hosts

If you pass multiple hosts to the client, it rotates across them in a round-robin fashion, by default.
When the same client would be running in multiple processes (eg. in a Ruby web server such as Thin),
it might keep connecting to the same nodes "at once". To prevent this, you can randomize the hosts
collection on initialization and reloading:

```ruby
Elastic::Transport::Client.new hosts: ['localhost:9200', 'localhost:9201'], randomize_hosts: true
```

### Retrying on Failures

When the client is initialized with multiple hosts, it makes sense to retry a failed request
on a different host:

```ruby
Elastic::Transport::Client.new hosts: ['localhost:9200', 'localhost:9201'], retry_on_failure: true
```

By default, the client will retry the request 3 times. You can specify how many times to retry before it raises an exception by passing a number to `retry_on_failure`:

```ruby
Elastic::Transport::Client.new hosts: ['localhost:9200', 'localhost:9201'], retry_on_failure: 5
```

You can also use `retry_on_status` to retry when specific status codes are returned:

```ruby
Elastic::Transport::Client.new hosts: ['localhost:9200', 'localhost:9201'], retry_on_status: [502, 503]
```

These two parameters can also be used together:

```ruby
Elastic::Transport::Client.new hosts: ['localhost:9200', 'localhost:9201'], retry_on_status: [502, 503], retry_on_failure: 10
```

### Reloading Hosts

Elasticsearch by default dynamically discovers new nodes in the cluster. You can leverage this
in the client, and periodically check for new nodes to spread the load.

To retrieve and use the information from the
[_Nodes Info API_](http://www.elastic.co/guide/en/elasticsearch/reference/current/cluster-nodes-info.html)
on every 10,000th request:

```ruby
Elastic::Transport::Client.new hosts: ['localhost:9200', 'localhost:9201'], reload_connections: true
```

You can pass a specific number of requests after which the reloading should be performed:

```ruby
Elastic::Transport::Client.new hosts: ['localhost:9200', 'localhost:9201'], reload_connections: 1_000
```

To reload connections on failures, use:

```ruby
Elastic::Transport::Client.new hosts: ['localhost:9200', 'localhost:9201'], reload_on_failure: true
```

The reloading will timeout if not finished under 1 second by default. To change the setting:

```ruby
Elastic::Transport::Client.new hosts: ['localhost:9200', 'localhost:9201'], sniffer_timeout: 3
```

**NOTE:** When using reloading hosts ("sniffing") together with authentication, just pass the scheme,
          user and password with the host info -- or, for more clarity, in the `http` options:

```ruby
Elastic::Transport::Client.new host: 'localhost:9200',
                          http: { scheme: 'https', user: 'U', password: 'P' },
                          reload_connections: true,
                          reload_on_failure: true
```

### Connection Selector

By default, the client will rotate the connections in a round-robin fashion, using the
{Elastic::Transport::Transport::Connections::Selector::RoundRobin} strategy.

You can implement your own strategy to customize the behaviour. For example,
let's have a "rack aware" strategy, which will prefer the nodes with a specific
[attribute](https://github.com/elasticsearch/elasticsearch/blob/1.0/config/elasticsearch.yml#L81-L85).
Only when these would be unavailable, the strategy will use the other nodes:

```ruby
class RackIdSelector
  include Elastic::Transport::Transport::Connections::Selector::Base

  def select(options={})
    connections.select do |c|
      # Try selecting the nodes with a `rack_id:x1` attribute first
      c.host[:attributes] && c.host[:attributes][:rack_id] == 'x1'
    end.sample || connections.to_a.sample
  end
end

Elastic::Transport::Client.new hosts: ['x1.search.org', 'x2.search.org'], selector_class: RackIdSelector
```

### Transport Implementations

By default, the client will use the [_Faraday_](https://rubygems.org/gems/faraday) HTTP library
as a transport implementation.

It will auto-detect and use an _adapter_ for _Faraday_ based on gems loaded in your code,
preferring HTTP clients with support for persistent connections.

To use the [_Patron_](https://github.com/toland/patron) HTTP, for example, just require it:

```ruby
require 'patron'
```

Then, create a new client, and the _Patron_  gem will be used as the "driver":

```ruby
client = Elastic::Transport::Client.new

client.transport.connections.first.connection.builder.adapter
# => Faraday::Adapter::Patron

10.times do
  client.nodes.stats(metric: 'http')['nodes'].values.each do |n|
    puts "#{n['name']} : #{n['http']['total_opened']}"
  end
end

# => Stiletoo : 24
# => Stiletoo : 24
# => Stiletoo : 24
# => ...
```

To use a specific adapter for _Faraday_, pass it as the `adapter` argument:

```ruby
client = Elastic::Transport::Client.new adapter: :net_http_persistent

client.transport.connections.first.connection.builder.handlers
# => [Faraday::Adapter::NetHttpPersistent]
```

To pass options to the
[`Faraday::Connection`](https://github.com/lostisland/faraday/blob/master/lib/faraday/connection.rb)
constructor, use the `transport_options` key:

```ruby
client = Elastic::Transport::Client.new transport_options: {
  request: { open_timeout: 1 },
  headers: { user_agent:   'MyApp' },
  params:  { :format => 'yaml' },
  ssl:     { verify: false }
}
```

To configure the _Faraday_ instance directly, use a block:

```ruby
require 'patron'

client = Elastic::Transport::Client.new(host: 'localhost', port: '9200') do |f|
  f.response :logger
  f.adapter  :patron
end
```

You can use any standard Faraday middleware and plugins in the configuration block. You can also initialize the transport class yourself, and pass it to the client constructor as the `transport` argument:

```ruby
require 'patron'

transport_configuration = lambda do |f|
  f.response :logger
  f.adapter  :patron
end

transport = Elastic::Transport::Transport::HTTP::Faraday.new \
  hosts: [ { host: 'localhost', port: '9200' } ],
  &transport_configuration

# Pass the transport to the client
#
client = Elastic::Transport::Client.new transport: transport
```

Instead of passing the transport to the constructor, you can inject it at run time:

```ruby
# Set up the transport
#
faraday_configuration = lambda do |f|
  f.instance_variable_set :@ssl, { verify: false }
  f.adapter :excon
end

faraday_client = Elastic::Transport::Transport::HTTP::Faraday.new \
  hosts: [ { host: 'my-protected-host',
             port: '443',
             user: 'USERNAME',
             password: 'PASSWORD',
             scheme: 'https'
          }],
  &faraday_configuration

# Create a default client
#
client = Elastic::Transport::Client.new

# Inject the transport to the client
#
client.transport = faraday_client
```

You can also use a bundled [_Curb_](https://rubygems.org/gems/curb) based transport implementation:

```ruby
require 'curb'
require 'elastic/transport/transport/http/curb'

client = Elastic::Transport::Client.new transport_class: Elastic::Transport::Transport::HTTP::Curb

client.transport.connections.first.connection
# => #<Curl::Easy http://localhost:9200/>
```

It's possible to customize the _Curb_ instance by passing a block to the constructor as well
(in this case, as an inline block):

```ruby
transport = Elastic::Transport::Transport::HTTP::Curb.new \
  hosts: [ { host: 'localhost', port: '9200' } ],
  & lambda { |c| c.verbose = true }

client = Elastic::Transport::Client.new transport: transport
```

You can write your own transport implementation easily, by including the
{Elastic::Transport::Transport::Base} module, implementing the required contract,
and passing it to the client as the `transport_class` parameter -- or injecting it directly.

### Serializer Implementations

By default, the [MultiJSON](http://rubygems.org/gems/multi_json) library is used as the
serializer implementation, and it will pick up the "right" adapter based on gems available.

The serialization component is pluggable, though, so you can write your own by including the
{Elastic::Transport::Transport::Serializer::Base} module, implementing the required contract,
and passing it to the client as the `serializer_class` or `serializer` parameter.

### Exception Handling

The library defines a [number of exception classes](https://github.com/elasticsearch/elasticsearch-ruby/blob/master/elasticsearch-transport/lib/elasticsearch/transport/transport/errors.rb)
for various client and server errors, as well as unsuccessful HTTP responses,
making it possible to `rescue` specific exceptions with desired granularity.

The highest-level exception is {Elastic::Transport::Transport::Error}
and will be raised for any generic client *or* server errors.

{Elastic::Transport::Transport::ServerError} will be raised for server errors only.

As an example for response-specific errors, a `404` response status will raise
an {Elastic::Transport::Transport::Errors::NotFound} exception.

Finally, {Elastic::Transport::Transport::SnifferTimeoutError} will be raised
when connection reloading ("sniffing") times out.

## Development and Community

For local development, clone the repository and run `bundle install`. See `rake -T` for a list of
available Rake tasks for running tests, generating documentation, starting a testing cluster, etc.

Bug fixes and features must be covered by unit tests.

Github's pull requests and issues are used to communicate, send bug reports and code contributions.

## The Architecture

* {Elastic::Transport::Client} is composed of {Elastic::Transport::Transport}

* {Elastic::Transport::Transport} is composed of {Elastic::Transport::Transport::Connections},
  and an instance of logger, tracer, serializer and sniffer.

* Logger and tracer can be any object conforming to Ruby logging interface,
  ie. an instance of [`Logger`](http://www.ruby-doc.org/stdlib-1.9.3/libdoc/logger/rdoc/Logger.html),
  [_log4r_](https://rubygems.org/gems/log4r), [_logging_](https://github.com/TwP/logging/), etc.

* The {Elastic::Transport::Transport::Serializer::Base} implementations handle converting data for Elasticsearch
  (eg. to JSON). You can implement your own serializer.

* {Elastic::Transport::Transport::Sniffer} allows to discover nodes in the cluster and use them as connections.

* {Elastic::Transport::Transport::Connections::Collection} is composed of
  {Elastic::Transport::Transport::Connections::Connection} instances and a selector instance.

* {Elastic::Transport::Transport::Connections::Connection} contains the connection attributes such as hostname and port,
  as well as the concrete persistent "session" connected to a specific node.

* The {Elastic::Transport::Transport::Connections::Selector::Base} implementations allow to choose connections
  from the pool, eg. in a round-robin or random fashion. You can implement your own selector strategy.

## Development

To run tests, launch a testing cluster and use the Rake tasks:

```bash
time rake test:unit
time rake test:integration
```

Use `COVERAGE=true` before running a test task to check coverage with Simplecov.

## License

This software is licensed under the [Apache 2 license](./LICENSE).
