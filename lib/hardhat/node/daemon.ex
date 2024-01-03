defmodule Hardhat.Node.Daemon do
  @moduledoc """
  An external daemonized process.
  """

  require Logger

  use GenServer

  @type t :: pid()

  ## Client

  @type option :: {:cd, String.t()} | {:env, %{binary() => binary()}} | {:log, Logger.level() | :none}

  @spec start(String.t(), [String.t()], [option]) :: {:ok, t()} | {:error, any()}
  def start(path, arguments, options \\ []) do
    GenServer.start_link(__MODULE__, {path, arguments, options})
  end

  @spec stop(t(), timeout()) :: :ok
  def stop(daemon, timeout \\ :infinity) do
    GenServer.stop(daemon, :normal, timeout)
  end

  ## Server

  # TODO(mtwilliams): Log lifecycle of daemon.
  # TODO(mtwilliams): Replace this with Porcelain/Muontrap?

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
      port: port(),
      ref: reference(),
      pid: non_neg_integer(),
      exited: boolean(),
      status: non_neg_integer() | nil,
      log: Logger.level() | :none
    }

    defstruct [
      :port,
      :ref,
      :pid,
      :exited,
      :status,
      :log
    ]
  end

  # Script that prevents a zombie process.
  #
  # https://hexdocs.pm/elixir/1.14/Port.html#module-zombie-operating-system-processes
  @shim Application.app_dir(:hardhat, ["priv", "exit-on-close.sh"])

  # Buffer size for lines.
  @line_length_limit 8_192

  # Base settings for port.
  @base [:use_stdio, :stderr_to_stdout, :binary, {:line, @line_length_limit}, :hide, :exit_status]

  @impl true
  def init({path, arguments, options}) do
    Process.flag(:trap_exit, true)

    # Execute through a shim to prevent zombies.
    port = Port.open({:spawn_executable, @shim}, [{:args, [path | arguments]} | handle_port_options(options, @base)])
    ref = Port.monitor(port)
    {:os_pid, pid} = Port.info(port, :os_pid)

    # Store log level for forwarding logs from the process.
    log = Keyword.get(options, :log, :debug)

    {:ok, %State{port: port, ref: ref, pid: pid, exited: false, log: log}}
  end

  defp handle_port_options([{:cd, path} | options], acc) when is_binary(path) do
    handle_port_options(options, [{:cd, path} | acc])
  end
  defp handle_port_options([{:env, env} | options], acc) when is_map(env) do
    handle_port_options(options, [{:env, handle_port_env(env, [])} | acc])
  end
  defp handle_port_options([], acc) do
    acc
  end

  defp handle_port_env([{var, val} | env], acc) when is_binary(var) and is_binary(val) do
    handle_port_env(env, [{:erlang.binary_to_list(var), :erlang.binary_to_list(val)} | acc])
  end
  defp handle_port_env([], acc) do
    acc
  end

  @impl true
  def terminate(_reason, state) do
    # Ensure the process managed by the port is terminted, to prevent orphaning
    # the process and leaving a zombie.
    unless state.exited do
      Port.close(state.port)
    end

    :ok
  end

  @impl true
  def handle_info({port, {:data, {_eol, <<>>}}}, %State{port: port} = state) do
    # Ignore empty lines.
    {:noreply, state}
  end
  def handle_info({port, {:data, {_eol, line}}}, %State{port: port, log: :none} = state) do
    # Do not log.
    {:noreply, state}
  end
  def handle_info({port, {:data, {_eol, line}}}, %State{port: port, log: level} = state) do
    Logger.log(level, line, [port: state.port, pid: state.pid])
    {:noreply, state}
  end
  def handle_info({port, {:exit_status, status}}, %State{port: port} = state) do
    {:noreply, %State{state | exited: true, status: status}}
  end
  def handle_info({:DOWN, _ref, :port, _port, :normal}, state) do
    {:stop, :normal, state}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end
end
