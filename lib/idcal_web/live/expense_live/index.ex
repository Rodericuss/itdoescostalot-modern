defmodule IdcalWeb.ExpenseLive.Index do
  use IdcalWeb, :live_view

  alias Idcal.Finances
  alias Idcal.Finances.{ExpenseCategory, ExpenseType, ExpenseEntry}

  import IdcalWeb.FormatHelpers, only: [format_amount: 1]

  @impl true
  def mount(%{"id" => profile_id}, _session, socket) do
    profile = Finances.get_profile!(socket.assigns.current_scope, profile_id)
    categories = Finances.list_expense_categories(profile)
    today = Date.utc_today()
    budget_status = Finances.budget_status_for_month(profile, today.year, today.month)

    {:ok,
     socket
     |> assign(:page_title, gettext("Tributes"))
     |> assign(:profile, profile)
     |> assign(:categories, categories)
     |> assign(:budget_status, Map.new(budget_status, fn {cat, status} -> {cat.id, status} end))
     |> assign(:category_form, nil)
     |> assign(:editing_category, nil)
     |> assign(:type_form, nil)
     |> assign(:type_category_id, nil)
     |> assign(:editing_type, nil)
     |> assign(:entry_form, nil)
     |> assign(:entry_type, nil)
     |> assign(:editing_entry, nil)
     |> assign(:show_import, false)
     |> allow_upload(:csv_file, accept: ~w(.csv), max_entries: 1, max_file_size: 1_000_000)}
  end

  @impl true
  def handle_event("new_category", _params, socket) do
    changeset = Finances.change_expense_category(%ExpenseCategory{})
    {:noreply, assign(socket, :category_form, to_form(changeset))}
  end

  def handle_event("cancel_category", _params, socket) do
    {:noreply, assign(socket, category_form: nil, editing_category: nil)}
  end

  def handle_event("save_category", %{"expense_category" => params}, socket) do
    profile = socket.assigns.profile

    result =
      if socket.assigns.editing_category do
        Finances.update_expense_category(socket.assigns.editing_category, params)
      else
        Finances.create_expense_category(profile, params)
      end

    case result do
      {:ok, _category} ->
        {:noreply,
         socket
         |> assign(:categories, Finances.list_expense_categories(profile))
         |> assign(:category_form, nil)
         |> assign(:editing_category, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :category_form, to_form(changeset))}
    end
  end

  def handle_event("edit_category", %{"id" => id}, socket) do
    category = Finances.get_expense_category!(socket.assigns.profile, id)
    changeset = Finances.change_expense_category(category)

    {:noreply,
     socket
     |> assign(:editing_category, category)
     |> assign(:category_form, to_form(changeset))}
  end

  def handle_event("delete_category", %{"id" => id}, socket) do
    category = Finances.get_expense_category!(socket.assigns.profile, id)
    {:ok, _} = Finances.delete_expense_category(category)

    {:noreply,
     socket
     |> assign(:categories, Finances.list_expense_categories(socket.assigns.profile))
     |> put_flash(:info, gettext("Guild disbanded."))}
  end

  def handle_event("new_type", %{"category-id" => category_id}, socket) do
    changeset = Finances.change_expense_type(%ExpenseType{expense_category_id: category_id})

    {:noreply,
     socket
     |> assign(:type_form, to_form(changeset))
     |> assign(:type_category_id, category_id)}
  end

  def handle_event("cancel_type", _params, socket) do
    {:noreply, assign(socket, type_form: nil, type_category_id: nil, editing_type: nil)}
  end

  def handle_event("save_type", %{"expense_type" => params}, socket) do
    profile = socket.assigns.profile

    result =
      if socket.assigns.editing_type do
        Finances.update_expense_type(socket.assigns.editing_type, params)
      else
        Finances.create_expense_type(profile, params)
      end

    case result do
      {:ok, _type} ->
        {:noreply,
         socket
         |> assign(:categories, Finances.list_expense_categories(profile))
         |> assign(:type_form, nil)
         |> assign(:type_category_id, nil)
         |> assign(:editing_type, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :type_form, to_form(changeset))}
    end
  end

  def handle_event("edit_type", %{"id" => id}, socket) do
    type = Finances.get_expense_type!(socket.assigns.profile, id)
    changeset = Finances.change_expense_type(type)

    {:noreply,
     socket
     |> assign(:editing_type, type)
     |> assign(:type_form, to_form(changeset))
     |> assign(:type_category_id, type.expense_category_id)}
  end

  def handle_event("delete_type", %{"id" => id}, socket) do
    type = Finances.get_expense_type!(socket.assigns.profile, id)
    {:ok, _} = Finances.delete_expense_type(type)

    {:noreply,
     socket
     |> assign(:categories, Finances.list_expense_categories(socket.assigns.profile))
     |> put_flash(:info, gettext("Levy abolished."))}
  end

  def handle_event("new_entry", %{"type-id" => type_id}, socket) do
    type = Finances.get_expense_type!(socket.assigns.profile, type_id)
    today = Date.utc_today()

    changeset =
      Finances.change_expense_entry(%ExpenseEntry{
        expense_type_id: type.id,
        year: today.year,
        month: today.month
      })

    {:noreply,
     socket
     |> assign(:entry_form, to_form(changeset))
     |> assign(:entry_type, type)}
  end

  def handle_event("cancel_entry", _params, socket) do
    {:noreply, assign(socket, entry_form: nil, entry_type: nil, editing_entry: nil)}
  end

  def handle_event("save_entry", %{"expense_entry" => params}, socket) do
    type = socket.assigns.entry_type

    result =
      if socket.assigns.editing_entry do
        Finances.update_expense_entry(socket.assigns.editing_entry, params)
      else
        Finances.create_expense_entry(type, params)
      end

    case result do
      {:ok, _entry} ->
        {:noreply,
         socket
         |> assign(:categories, Finances.list_expense_categories(socket.assigns.profile))
         |> assign(:entry_form, nil)
         |> assign(:entry_type, nil)
         |> assign(:editing_entry, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :entry_form, to_form(changeset))}
    end
  end

  def handle_event("edit_entry", %{"type-id" => type_id, "id" => entry_id}, socket) do
    type = Finances.get_expense_type!(socket.assigns.profile, type_id)
    entry = Finances.get_expense_entry!(type, entry_id)
    changeset = Finances.change_expense_entry(entry)

    {:noreply,
     socket
     |> assign(:editing_entry, entry)
     |> assign(:entry_form, to_form(changeset))
     |> assign(:entry_type, type)}
  end

  def handle_event("delete_entry", %{"type-id" => type_id, "id" => entry_id}, socket) do
    type = Finances.get_expense_type!(socket.assigns.profile, type_id)
    entry = Finances.get_expense_entry!(type, entry_id)
    {:ok, _} = Finances.delete_expense_entry(entry)

    {:noreply,
     socket
     |> assign(:categories, Finances.list_expense_categories(socket.assigns.profile))
     |> put_flash(:info, gettext("Record expunged."))}
  end

  def handle_event("toggle_pin", %{"id" => id}, socket) do
    profile = socket.assigns.profile
    category = Finances.get_expense_category!(profile, id)
    {:ok, _} = Finances.toggle_pin_expense_category(category)
    {:noreply, assign(socket, :categories, Finances.list_expense_categories(profile))}
  end

  def handle_event("validate_import", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_import", _params, socket) do
    {:noreply, assign(socket, :show_import, !socket.assigns.show_import)}
  end

  def handle_event("import_csv", _params, socket) do
    profile = socket.assigns.profile
    today = Date.utc_today()

    results =
      consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
        content = File.read!(path)
        rows =
          content
          |> String.split("\n")
          |> Enum.drop(1)
          |> Enum.reject(&(String.trim(&1) == ""))
          |> Enum.map(&parse_csv_row/1)

        case Finances.import_expense_csv(profile, rows, today.year, today.month) do
          {:ok, count} -> {:ok, count}
          {:error, reason} -> {:ok, {:error, reason}}
        end
      end)

    case results do
      [{:error, reason}] ->
        {:noreply, put_flash(socket, :error, "Import failed: #{inspect(reason)}")}

      counts ->
        total = Enum.sum(counts)
        {:noreply,
         socket
         |> assign(:categories, Finances.list_expense_categories(profile))
         |> assign(:show_import, false)
         |> put_flash(:info, ngettext("%{count} entry imported.", "%{count} entries imported.", total))}
    end
  end

  defp parse_csv_row(line) do
    line
    |> String.split(",")
    |> Enum.map(&String.trim/1)
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
          <h1 class="font-cinzel-decorative font-bold text-3xl text-[#8b1a1a] mt-1">💸 {gettext("Tributes")}</h1>
        </div>
        <div class="flex gap-2">
          <button phx-click="new_category" class="btn-medieval">
            🏷️ {gettext("New Guild")}
          </button>
          <button phx-click="toggle_import" class="btn-medieval">
            📤 {gettext("Import CSV")}
          </button>
        </div>
      </div>

      <%!-- CSV Import --%>
      <div :if={@show_import} class="panel p-5">
        <h2 class="panel-title text-lg mb-3">📤 {gettext("Import CSV")}</h2>
        <p class="text-muted text-xs italic-fell mb-3">
          {gettext("CSV format: Category, Type, Amount, Note (optional). First row is skipped as header.")}
        </p>
        <.form for={%{}} phx-submit="import_csv" phx-change="validate_import" class="space-y-3">
          <.live_file_input upload={@uploads.csv_file} class="text-cream text-sm" />
          <div class="flex gap-2">
            <button type="submit" class="btn-medieval">{gettext("Import")}</button>
            <button type="button" phx-click="toggle_import" class="btn-medieval btn-danger">{gettext("Cancel")}</button>
          </div>
        </.form>
      </div>

      <%!-- Guild form --%>
      <div :if={@category_form} class="panel p-5">
        <h2 class="panel-title text-lg mb-3">
          {if @editing_category, do: gettext("Edit Guild"), else: gettext("New Guild")}
        </h2>
        <.form for={@category_form} phx-submit="save_category" class="space-y-3">
          <div class="flex flex-wrap items-end gap-3">
            <.input field={@category_form[:name]} label={gettext("Name")} placeholder={gettext("e.g. Provisions, Revelry")} />
            <.input field={@category_form[:budget_limit]} type="number" label={gettext("Gold Limit")} placeholder={gettext("optional")} step="0.01" min="0" />
          </div>
          <div class="flex gap-2">
            <button type="submit" class="btn-medieval">{gettext("Save")}</button>
            <button type="button" phx-click="cancel_category" class="btn-medieval btn-danger">{gettext("Cancel")}</button>
          </div>
        </.form>
      </div>

      <%!-- Empty state --%>
      <div :if={@categories == [] && !@category_form} class="panel p-10 text-center">
        <div class="text-5xl mb-3">🏚️</div>
        <p class="italic-fell text-muted mt-3">
          {gettext("No guilds yet — establish one to start tracking your tributes.")}
        </p>
      </div>

      <%!-- Category list --%>
      <div :for={category <- @categories} class="panel p-5 space-y-4">
        <div class="flex items-center justify-between">
          <div>
            <h2 class="panel-title text-xl">
              {if category.pinned, do: "📌", else: "⚜️"} {category.name}
            </h2>
            <span :if={category.budget_limit} class="text-xs text-muted">
              {gettext("Gold Limit:")} {format_amount(category.budget_limit)}
            </span>
          </div>
          <div class="flex gap-2">
            <button phx-click="new_type" phx-value-category-id={category.id} class="btn-medieval text-sm">
              ⛏️ {gettext("Add Levy")}
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
              data-confirm={gettext("Disband this guild and all its levies?")}
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
          </div>
        </div>

        <%!-- Budget progress bar --%>
        <.budget_bar :if={@budget_status[category.id]} status={@budget_status[category.id]} />

        <%!-- Type form for this category --%>
        <div :if={@type_form && to_string(@type_category_id) == to_string(category.id)} class="ml-4 border-l-2 border-[#7a5c1e] pl-4">
          <h3 class="font-cinzel text-gold text-sm mb-2">
            {if @editing_type, do: gettext("Edit Levy"), else: gettext("New Levy")}
          </h3>
          <.form for={@type_form} phx-submit="save_type" class="space-y-2">
            <input type="hidden" name="expense_type[expense_category_id]" value={category.id} />
            <div class="flex flex-wrap items-end gap-3">
              <.input field={@type_form[:name]} label={gettext("Name")} placeholder={gettext("e.g. Torchlight, Arena")} />
              <.input
                field={@type_form[:recurrence]}
                type="select"
                label={gettext("Recurrence")}
                options={[{gettext("Monthly"), :monthly}, {gettext("Sporadic"), :sporadic}]}
              />
              <.input field={@type_form[:base_amount]} type="number" label={gettext("Base Tithe")} placeholder="0.00" step="0.01" min="0" />
            </div>
            <div class="flex gap-2">
              <button type="submit" class="btn-medieval">{gettext("Save")}</button>
              <button type="button" phx-click="cancel_type" class="btn-medieval btn-danger">{gettext("Cancel")}</button>
            </div>
          </.form>
        </div>

        <%!-- Types list --%>
        <div :if={category.types != []} class="ml-4 space-y-3">
          <div :for={type <- category.types} class="border-l-2 border-[#7a5c1e] pl-4">
            <div class="flex items-center justify-between">
              <div>
                <span class="text-cream font-cinzel">{type.name}</span>
                <span class={[
                  "ml-2 text-xs px-2 py-0.5 rounded",
                  if(type.recurrence == :monthly, do: "bg-[#8b1a1a]/20 text-[#8b1a1a]", else: "bg-[#d4a017]/20 text-[#d4a017]")
                ]}>
                  {if type.recurrence == :monthly, do: gettext("Monthly"), else: gettext("Sporadic")}
                </span>
                <span :if={type.base_amount} class="ml-2 text-muted text-sm">
                  {gettext("Tithe:")} {Decimal.to_string(type.base_amount)}
                </span>
              </div>
              <div class="flex gap-2">
                <button phx-click="new_entry" phx-value-type-id={type.id} class="btn-medieval text-xs">
                  <.icon name="hero-plus" class="size-3" /> {gettext("Record")}
                </button>
                <button phx-click="edit_type" phx-value-id={type.id} class="btn-medieval text-xs">
                  <.icon name="hero-pencil-square" class="size-3" />
                </button>
                <button
                  phx-click="delete_type"
                  phx-value-id={type.id}
                  class="btn-medieval btn-danger text-xs"
                  data-confirm={gettext("Abolish this levy and all its records?")}
                >
                  <.icon name="hero-trash" class="size-3" />
                </button>
              </div>
            </div>

            <%!-- Entry form for this type --%>
            <div :if={@entry_form && @entry_type && @entry_type.id == type.id} class="mt-3 ml-4 border-l-2 border-[#8b1a1a] pl-3">
              <h4 class="font-cinzel text-[#8b1a1a] text-sm mb-2">
                {if @editing_entry, do: gettext("Edit Record"), else: gettext("New Record")}
              </h4>
              <.form for={@entry_form} phx-submit="save_entry" class="space-y-2">
                <input type="hidden" name="expense_entry[expense_type_id]" value={type.id} />
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
            <.entries_table :if={type.entries != [] && Ecto.assoc_loaded?(type.entries)} entries={type.entries} type={type} />
          </div>
        </div>

        <p :if={category.types == []} class="ml-4 italic-fell text-muted text-sm">
          🕸️ {gettext("No levies yet.")}
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
            <td class="py-1 px-2 text-right text-[#8b1a1a] font-mono">{Decimal.to_string(entry.amount)}</td>
            <td class="py-1 px-2 text-muted">{entry.note || "—"}</td>
            <td class="py-1 px-2 flex gap-1 justify-end">
              <button phx-click="edit_entry" phx-value-type-id={@type.id} phx-value-id={entry.id} class="text-muted hover:text-gold">
                <.icon name="hero-pencil-square" class="size-4" />
              </button>
              <button
                phx-click="delete_entry"
                phx-value-type-id={@type.id}
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

  defp budget_bar(assigns) do
    pct_float = min(Decimal.to_float(assigns.status.percentage), 100)
    color =
      cond do
        Decimal.gte?(assigns.status.percentage, 100) -> "bg-[#8b1a1a]"
        Decimal.gte?(assigns.status.percentage, 80) -> "bg-[#d4a017]"
        true -> "bg-[#3d8b3d]"
      end

    assigns = assign(assigns, pct_float: pct_float, color: color)

    ~H"""
    <div class="mt-1">
      <div class="flex justify-between text-xs mb-1">
        <span class="text-muted">{gettext("Spent:")} {format_amount(@status.spent)} / {format_amount(@status.limit)}</span>
        <span class={if Decimal.gte?(@status.percentage, 100), do: "text-[#8b1a1a] font-bold", else: "text-gold"}>
          {Decimal.to_string(@status.percentage)}%
        </span>
      </div>
      <div class="w-full bg-[#1a1208] border border-[#7a5c1e] h-3">
        <div class={["h-full transition-all", @color]} style={"width: #{@pct_float}%"} />
      </div>
    </div>
    """
  end
end
