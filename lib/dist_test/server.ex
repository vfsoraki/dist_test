defmodule DistTest.Server do
  use GenServer
  require Logger

  def start_link(opts) do
    Logger.debug("Starting server")

    GenServer.start_link(__MODULE__, opts)
  end

  def add(name \\ __MODULE__, value) do
    GenServer.cast({:global, name}, {:add, value})
  end

  def init(_opts) do
    {:ok, %{started_at: NaiveDateTime.utc_now(), values: []}}
  end

  def handle_cast({:add, value}, %{values: values} = state) do
    {:noreply, %{state | values: [value | values]}}
  end

  def handle_info({:conflict, resolver_pid}, state) do
    resolution_data = Map.take(state, [:values, :started_at])
    send(resolver_pid, {:conflict_data, self(), resolution_data})

    Logger.debug(
      "Conflict resolution: sent #{inspect(resolution_data)} to #{inspect(resolver_pid)}"
    )

    {:noreply, state}
  end

  def handle_info({:conflict_resolution, :merge, new_values}, %{values: values} = state) do
    Logger.debug("Conflict resolution: updating state with #{new_values}")

    values =
      values
      |> Enum.concat(new_values)
      |> Enum.uniq()

    {:noreply, %{state | values: values}}
  end

  def handle_info({:conflict_resolution, :stop}, state) do
    Logger.debug("Conflict resolution: stopping")
    {:stop, :normal, state}
  end
end
