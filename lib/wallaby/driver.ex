defmodule Wallaby.Driver do
  @moduledoc false

  alias Wallaby.{Element, Query, Session}

  @type reason :: :not_implemented | :not_supported | any
  @type url :: String.t
  @type open_dialog_fn :: ((Session.t) -> any)
  @type window_dimension :: %{String.t => pos_integer, String.t => pos_integer}

  @type on_start_session :: {:ok, Session.t} | {:error, reason}

  @doc """
  Invoked to start a browser session.
  """
  @callback start_session(Keyword.t) :: on_start_session

  @doc """
  Invoked to stop a browser sesssion.
  """
  @callback end_session(Session.t) :: :ok | {:error, reason}

  @doc """
  Invoked to accept one alert triggered within `open_dialog_fn` and return the alert message.
  """
  @callback accept_alert(Session.t, open_dialog_fn) :: {:ok, [String.t]} | {:error, reason}

  @doc """
  Invoked to accept one confirm triggered within `open_dialog_fn` and return the confirm message.
  """
  @callback accept_confirm(Session.t, open_dialog_fn) :: {:ok, [String.t]} | {:error, reason}

  @doc """
  Invoked to accept all open dialogs.
  """
  @callback accept_dialogs(Session.t) :: {:ok, String.t} | {:error, reason}

  @doc """
  Invoked to accept one prompt triggered within `open_dialog_fn` and return the prompt message.
  """
  @callback accept_prompt(Session.t, String.t | nil, open_dialog_fn) :: {:ok, [String.t]} | {:error, reason}

  @doc """
  Invoked to retrieve cookies for the given session.
  """
  @callback cookies(Session.t) :: {:ok, [%{String.t => String.t}]} | {:error, reason}

  @doc """
  Invoked to get the current path of the browser's session.
  """
  @callback current_path!(Session.t) :: String.t | nil | no_return

  @doc """
  Invoked to get the current url of the browser's session.
  """
  @callback current_url!(Session.t) :: String.t | nil | no_return

  @doc """
  Invoked to dismiss all open dialogs.
  """
  @callback dismiss_dialogs(Session.t) :: {:ok, String.t} | {:error, reason}

  @doc """
  Invoked to dismiss one confirm triggered within `open_dialog_fn` and return the confirm message.
  """
  @callback dismiss_confirm(Session.t, open_dialog_fn) :: {:ok, [String.t]} | {:error, reason}

  @doc """
  Invoked to dismiss one prompt triggered within `open_dialog_fn` and return the prompt message.
  """
  @callback dismiss_prompt(Session.t, open_dialog_fn) :: {:ok, [String.t]} | {:error, reason}

  @doc """
  Invoked to retrieve the size of the window.
  """
  @callback get_window_size(Session.t) :: {:ok, window_dimension} | {:error, reason}

  @doc """
  Invoked to retrieve the html source of the current page.
  """
  @callback page_source(Session.t) :: {:ok, String.t} | {:error, reason}

  @doc """
  Invoked to retrieve the title of the current page.
  """
  @callback page_title(Session.t) :: {:ok, String.t} | {:error, reason}

  @doc """
  Invoked to set a cookie on a session
  """
  @callback set_cookies(Session.t, String.t, String.t) :: {:ok, any} | {:error, reason}

  @doc """
  Invoked to set the size of the window.
  """
  @callback set_window_size(Session.t, pos_integer, pos_integer) :: {:ok, any} | {:error, reason}

  @doc """
  Invoked to visit a url.
  """
  @callback visit(Session.t, url) :: :ok | {:error, reason}

  @doc """
  Invoked to return the value of an element's attribute.
  """
  @callback attribute(Element.t, String.t) :: {:ok, String.t | nil} |
    {:error, reason}

  @doc """
  Invoked to clear an element.
  """
  @callback clear(Element.t) :: {:ok, any} | {:error, reason}

  @doc """
  Invoked to click on an element.
  """
  @callback click(Element.t) :: {:ok, any} | {:error, reason}

  @doc """
  Invoked to check if an element is currently visible.
  """
  @callback displayed(Element.t) :: {:ok, boolean} | {:error, reason}

  @doc """
  Invoked to check if an element is selected (like a checkbox).
  """
  @callback selected(Element.t) :: {:ok, boolean} | {:error, reason}

  @doc """
  Invoked to set the value of the given element.
  """
  @callback set_value(Element.t, any) :: {:ok, any} | {:error, reason}

  @doc """
  Invoked to return the text from the element.
  """
  @callback text(Element.t) :: {:ok, any} | {:error, reason}

  @doc """
  Invoked to find child elements of the given session/element.
  """
  @callback find_elements(Session.t | Element.t, Query.compiled) ::
    {:ok, [Element.t]} | {:error, reason}

  @doc """
  Invoked to execute javascript in the browser.
  """
  @callback execute_script(Session.t | Element, String.t, [any]) ::
    {:ok, any} | {:error, reason}

  @doc """
  Invoked to send keys to the browser.
  """
  @callback send_keys(Session.t | Element.t, String.t | [String.t | atom]) :: {:ok, any} | {:error, reason}

  @doc """
  Invoked to take a screenshot of the session/element.
  """
  @callback take_screenshot(Session.t | Element.t) :: binary | {:error, reason}
end
