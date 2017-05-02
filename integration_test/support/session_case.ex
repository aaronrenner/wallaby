defmodule Wallaby.Integration.SessionCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.DSL
      import Wallaby.Integration.SessionCase
    end
  end

  setup :inject_test_session

  @doc """
  Starts a test session with the default opts for the given driver
  """
  def start_test_session(opts \\ []) do
    session_opts =
      System.get_env("WALLABY_DRIVER")
      |> default_opts_for_driver
      |> Keyword.merge(opts)

    with {:ok, session} <- Wallaby.start_session(session_opts),
        :ok <- on_exit(fn -> Wallaby.end_session(session) end),
        do: {:ok, session}
  end

  @doc """
  Injects a test session into the test context
  """
  def inject_test_session(%{skip_test_session: true}), do: :ok
  def inject_test_session(_context) do
    {:ok, session} = start_test_session()

    {:ok, %{session: session}}
  end

  defp default_opts_for_driver("phantom"), do: []
  defp default_opts_for_driver(other) do
    raise "Unknown value for WALLABY_DRIVER environment variable: #{other}"
  end
end
