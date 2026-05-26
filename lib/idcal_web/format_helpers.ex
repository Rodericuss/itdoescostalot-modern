defmodule IdcalWeb.FormatHelpers do
  use Gettext, backend: IdcalWeb.Gettext

  @month_abbr_en ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  @month_abbr_pt ~w(Jan Fev Mar Abr Mai Jun Jul Ago Set Out Nov Dez)

  def month_name(1), do: gettext("January")
  def month_name(2), do: gettext("February")
  def month_name(3), do: gettext("March")
  def month_name(4), do: gettext("April")
  def month_name(5), do: gettext("May")
  def month_name(6), do: gettext("June")
  def month_name(7), do: gettext("July")
  def month_name(8), do: gettext("August")
  def month_name(9), do: gettext("September")
  def month_name(10), do: gettext("October")
  def month_name(11), do: gettext("November")
  def month_name(12), do: gettext("December")

  def month_abbr(m) when m in 1..12 do
    case Gettext.get_locale(IdcalWeb.Gettext) do
      "pt" -> Enum.at(@month_abbr_pt, m - 1)
      _ -> Enum.at(@month_abbr_en, m - 1)
    end
  end

  def format_amount(decimal) do
    decimal |> Decimal.round(2) |> Decimal.to_string(:normal) |> localize_number()
  end

  def format_short(decimal) do
    decimal |> Decimal.round(0) |> Decimal.to_string(:normal) |> localize_number()
  end

  defp localize_number(str) do
    case Gettext.get_locale(IdcalWeb.Gettext) do
      "pt" -> String.replace(str, ".", ",")
      _ -> str
    end
  end
end
