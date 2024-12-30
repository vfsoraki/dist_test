# DistTest

<a target="_blank" href="https://staging.mipasa.com/projects/import/git?repo=https%3A%2F%2Fgithub.com%2Fvfsoraki%2Fdist_test&branch=main&dir=test" style="background: #fff;padding: 0.1rem 0.5rem; border-radius: 0.5rem; display: inline-block">
        <img src="https://staging.mipasa.com/mipasa/open-in.svg" alt="Open In MiPasa"/>
</a>

A POC for handling singleton processes and resolving network splits.

Uses `:global` to resolve conflicts.

## Installation

It's a POC, clone it.

## Resolver

To handle singletons, you have to define a module using `DistTest.SingletonResolver`. This
will ensure there's only one instance of the singleton running in cluster, and also handles
resolving conflicts if they happen.

``` elixir
defmodule DistTest.Resolver do
  use DistTest.SingletonResolver
  
  @impl true
  def resolver(name, pid1, pid2) do
    # Use your own logic here
    # NOTE: You have to return one of the `pid1` or `pid2` as winner
  end
```

And to start it in your supervisor

``` elixir
chilren = [
  {DisTest.SingletonResolver, 
    name: DisTest.SomeName, 
    child_opts: [DisTest.Server, []]}
]
```

`name` is the name to register the `GenServer` under, and `child_opts` is the arguments
to pass to `GenServer.start_link` to start the process.

## Splits

When a split happens, the singleton will exist in all of partitions. When the split 
resolved, your `resolve/3` callback is called to determine what process should be killed
and what is kept.
