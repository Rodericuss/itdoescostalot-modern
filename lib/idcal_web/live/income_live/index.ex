defmodule IdcalWeb.IncomeLive.Index do
  use IdcalWeb, :live_view

  alias Idcal.Finances
  alias Idcal.Finances.{IncomeCategory, IncomeSource, IncomeEntry}

  @impl true
  def mount(%{"id" => profile_id}, _session, socket) do
    profile = Finances.get_profile!(socket.assigns.current_scope, profile_id)
    categories = Finances.list_income_categories(profile)

    {:ok,
     socket
     |> assign(:page_title, gettext("Coffers"))
     |> assign(:profile, profile)
     |> assign(:categories, categories)
     |> assign(:category_form, nil)
     |> assign(:editing_category, nil)
     |> assign(:source_form, nil)
     |> assign(:source_category_id, nil)
     |> assign(:editing_source, nil)
     |> assign(:entry_form, nil)
     |> assign(:entry_source, nil)
     |> assign(:editing_entry, nil)}
  end

  @impl true
  def handle_event("new_category", _params, socket) do
    changeset = Finances.change_income_category(%IncomeCategory{})
    {:noreply, assign(socket, :category_form, to_form(changeset))}
  end

  def handle_event("cancel_category", _params, socket) do
    {:noreply, assign(socket, category_form: nil, editing_category: nil)}
  end

  def handle_event("save_category", %{"income_category" => params}, socket) do
    profile = socket.assigns.profile

    result =
      if socket.assigns.editing_category do
        Finances.update_income_category(socket.assigns.editing_category, params)
      else
        Finances.create_income_category(profile, params)
      end

    case result do
      {:ok, _category} ->
        {:noreply,
         socket
         |> assign(:categories, Finances.list_income_categories(profile))
         |> assign(:category_form, nil)
         |> assign(:editing_category, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :category_form, to_form(changeset))}
    end
  end

  def handle_event("edit_category", %{"id" => id}, socket) do
    category = Finances.get_income_category!(socket.assigns.profile, id)
    changeset = Finances.change_income_category(category)

    {:noreply,
     socket
     |> assign(:editing_category, category)
     |> assign(:category_form, to_form(changeset))}
  end

  def handle_event("delete_category", %{"id" => id}, socket) do
    category = Finances.get_income_category!(socket.assigns.profile, id)
    {:ok, _} = Finances.delete_income_category(category)

    {:noreply,
     socket
     |> assign(:categories, Finances.list_income_categories(socket.assigns.profile))
     |> put_flash(:info, gettext("Guild disbanded."))}
  end

  def handle_event("new_source", %{"category-id" => category_id}, socket) do
    changeset = Finances.change_income_source(%IncomeSource{income_category_id: category_id})

    {:noreply,
     socket
     |> assign(:source_form, to_form(changeset))
     |> assign(:source_category_id, category_id)}
  end

  def handle_event("cancel_source", _params, socket) do
    {:noreply, assign(socket, source_form: nil, source_category_id: nil, editing_source: nil)}
  end

  def handle_event("save_source", %{"income_source" => params}, socket) do
    profile = socket.assigns.profile

    result =
      if socket.assigns.editing_source do
        Finances.update_income_source(socket.assigns.editing_source, params)
      else
        Finances.create_income_source(profile, params)
      end

    case result do
      {:ok, _source} ->
        {:noreply,
         socket
         |> assign(:categories, Finances.list_income_categories(profile))
         |> assign(:source_form, nil)
         |> assign(:source_category_id, nil)
         |> assign(:editing_source, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :source_form, to_form(changeset))}
    end
  end

  def handle_event("edit_source", %{"id" => id}, socket) do
    source = Finances.get_income_source!(socket.assigns.profile, id)
    changeset = Finances.change_income_source(source)

    {:noreply,
     socket
     |> assign(:editing_source, source)
     |> assign(:source_form, to_form(changeset))
     |> assign(:source_category_id, source.income_category_id)}
  end

  def handle_event("delete_source", %{"id" => id}, socket) do
    source = Finances.get_income_source!(socket.assigns.profile, id)
    {:ok, _} = Finances.delete_income_source(source)

    {:noreply,
     socket
     |> assign(:categories, Finances.list_income_categories(socket.assigns.profile))
     |> put_flash(:info, gettext("Wellspring dried up."))}
  end

  def handle_event("new_entry", %{"source-id" => source_id}, socket) do
    source = Finances.get_income_source!(socket.assigns.profile, source_id)
    today = Date.utc_today()

    changeset =
      Finances.change_income_entry(%IncomeEntry{
        income_source_id: source.id,
        year: today.year,
        month: today.month
      })

    {:noreply,
     socket
     |> assign(:entry_form, to_form(changeset))
     |> assign(:entry_source, source)}
  end

  def handle_event("cancel_entry", _params, socket) do
    {:noreply, assign(socket, entry_form: nil, entry_source: nil, editing_entry: nil)}
  end

  def handle_event("save_entry", %{"income_entry" => params}, socket) do
    source = socket.assigns.entry_source

    result =
      if socket.assigns.editing_entry do
        Finances.update_income_entry(socket.assigns.editing_entry, params)
      else
        Finances.create_income_entry(source, params)
      end

    case result do
      {:ok, _entry} ->
        {:noreply,
         socket
         |> assign(:categories, Finances.list_income_categories(socket.assigns.profile))
         |> assign(:entry_form, nil)
         |> assign(:entry_source, nil)
         |> assign(:editing_entry, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :entry_form, to_form(changeset))}
    end
  end

  def handle_event("edit_entry", %{"source-id" => source_id, "id" => entry_id}, socket) do
    source = Finances.get_income_source!(socket.assigns.profile, source_id)
    entry = Finances.get_income_entry!(source, entry_id)
    changeset = Finances.change_income_entry(entry)

    {:noreply,
     socket
     |> assign(:editing_entry, entry)
     |> assign(:entry_form, to_form(changeset))
     |> assign(:entry_source, source)}
  end

  def handle_event("delete_entry", %{"source-id" => source_id, "id" => entry_id}, socket) do
    source = Finances.get_income_source!(socket.assigns.profile, source_id)
    entry = Finances.get_income_entry!(source, entry_id)
    {:ok, _} = Finances.delete_income_entry(entry)

    {:noreply,
     socket
     |> assign(:categories, Finances.list_income_categories(socket.assigns.profile))
     |> put_flash(:info, gettext("Record expunged."))}
  end

  def handle_event("toggle_pin", %{"id" => id}, socket) do
    profile = socket.assigns.profile
    category = Finances.get_income_category!(profile, id)
    {:ok, _} = Finances.toggle_pin_income_category(category)
    {:noreply, assign(socket, :categories, Finances.list_income_categories(profile))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center justify-between">
        <div>
          <.link navigate={~p"/profiles/#{@profile}"} class="text-muted hover:text-gold font-cinzel text-sm">
            &larr; {@profile.nickname}
          </.link>
          <h1 class="font-cinzel-decorative font-bold text-3xl text-[#3d8b3d] mt-1">🪙 {gettext("Coffers")}</h1>
        </div>
        <button phx-click="new_category" class="btn-medieval">
          🏷️ {gettext("New Guild")}
        </button>
      </div>

      <%!-- Guild form (new or edit) --%>
      <div :if={@category_form} class="panel p-5">
        <h2 class="panel-title text-lg mb-3">
          {if @editing_category, do: gettext("Edit Guild"), else: gettext("New Guild")}
        </h2>
        <.form for={@category_form} phx-submit="save_category" class="flex items-end gap-3">
          <.input field={@category_form[:name]} label={gettext("Name")} placeholder={gettext("e.g. Crown's Pay, Mercenary Work")} />
          <button type="submit" class="btn-medieval">{gettext("Save")}</button>
          <button type="button" phx-click="cancel_category" class="btn-medieval btn-danger">{gettext("Cancel")}</button>
        </.form>
      </div>

      <%!-- Empty state --%>
      <div :if={@categories == [] && !@category_form} class="panel p-10 text-center">
        <div class="text-5xl mb-3">🏚️</div>
        <p class="italic-fell text-muted mt-3">
          {gettext("No guilds yet — establish one to start tallying your coin.")}
        </p>
      </div>

      <%!-- Category list --%>
      <div :for={category <- @categories} class="panel p-5 space-y-4">
        <div class="flex items-center justify-between">
          <h2 class="panel-title text-xl">
            {if category.pinned, do: "📌", else: "⚜️"} {category.name}
          </h2>
          <div class="flex gap-2">
            <button phx-click="new_source" phx-value-category-id={category.id} class="btn-medieval text-sm">
              ⛏️ {gettext("Add Wellspring")}
            </button>
            <button phx-click="toggle_pin" phx-value-id={category.id} class="btn-medieval text-sm" title={gettext("Pin")}>
              {if category.pinned, do: "📌", else: "📍"}
            </button>
            <button phx-click="edit_category" phx-value-id={category.id} class="btn-medieval text-sm">
              <.icon name="hero-pencil-square" class="size-4" />
            </button>
            <button
              phx-click="delete_category"
              phx-value-id={category.id}
              class="btn-medieval btn-danger text-sm"
              data-confirm={gettext("Disband this guild and all its wellsprings?")}
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
          </div>
        </div>

        <%!-- Source form for this category --%>
        <div :if={@source_form && to_string(@source_category_id) == to_string(category.id)} class="ml-4 border-l-2 border-[#7a5c1e] pl-4">
          <h3 class="font-cinzel text-gold text-sm mb-2">
            {if @editing_source, do: gettext("Edit Wellspring"), else: gettext("New Wellspring")}
          </h3>
          <.form for={@source_form} phx-submit="save_source" class="space-y-2">
            <input type="hidden" name="income_source[income_category_id]" value={category.id} />
            <div class="flex flex-wrap items-end gap-3">
              <.input field={@source_form[:name]} label={gettext("Name")} placeholder={gettext("e.g. Lord Pemberton")} />
              <.input
                field={@source_form[:recurrence]}
                type="select"
                label={gettext("Recurrence")}
                options={[{gettext("Monthly"), :monthly}, {gettext("Sporadic"), :sporadic}]}
              />
              <.input field={@source_form[:base_amount]} type="number" label={gettext("Base Tithe")} placeholder="0.00" step="0.01" min="0" />
            </div>
            <div class="flex gap-2">
              <button type="submit" class="btn-medieval">{gettext("Save")}</button>
              <button type="button" phx-click="cancel_source" class="btn-medieval btn-danger">{gettext("Cancel")}</button>
            </div>
          </.form>
        </div>

        <%!-- Sources list --%>
        <div :if={category.sources != []} class="ml-4 space-y-3">
          <div :for={source <- category.sources} class="border-l-2 border-[#7a5c1e] pl-4">
            <div class="flex items-center justify-between">
              <div>
                <span class="text-cream font-cinzel">{source.name}</span>
                <span class={[
                  "ml-2 text-xs px-2 py-0.5 rounded",
                  if(source.recurrence == :monthly, do: "bg-[#3d8b3d]/20 text-[#3d8b3d]", else: "bg-[#d4a017]/20 text-[#d4a017]")
                ]}>
                  {if source.recurrence == :monthly, do: gettext("Monthly"), else: gettext("Sporadic")}
                </span>
                <span :if={source.base_amount} class="ml-2 text-muted text-sm">
                  {gettext("Tithe:")} {Decimal.to_string(source.base_amount)}
                </span>
              </div>
              <div class="flex gap-2">
                <button phx-click="new_entry" phx-value-source-id={source.id} class="btn-medieval text-xs">
                  <.icon name="hero-plus" class="size-3" /> {gettext("Record")}
                </button>
                <button phx-click="edit_source" phx-value-id={source.id} class="btn-medieval text-xs">
                  <.icon name="hero-pencil-square" class="size-3" />
                </button>
                <button
                  phx-click="delete_source"
                  phx-value-id={source.id}
                  class="btn-medieval btn-danger text-xs"
                  data-confirm={gettext("Dry up this wellspring and all its records?")}
                >
                  <.icon name="hero-trash" class="size-3" />
                </button>
              </div>
            </div>

            <%!-- Entry form for this source --%>
            <div :if={@entry_form && @entry_source && @entry_source.id == source.id} class="mt-3 ml-4 border-l-2 border-[#3d8b3d] pl-3">
              <h4 class="font-cinzel text-[#3d8b3d] text-sm mb-2">
                {if @editing_entry, do: gettext("Edit Record"), else: gettext("New Record")}
              </h4>
              <.form for={@entry_form} phx-submit="save_entry" class="space-y-2">
                <input type="hidden" name="income_entry[income_source_id]" value={source.id} />
                <div class="flex flex-wrap items-end gap-3">
                  <.input field={@entry_form[:year]} type="number" label={gettext("Year")} min="1970" max="9999" />
                  <.input field={@entry_form[:month]} type="number" label={gettext("Month")} min="1" max="12" />
                  <.input field={@entry_form[:amount]} type="number" label={gettext("Amount")} placeholder="0.00" step="0.01" min="0" />
                  <.input field={@entry_form[:note]} label={gettext("Note")} placeholder={gettext("optional")} />
                </div>
                <div class="flex gap-2">
                  <button type="submit" class="btn-medieval">{gettext("Save")}</button>
                  <button type="button" phx-click="cancel_entry" class="btn-medieval btn-danger">{gettext("Cancel")}</button>
                </div>
              </.form>
            </div>

            <%!-- Entries table --%>
            <.entries_table :if={source.entries != [] && Ecto.assoc_loaded?(source.entries)} entries={source.entries} source={source} />
          </div>
        </div>

        <p :if={category.sources == []} class="ml-4 italic-fell text-muted text-sm">
          🕸️ {gettext("No wellsprings yet.")}
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp entries_table(assigns) do
    ~H"""
    <div class="mt-2 ml-4 overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-gold font-cinzel text-xs border-b border-[#7a5c1e]">
            <th class="text-left py-1 px-2">{gettext("Year")}</th>
            <th class="text-left py-1 px-2">{gettext("Month")}</th>
            <th class="text-right py-1 px-2">{gettext("Amount")}</th>
            <th class="text-left py-1 px-2">{gettext("Note")}</th>
            <th class="py-1 px-2"></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={entry <- @entries} class="border-b border-[#7a5c1e]/30 hover:bg-[#2e1f0e]">
            <td class="py-1 px-2 text-cream">{entry.year}</td>
            <td class="py-1 px-2 text-cream">{entry.month}</td>
            <td class="py-1 px-2 text-right text-[#3d8b3d] font-mono">{Decimal.to_string(entry.amount)}</td>
            <td class="py-1 px-2 text-muted">{entry.note || "—"}</td>
            <td class="py-1 px-2 flex gap-1 justify-end">
              <button phx-click="edit_entry" phx-value-source-id={@source.id} phx-value-id={entry.id} class="text-muted hover:text-gold">
                <.icon name="hero-pencil-square" class="size-4" />
              </button>
              <button
                phx-click="delete_entry"
                phx-value-source-id={@source.id}
                phx-value-id={entry.id}
                class="text-muted hover:text-[#8b1a1a]"
                data-confirm={gettext("Expunge this record?")}
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
