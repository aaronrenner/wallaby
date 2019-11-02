defmodule Wallaby.FeatureTestTest do
  use ExUnit.Case, async: true
  use Wallaby.DSL

  import ExUnit.CaptureIO

  @moduletag :ex_unit

  test "feature macro works" do
    defmodule SimpleTest do
      use ExUnit.Case
      import Wallaby.FeatureTest

      feature "successful" do
        assert "foo" == "foo"
      end
    end

    ExUnit.Server.modules_loaded()
    configure_and_reload_on_exit(colors: [enabled: false])

    assert capture_io(fn ->
             assert ExUnit.run() == %{failures: 0, skipped: 0, total: 1, excluded: 0}
           end) =~ "\n1 feature, 0 failures\n"
  end

  test "feature takes a screenshot on failure for each open wallaby session" do
    defmodule FailureWithMultipleSessionsTest do
      use ExUnit.Case
      import Wallaby.FeatureTest

      test "fails" do
        {:ok, _} = Wallaby.start_session()
        {:ok, _} = Wallaby.start_session()

        assert false
      end
    end

    ExUnit.Server.modules_loaded()
    configure_and_reload_on_exit(colors: [enabled: false])

    output =
      capture_io(fn ->
        assert ExUnit.run() == %{failures: 1, skipped: 0, total: 1, excluded: 0}
      end)

    assert output =~ "\n1 feature, 1 failure\n"
    assert screenshot_taken_count(output) == 2
  end

  test "feature does not take a screenshot when test passes" do
    defmodule PassWithOpenSessionTest do
      use ExUnit.Case
      import Wallaby.FeatureTest

      feature "passes" do
        {:ok, _} = Wallaby.start_session()

        assert true
      end
    end

    ExUnit.Server.modules_loaded()
    configure_and_reload_on_exit(colors: [enabled: false])

    output =
      capture_io(fn ->
        assert ExUnit.run() == %{failures: 0, skipped: 0, total: 1, excluded: 0}
      end)

    assert output =~ "\n1 feature, 0 failures\n"
    assert screenshot_taken_count(output) == 0
  end

  test "feature takes a screenshot with a rescue block" do
    defmodule RescueBlockFailureTest do
      use ExUnit.Case
      import Wallaby.FeatureTest

      feature "successful" do
        Wallaby.start_session()
        raise "foo"
      rescue
        _error ->
          raise "another error"
      end
    end

    ExUnit.Server.modules_loaded()
    configure_and_reload_on_exit(colors: [enabled: false])

    output =
      capture_io(fn ->
        assert ExUnit.run() == %{failures: 1, skipped: 0, total: 1, excluded: 0}
      end)

    assert output =~ "\n1 feature, 1 failure\n"
    assert screenshot_taken_count(output) == 1
  end

  defp configure_and_reload_on_exit(opts) do
    old_opts = ExUnit.configuration()
    ExUnit.configure(opts)

    on_exit(fn -> ExUnit.configure(old_opts) end)
  end

  defp screenshot_taken_count(output) do
    ~r/(Screenshot taken)/
    |> Regex.scan(output)
    |> length()
  end
end
