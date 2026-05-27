defmodule IdcalWeb.Locale do
  @moduledoc """
  Locale handling for the bilingual site (en-US / pt-BR).

  Acts both as a plug (for controller requests) and an `on_mount` hook
  (for LiveViews), reading the chosen locale from the session and applying
  it to the Gettext backend.
  """

  import Plug.Conn, only: [get_session: 2, get_req_header: 2, assign: 3]

  @supported ~w(en pt)
  @default "en"

  @doc "List of supported locale codes."
  def supported, do: @supported

  @doc "Default/fallback locale code."
  def default, do: @default

  @doc "Returns the locale if supported, otherwise the default."
  def normalize(locale) when locale in @supported, do: locale
  def normalize(_), do: @default

  ## Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    locale =
      case get_session(conn, :locale) do
        nil -> conn |> detect_from_header() |> normalize()
        saved -> normalize(saved)
      end

    Gettext.put_locale(IdcalWeb.Gettext, locale)
    assign(conn, :locale, locale)
  end

  defp detect_from_header(conn) do
    case get_req_header(conn, "accept-language") do
      [header | _] -> parse_accept_language(header)
      [] -> nil
    end
  end

  defp parse_accept_language(header) do
    header
    |> String.split(",")
    |> Enum.find_value(fn segment ->
      lang = segment |> String.split(";") |> hd() |> String.trim() |> String.downcase()
      prefix = lang |> String.split("-") |> hd()
      if prefix in @supported, do: prefix
    end)
  end

  ## LiveView on_mount

  def on_mount(:default, _params, session, socket) do
    locale = session |> Map.get("locale") |> normalize()
    Gettext.put_locale(IdcalWeb.Gettext, locale)
    {:cont, Phoenix.Component.assign(socket, :locale, locale)}
  end
end
