defmodule Hardhat do
  @moduledoc """
  Ingredients for working with [Hardhat][1] in Elixir.

  [1]: https://hardhat.org/
  """

  defmodule Application do
    @moduledoc false

    alias :"Elixir.Application"

    use Application

    @impl true
    def start(_type, _args) do
      children = [
        # Supervisor for Hardhat nodes managed by the VM.
        {DynamicSupervisor, name: Hardhat.Node.Supervisor}
      ]

      Supervisor.start_link(children, name: __MODULE__.Supervisor, strategy: :one_for_one)
    end
  end
end
