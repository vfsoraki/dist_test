defmodule DistTest.SingletonResolver do
  @callback resolve(name :: term(), pid1 :: pid(), pid2 :: pid()) :: pid()

  defmacro __using__(_opts) do
    mod = __MODULE__

    quote do
      @behaviour unquote(mod)
      use GenServer
      require Logger

      def start_link(opts) do
        name = Keyword.fetch!(opts, :name)
        child_opts = Keyword.fetch!(opts, :child_opts)

        case :global.whereis_name(name) do
          rpid when is_pid(rpid) ->
            # It's already registed. Monitor node and process
            rnode = node(rpid)

            opts =
              opts
              |> Keyword.put(:process, rpid)
              |> Keyword.put(:node, rnode)

            GenServer.start_link(__MODULE__, opts)

          :undefined ->
            # Start the worker
            {:ok, lpid} = apply(GenServer, :start_link, child_opts)

            # Try to register name
            case :global.register_name(name, lpid, &__MODULE__.resolve/3) do
              :yes ->
                # We don't need to do anything, let supervisor supervise process
                {:ok, lpid}

              :no ->
                # Someone else registered it, kill our process and monitor that
                case :global.whereis_name(name) do
                  rpid when is_pid(rpid) ->
                    rnode = node(rpid)

                    opts =
                      opts
                      |> Keyword.put(:process, rpid)
                      |> Keyword.put(:node, rnode)

                    GenServer.start_link(__MODULE__, opts)

                  :undefined ->
                    # This is too much and shouldn't happen
                    # But let the supervisor handle this
                    {:error, {:register_failed, name}}
                end
            end
        end
      end

      @impl true
      def init(opts) do
        pid = Keyword.get(opts, :process)
        node = Keyword.get(opts, :node)

        pid_ref = if pid, do: Process.monitor(pid)
        if node, do: true = Node.monitor(node, true)

        {:ok, %{pid: pid, node: node, pid_ref: pid_ref}}
      end

      @impl true
      def handle_info({:DOWN, ref, :process, pid, reason}, %{pid: pid, pid_ref: ref} = state) do
        Logger.info(fn -> "Process #{inspect(pid)} is down (#{inspect(reason)})" end)
        {:stop, :normal, state}
      end

      def handle_info({nodedown, node}, %{node: node} = state) do
        Logger.info(fn -> "Node #{inspect(node)} is down" end)
        {:stop, :normal, state}
      end
    end
  end
end
