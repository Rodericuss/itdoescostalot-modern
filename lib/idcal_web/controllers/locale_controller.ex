defmodule IdcalWeb.LocaleController do
  use IdcalWeb, :controller

  @doc """
  Sets the chosen locale in the session and redirects back to the
  page the user came from.
  """
  def update(conn, %{"locale" => locale}) do
    locale = IdcalWeb.Locale.normalize(locale)

    to =
      case conn |> get_req_header("referer") |> List.first() do
        ref when is_binary(ref) ->
          case URI.parse(ref).path do
            path when is_binary(path) -> path
            _ -> ~p"/"
          end

        _ ->
          ~p"/"
      end

    conn
    |> put_session(:locale, locale)
    |> redirect(to: to)
  end
end
