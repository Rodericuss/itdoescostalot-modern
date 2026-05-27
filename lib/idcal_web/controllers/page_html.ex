defmodule IdcalWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use IdcalWeb, :html

  import IdcalWeb.FormatHelpers, only: [format_amount: 1, month_name: 1]

  embed_templates "page_html/*"
end
