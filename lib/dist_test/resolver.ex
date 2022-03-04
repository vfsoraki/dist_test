defmodule DistTest.Resolver do
  use DistTest.SingletonResolver
  require Logger

  @impl true
  @spec resolve(term(), pid(), pid()) :: pid()
  def resolve(name, pid1, pid2) do
    Logger.debug(
      "Resolving conflict of #{name} from #{inspect(self())} for #{inspect(pid1)} and #{inspect(pid2)}"
    )

    send(pid1, {:conflict, self()})
    send(pid2, {:conflict, self()})

    conflict_data =
      Enum.reduce([pid1, pid2], %{values: [], started_ats: []}, fn pid, acc ->
        Logger.debug("Waiting for data ")

        receive do
          {:conflict_data, ^pid, %{started_at: started_at, values: values}} ->
            Logger.debug("Data from #{inspect(pid)} -> #{started_at}, #{values}")

            acc
            |> Map.update(:started_ats, [{pid, started_at}], fn d -> [{pid, started_at} | d] end)
            |> Map.update(:values, [{pid, values}], fn d -> [{pid, values} | d] end)
        after
          5_000 ->
            raise """
            Pid #{inspect(pid)} did not send a message in a timely manner.
            """
        end
      end)

    # Keep oldest pid
    [{keep_pid, _}, {kill_pid, _}] =
      conflict_data
      |> Map.get(:started_ats)
      |> Enum.sort(fn {_, ndt1}, {_, ndt2} ->
        NaiveDateTime.compare(ndt1, ndt2) in [:lt, :eq]
      end)

    {_, new_values} = Enum.find(conflict_data.values, fn {pid, _values} -> pid == kill_pid end)
    Logger.debug("New data -> #{new_values}")

    Logger.debug("Keeping #{inspect(keep_pid)} and killing #{inspect(kill_pid)}")

    send(keep_pid, {:conflict_resolution, :merge, new_values})
    send(kill_pid, {:conflict_resolution, :stop})

    Logger.debug("Done")

    keep_pid
  end
end
