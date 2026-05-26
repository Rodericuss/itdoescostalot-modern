defmodule IdcalWeb.QuickEntryLive.Index do
  use IdcalWeb, :live_view

  alias Idcal.Finances

  @impl true
  def mount(%{"id" => profile_id}, _session, socket) do
    profile = Finances.get_profile!(socket.assigns.current_scope, profile_id)
    today = Date.utc_today()

    {:ok,
     socket
     |> assign(:page_title, gettext("Quick Entry"))
     |> assign(:profile, profile)
     |> assign(:category, "")
     |> assign(:type, "")
     |> assign(:amount, "")
     |> assign(:note, "")
     |> assign(:year, today.year)
     |> assign(:month, today.month)}
  end

  @impl true
  def handle_event("save", params, socket) do
    profile = socket.assigns.profile

    case Finances.quick_expense_entry(
      profile,
      String.trim(params["category"]),
      String.trim(params["type"]),
      params["amount"],
      String.to_integer(params["year"]),
      String.to_integer(params["month"]),
      if(params["note"] != "", do: params["note"])
    ) do
      {:ok, _entry} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Entry recorded!"))
         |> assign(:type, "")
         |> assign(:amount, "")
         |> assign(:note, "")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to record entry."))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <.link navigate={~p"/profiles/#{@profile}"} class="text-muted hover:text-gold font-cinzel text-sm">
          &larr; {@profile.nickname}
        </.link>
        <h1 class="font-cinzel-decorative font-bold text-2xl text-gold mt-1">⚡ {gettext("Quick Entry")}</h1>
        <p class="italic-fell text-muted text-sm mb-4">{gettext("Log a sporadic expense fast.")}</p>

        <form phx-submit="save" class="panel p-5 space-y-4">
          <div>
            <label class="font-cinzel text-sm text-gold">{gettext("Guild")}</label>
            <input type="text" name="category" value={@category} class="input-medieval w-full mt-1 text-sm" required placeholder={gettext("e.g. Leisure")} />
          </div>
          <div>
            <label class="font-cinzel text-sm text-gold">{gettext("Levy")}</label>
            <input type="text" name="type" value={@type} class="input-medieval w-full mt-1 text-sm" required placeholder={gettext("e.g. Tavern Bill")} />
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="font-cinzel text-sm text-gold">{gettext("Amount")}</label>
              <input type="number" name="amount" value={@amount} step="0.01" min="0.01" class="input-medieval w-full mt-1 text-sm" required />
            </div>
            <div class="grid grid-cols-2 gap-2">
              <div>
                <label class="text-muted text-xs">{gettext("Year")}</label>
                <input type="number" name="year" value={@year} min="1970" max="9999" class="input-medieval w-full mt-1 text-sm" required />
              </div>
              <div>
                <label class="text-muted text-xs">{gettext("Month")}</label>
                <input type="number" name="month" value={@month} min="1" max="12" class="input-medieval w-full mt-1 text-sm" required />
              </div>
            </div>
          </div>
          <div>
            <label class="font-cinzel text-sm text-gold">{gettext("Note")}</label>
            <input type="text" name="note" value={@note} class="input-medieval w-full mt-1 text-sm" placeholder={gettext("Optional note...")} />
          </div>
          <button type="submit" class="btn-medieval w-full">⚡ {gettext("Record")}</button>
        </form>
      </div>
    </Layouts.app>
    """
  end
end
