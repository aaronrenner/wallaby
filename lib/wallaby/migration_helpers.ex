defmodule Wallaby.MigrationHelpers do
  @moduledoc false

  alias Wallaby.Element
  alias Wallaby.Session
  alias WebDriverClient.Config, as: WDCConfig

  @spec build_web_driver_client_session(Session.t() | Element.t()) :: WebDriverClient.Session.t()
  def build_web_driver_client_session(%{session_url: session_url}) do
    %URI{path: path} = uri = URI.parse(session_url)

    {base_path_segments, ["session", session_id]} =
      path
      |> Path.split()
      |> Enum.split(-2)

    base_path = Path.join(base_path_segments)

    base_url = uri |> URI.merge(base_path) |> URI.to_string()

    config = WDCConfig.build(base_url: base_url, protocol: :jwp, debug: false)
    WebDriverClient.Session.build(session_id, config)
  end

  @spec to_legacy_log_entry(WebDriverClient.LogEntry.t()) :: map()
  def to_legacy_log_entry(%WebDriverClient.LogEntry{
        level: level,
        message: message,
        source: source
      }) do
    %{"level" => level, "message" => message, "source" => source}
  end
end
