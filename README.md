Pulse
=====

[![hex.pm version](https://img.shields.io/hexpm/v/pulse.svg?style=flat)](https://hex.pm/packages/pulse)

Service registration and discovery library for Elixir. Relies on [etcd](https://coreos.com/etcd/) as an external service registry.

Works best with FQDN node names, such as `my_node@ip-123-234-124-235.local`.

### Installation

The latest version is `0.1.0` and requires Elixir `~> 1.2`. New releases may change this minimum compatible version depending on breaking language changes. The [changelog](https://github.com/heroiclabs/pulse/blob/master/CHANGELOG.md) lists every available release and its corresponding language version requirement.

Releases are published through [hex.pm](https://hex.pm/packages/pulse). Add as a dependency in your `mix.exs` file:
```elixir
defp deps do
  [ { :pulse, "~> 0.1" } ]
end
```

Also ensure it's listed in the `mix.exs` list of applications to start:
```elixir
def application do
  [
    applications: [:pulse]
  ]
end
```

### Configuration

Below is the complete default configuration. All parameters can be changed.

```elixir
config :pulse,
  directory: "pulse"
```

For `etcd` connection configuration, see [Sonic](https://github.com/heroiclabs/sonic).

### Usage

There are three discrete functions handled by Pulse:

* Service Registration - Publishing service status so it is discoverable by other nodes.
* Service Discovery - Retrieving a list of available nodes registered to provide a service.
* Service Directory - Maintaining the internal service registry and handling connections to discovered nodes.

For the examples below, we'll assume a typical `Application` module with a start function:

```elixir
def start(_type, _args) do
import Supervisor.Spec, warn: false

children = [
  worker(MyApp.SomeWorker, [])
]

opts = [strategy: :one_for_one, name: MyApp.Supervisor]
Supervisor.start_link(children, opts)
end
```

#### Service Registration

`Pulse.Register` is responsible for service registration. To use it, declare it as a worker in your application's supervision tree.

The module takes 4 parameters in a keyword list, for legibility:

* `service` - A binary indicating the service name to register.
* `ttl` - An integer indicating the number of seconds the registration should live unless refreshed.
* `heartbeat` - An integer indicating the number of seconds to wait between registration refreshes.
* `delay` - An integer indicating the number of seconds to wait before first registration.

```elixir
children = [
  worker(Pulse.Register, [[service: "my_service", ttl: 15, heartbeat: 5, delay: 5]])
]
```

Each `Pulse.Register` worker is only responsible for one service, but you can register the application as providing multiple services by declaring more than one worker.

```elixir
children = [
  worker(Pulse.Register, [[service: "my_service", ttl: 15, heartbeat: 5, delay: 5]], id: MyApp.MyServiceRegister),
  worker(Pulse.Register, [[service: "my_other_service", ttl: 15, heartbeat: 5, delay: 5]], id: MyApp.MyOthereSrviceRegister)
  # ...
]
```

The configuration options should be tuned for your application, however the values shown above are a good baseline.

#### Service Discovery

Start one or more `Pulse.Discover` workers to look up registered nodes for required services.

The module taks 3 parameters in a keyword list, for legibility:

* `service` - A binary indicating the service name to discover.
* `poll` - An integer indicating the number of seconds to wait between discovery refreshes.
* `delay` - An integer indicating the number of seconds to wait before first discovery.

```elixir
children = [
  worker(Pulse.Discover, [[service: "my_service", poll: 5, delay: 1]])
]
```

Each `Pulse.Discover` worker is only responsible for one service, but you can discover multiple services by declaring more than one worker.

```elixir
children = [
  worker(Pulse.Discover, [[service: "my_service", poll: 5, delay: 1]], id: MyApp.MyServiceDiscover),
  worker(Pulse.Discover, [[service: "my_other_service", poll: 5, delay: 1]], id: MyApp.MyOtherServiceDiscover)
  # ...
]
```

The configuration options should be tuned for your application, however the values shown above are a good baseline.

#### Service Directory

The `Pulse.Directory` module maintains connections and tracks available nodes registered for each discovered service. This module is monitored by Pulse internally, you do not need to start a worker to use it.

`Pulse.Directory.get/1` is the primary way to retrieve available nodes for any given discovered service.

```elixir
iex> Pulse.Directory.get("my_service")
[:"my_machine1@ip-123-234-124-235.local", :"my_machine2@ip-123-234-124-235.local"]
```

These nodes will already be connected by the `Pulse.Directory` process and are valid RPC targets if necessary. The directory also monitors connections and will unregister nodes from service lists if they disconnect.

### License

```none
Copyright 2016 Heroic Labs

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
