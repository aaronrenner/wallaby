defmodule Wallaby.FeatureTest do
  alias Wallaby.Browser

  defmacro feature(message, context \\ quote(do: _), contents) do
    contents =
      case contents do
        [do: block] ->
          quote do
            unquote(block)
            :ok
          end

        _ ->
          quote do
            try(unquote(contents))
            :ok
          end
      end

    context = Macro.escape(context)

    contents =
      quote do
        try do
          unquote(contents)
        rescue
          error ->
            unquote(__MODULE__).take_screenshots_for_open_sessions(self())
            reraise error, __STACKTRACE__
        after
          :ok
        end
      end

    contents = Macro.escape(contents, unquote: true)

    quote bind_quoted: [context: context, contents: contents, message: message] do
      name = ExUnit.Case.register_test(__ENV__, :feature, message, [:feature])
      def unquote(name)(unquote(context)), do: unquote(contents)
    end
  end

  def take_screenshots_for_open_sessions(pid) do
    pid
    |> Wallaby.SessionStore.get_registered_sessions()
    |> Enum.each(&Browser.take_screenshot(&1, log: true))
  end
end
