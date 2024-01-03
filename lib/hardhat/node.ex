defmodule Hardhat.Node do
  @moduledoc """
  A managed Hardhat node.
  """

  use GenServer

  @type t :: pid()

  ## Client

  @type option :: {:host, binary()} | {:port, 0..0xffff} | Hardhat.Node.Daemon.option()

  @spec start(Hardhat.Config.t(), [option()]) :: {:ok, pid()} | {:error, any()}
  def start(config, options \\ []) do
    # TODO(mtwilliams): Spawn under `Hardhat.Node.Supervisor`.
    GenServer.start(__MODULE__, {config, options})
  end

  @spec stop(t(), timeout()) :: :ok
  def stop(node, timeout \\ :infinity) do
    GenServer.stop(node, :normal, timeout)
  end

  @spec url(t()) :: String.t()
  def url(node) do
    GenServer.call(node, :url)
  end

  ## Server

  defmodule State do
    @type t :: %__MODULE__{
      host: String.t(),
      port: 0..0xffff,
      daemon: pid()
    }

    defstruct [
      :host,
      :port,
      :daemon
    ]
  end

  # TODO(mtwilliams): Embed Hardhat (and dependencies) in `priv/` so it can be
  # used without `package.json`.

  @impl true
  def init({config, options}) do
    case System.find_executable("npx") do
      npx when is_binary(npx) ->
        # Write configuration to an arbitrary file.
        #
        # This is the only way to *fully* configure Hardhat.
        path_to_config = Path.join([System.tmp_dir!(), generate_random_token(32) <> ".json"])
        File.write!(path_to_config, Poison.encode!(Hardhat.Config.dump(config), pretty: true, indent: 2), [:binary])

        # Parse options into those to pass to Hardhat and our daemon.
        {passthrough, arguments} = handle_node_options(options, [], [])
        arguments = ["hardhat", "--config", path_to_config, "node"] ++ arguments

        # Spawn the Hardhat node and monitor it.
        {:ok, daemon} = Hardhat.Node.Daemon.start(npx, arguments, passthrough)

        # Extract host and port so it can be queried.
        #
        # Defaults must match Hardhat.
        host = Keyword.get(options, :host, "127.0.0.1")
        port = Keyword.get(options, :port, "8545")

        {:ok, %State{host: host, port: port, daemon: daemon}}

      _ ->
        # Node isn't available on the path?
        {:stop, :unavailable}
    end
  end

  @spec generate_random_token(non_neg_integer()) :: String.t()
  defp generate_random_token(size) do
    :crypto.strong_rand_bytes(size)
    |> Base.encode16(case: :lower)
  end

  # Options to pass through to daemon.
  @passthrough [:env, :cd, :log]

  defp handle_node_options([{:host, host} | options], passthrough, arguments) do
    handle_node_options(options, passthrough, ["--hostname", host | arguments])
  end
  defp handle_node_options([{:port, port} | options], passthrough, arguments) when is_integer(port) and port >= 0 and port <= 0xffff do
    handle_node_options(options, passthrough, ["--port", Integer.to_string(port, 10) | arguments])
  end
  # defp handle_node_options([{:fork, url} | options], passthrough, arguments) when is_binary(url) do
  #   handle_node_options(options, passthrough, ["--fork", url] ++ arguments)
  # end
  # defp handle_node_options([{:fork, {url, block}} | options], passthrough, arguments)
  #   when is_binary(url) and is_integer(block) and block >= 0
  # do
  #   handle_node_options(options, passthrough, ["--fork", url, "--fork-block-number", Integer.to_string(block)] ++ arguments)
  # end
  defp handle_node_options([{option, value} | options], passthrough, arguments) when option in @passthrough do
    handle_node_options(options, [{option, value} | passthrough], arguments)
  end
  defp handle_node_options([], passthrough, arguments) do
    {passthrough, arguments}
  end

  @impl true
  def handle_call(:url, _, state) do
    {:reply, "http://#{state.host}:#{state.port}", state}
  end
end
