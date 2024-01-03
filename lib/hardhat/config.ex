defmodule Hardhat.Config do
  @moduledoc """
  Configuration for [Hardhat][1].

  [1]: https://hardhat.org/hardhat-runner/docs/config#hardhat-network
  """

  @type t :: %__MODULE__{
    ## Paths

    # The root of the Hardhat project.
    root: Path.t() | String.t(),

    # Directory under which contracts are stored.
    sources: Path.t() | String.t(),

    # Directory under which tests are stored.
    tests: Path.t() | String.t(),

    # Directory under which Hardhat caches internals.
    cache: Path.t() | String.t(),

    # Directory under which artifacts are stored.
    artifacts: Path.t() | String.t(),

    ## Solidty

    solidity: Solidity.t(),

    ## Networks

    networks: %{atom() => Network.t()}
  }

  defstruct [
    :root,
    :sources,
    :tests,
    :cache,
    :artifacts,
    :solidity,
    :networks
  ]

  defmodule Solidity do
    @moduledoc """
    Configuration for Solidity compiler used by Hardhat.
    """

    @type t :: %__MODULE__{
      version: Version.version(),
      settings: map()
    }

    defstruct [
      :version,
      :settings
    ]
  end

  defmodule Network do
    @type t :: %__MODULE__{
      # Specifies another network to fork.
      #
      # If specified, Hardhat will fork from another network by bootstrapping
      # from another node over JSON-RPC.
      fork: Fork.t() | nil,

      # Controls whether or not the node automatically mines blocks.
      #
      # If specified, Hardhat will automatically mine blocks with the
      # specified delay between blocks in milliseconds. A range can be
      # specified, in which case Hardhat will mine with a random delay in the
      # range.
      automine: non_neg_integer() | {min :: non_neg_integer(), max :: non_neg_integer()} | nil,

      # Controls how to sort transactions for inclusion in blocks.
      #
      # https://hardhat.org/hardhat-network/docs/reference#transaction-ordering
      order: :priority | :fifo
    }

    defstruct [
      :fork,
      :automine,
      :order
    ]

    defmodule Fork do
      @type t :: %__MODULE__{
        # JSON-RPC node to bootstrap and fork.
        url: URI.t() | String.t(),

        # Block from which to fork.
        block: non_neg_integer() | nil
      }

      defstruct [
        :url,
        :block
      ]
    end
  end

  @doc """
  Generates a reasonable default configuration for the specified application.
  """
  @spec default(atom()) :: t()
  def default(app) do
    %__MODULE__{
      root: Application.app_dir(app, ["priv", "hardhat"]),
      sources: Application.app_dir(app, ["priv", "hardhat", "sources"]),
      tests: Application.app_dir(app, ["priv", "hardhat", "tests"]),
      cache: Application.app_dir(app, ["priv", "hardhat", "cache"]),
      artifacts: Application.app_dir(app, ["priv", "hardhat", "artifacts"]),
      solidity: %Solidity{version: "0.8.23", settings: %{}},
      networks: %{hardhat: %Network{automine: 1_000, order: :priority}}
    }
  end

  @doc """
  Translates to configuration that can be passed to Hardhat.
  """
  @spec dump(t()) :: binary()
  def dump(%__MODULE__{} = config) do
    %{
      "paths" => %{
        "root" => config.root,
        "sources" => config.sources,
        "tests" => config.tests,
        "cache" => config.cache,
        "artifacts" => config.artifacts
      },

      "solidity" => %{
        "version" => config.solidity.version,
        "setttings" => config.solidity.settings
      },

      "networks" => Map.new(config.networks, fn {name, network} ->
        {Atom.to_string(name), do_dump_network(network)}
      end)
    }
  end

  defp do_dump_network(%Hardhat.Config.Network{} = network) do
    %{
      "mining" => %{
        "auto" => not is_nil(network.automine),
        "interval" => do_dump_interval(network.automine),
        "mempool" => %{
          "order" => Atom.to_string(network.order)
        }
      }
    }
    |> maybe_with_fork(network.fork)
  end

  defp maybe_with_fork(config, fork) do
    if fork do
      Map.put(config, "forking", do_dump_fork(fork))
    else
      config
    end
  end

  defp do_dump_fork(%Hardhat.Config.Network.Fork{} = fork) do
    %{
      "url" => to_string(fork.url),
      "block" => fork.block
    }
  end

  defp do_dump_interval({min, max}), do: [min, max]
  defp do_dump_interval(constant), do: constant
end
