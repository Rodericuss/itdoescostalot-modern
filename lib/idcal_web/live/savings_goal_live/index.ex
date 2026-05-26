defmodule IdcalWeb.SavingsGoalLive.Index do
  use IdcalWeb, :live_view

  alias Idcal.Finances
  alias Idcal.Finances.{SavingsGoal, SavingsContribution}

  import IdcalWeb.FormatHelpers, only: [format_amount: 1]

  @impl true
  def mount(%{"id" => profile_id}, _session, socket) do
    profile = Finances.get_profile!(socket.assigns.current_scope, profile_id)
    goals = Finances.list_savings_goals(profile)

    {:ok,
     socket
     |> assign(:page_title, gettext("Quests"))
     |> assign(:profile, profile)
     |> assign(:goals, goals)
     |> assign(:goal_form, nil)
     |> assign(:editing_goal, nil)
     |> assign(:contribution_form, nil)
     |> assign(:contribution_goal, nil)
     |> assign(:editing_contribution, nil)}
  end

  @impl true
  def handle_event("new_goal", _params, socket) do
    changeset = Finances.change_savings_goal(%SavingsGoal{tracking_mode: :manual})
    {:noreply, assign(socket, :goal_form, to_form(changeset))}
  end

  def handle_event("cancel_goal", _params, socket) do
    {:noreply, assign(socket, goal_form: nil, editing_goal: nil)}
  end

  def handle_event("save_goal", %{"savings_goal" => params}, socket) do
    profile = socket.assigns.profile

    result =
      if socket.assigns.editing_goal do
        Finances.update_savings_goal(socket.assigns.editing_goal, params)
      else
        Finances.create_savings_goal(profile, params)
      end

    case result do
      {:ok, _goal} ->
        {:noreply,
         socket
         |> assign(:goals, Finances.list_savings_goals(profile))
         |> assign(:goal_form, nil)
         |> assign(:editing_goal, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :goal_form, to_form(changeset))}
    end
  end

  def handle_event("edit_goal", %{"id" => id}, socket) do
    goal = Finances.get_savings_goal!(socket.assigns.profile, id)
    changeset = Finances.change_savings_goal(goal)

    {:noreply,
     socket
     |> assign(:editing_goal, goal)
     |> assign(:goal_form, to_form(changeset))}
  end

  def handle_event("delete_goal", %{"id" => id}, socket) do
    goal = Finances.get_savings_goal!(socket.assigns.profile, id)
    {:ok, _} = Finances.delete_savings_goal(goal)

    {:noreply,
     socket
     |> assign(:goals, Finances.list_savings_goals(socket.assigns.profile))
     |> put_flash(:info, gettext("Quest abandoned."))}
  end

  def handle_event("new_contribution", %{"goal-id" => goal_id}, socket) do
    goal = Finances.get_savings_goal!(socket.assigns.profile, goal_id)
    today = Date.utc_today()

    changeset =
      Finances.change_savings_contribution(%SavingsContribution{
        savings_goal_id: goal.id,
        year: today.year,
        month: today.month
      })

    {:noreply,
     socket
     |> assign(:contribution_form, to_form(changeset))
     |> assign(:contribution_goal, goal)}
  end

  def handle_event("cancel_contribution", _params, socket) do
    {:noreply, assign(socket, contribution_form: nil, contribution_goal: nil, editing_contribution: nil)}
  end

  def handle_event("save_contribution", %{"savings_contribution" => params}, socket) do
    goal = socket.assigns.contribution_goal

    result =
      if socket.assigns.editing_contribution do
        Finances.update_savings_contribution(socket.assigns.editing_contribution, params)
      else
        Finances.create_savings_contribution(goal, params)
      end

    case result do
      {:ok, _contribution} ->
        {:noreply,
         socket
         |> assign(:goals, Finances.list_savings_goals(socket.assigns.profile))
         |> assign(:contribution_form, nil)
         |> assign(:contribution_goal, nil)
         |> assign(:editing_contribution, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :contribution_form, to_form(changeset))}
    end
  end

  def handle_event("edit_contribution", %{"goal-id" => goal_id, "id" => id}, socket) do
    goal = Finances.get_savings_goal!(socket.assigns.profile, goal_id)
    contribution = Finances.get_savings_contribution!(goal, id)
    changeset = Finances.change_savings_contribution(contribution)

    {:noreply,
     socket
     |> assign(:editing_contribution, contribution)
     |> assign(:contribution_form, to_form(changeset))
     |> assign(:contribution_goal, goal)}
  end

  def handle_event("delete_contribution", %{"goal-id" => goal_id, "id" => id}, socket) do
    goal = Finances.get_savings_goal!(socket.assigns.profile, goal_id)
    contribution = Finances.get_savings_contribution!(goal, id)
    {:ok, _} = Finances.delete_savings_contribution(contribution)

    {:noreply,
     socket
     |> assign(:goals, Finances.list_savings_goals(socket.assigns.profile))
     |> put_flash(:info, gettext("Record expunged."))}
  end

  defp goal_progress(goal, profile) do
    Finances.savings_goal_progress(goal, profile)
  end

  defp tracking_mode_label(:auto), do: gettext("Auto (from surplus)")
  defp tracking_mode_label(:manual), do: gettext("Manual contributions")

  defp progress_bar_color(pct) do
    cond do
      Decimal.gte?(pct, 100) -> "bg-[#3d8b3d]"
      Decimal.gte?(pct, 75) -> "bg-[#d4a017]"
      true -> "bg-[#8b5213]"
    end
  end

  defp deadline_urgency(months_left) do
    cond do
      months_left <= 0 -> "text-[#8b1a1a] font-bold"
      months_left <= 3 -> "text-[#d4a017]"
      true -> "text-muted"
    end
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
          <h1 class="font-cinzel-decorative font-bold text-3xl text-[#d4a017] mt-1">🏆 {gettext("Quests")}</h1>
        </div>
        <button phx-click="new_goal" class="btn-medieval">
          ⚔️ {gettext("New Quest")}
        </button>
      </div>

      <%!-- Goal form --%>
      <div :if={@goal_form} class="panel p-5">
        <h2 class="panel-title text-lg mb-3">
          {if @editing_goal, do: gettext("Edit Quest"), else: gettext("New Quest")}
        </h2>
        <.form for={@goal_form} phx-submit="save_goal" class="space-y-3">
          <div class="flex flex-wrap items-end gap-3">
            <.input field={@goal_form[:name]} label={gettext("Name")} placeholder={gettext("e.g. Travel to Africa")} />
            <.input field={@goal_form[:target_amount]} type="number" label={gettext("Target Amount")} placeholder="0.00" step="0.01" min="0" />
            <.input field={@goal_form[:deadline]} type="date" label={gettext("Deadline")} />
            <.input
              field={@goal_form[:tracking_mode]}
              type="select"
              label={gettext("Tracking")}
              options={[{gettext("Manual contributions"), :manual}, {gettext("Auto (from surplus)"), :auto}]}
            />
          </div>
          <div class="flex gap-2">
            <button type="submit" class="btn-medieval">{gettext("Save")}</button>
            <button type="button" phx-click="cancel_goal" class="btn-medieval btn-danger">{gettext("Cancel")}</button>
          </div>
        </.form>
      </div>

      <%!-- Empty state --%>
      <div :if={@goals == [] && !@goal_form} class="panel p-10 text-center">
        <div class="text-5xl mb-3">🗺️</div>
        <p class="italic-fell text-muted mt-3">
          {gettext("No quests yet — embark on one to start saving toward your goal.")}
        </p>
      </div>

      <%!-- Goals list --%>
      <div :for={goal <- @goals} class="panel p-5 space-y-4">
        <% progress = goal_progress(goal, @profile) %>
        <div class="flex items-start justify-between">
          <div>
            <h2 class="panel-title text-xl">🏆 {goal.name}</h2>
            <div class="flex flex-wrap gap-4 mt-1 text-sm">
              <span class="text-muted">
                🎯 {gettext("Target:")} <span class="text-cream">{format_amount(goal.target_amount)}</span>
              </span>
              <span class={deadline_urgency(progress.months_left)}>
                📅 {goal.deadline}
                ({ngettext("%{count} month left", "%{count} months left", progress.months_left)})
              </span>
              <span class="text-muted text-xs px-2 py-0.5 bg-[#2e1f0e] border border-[#7a5c1e]">
                {tracking_mode_label(goal.tracking_mode)}
              </span>
            </div>
          </div>
          <div class="flex gap-2">
            <button :if={goal.tracking_mode == :manual} phx-click="new_contribution" phx-value-goal-id={goal.id} class="btn-medieval text-sm">
              <.icon name="hero-plus" class="size-3" /> {gettext("Contribute")}
            </button>
            <button phx-click="edit_goal" phx-value-id={goal.id} class="btn-medieval text-sm">
              <.icon name="hero-pencil-square" class="size-4" />
            </button>
            <button
              phx-click="delete_goal"
              phx-value-id={goal.id}
              class="btn-medieval btn-danger text-sm"
              data-confirm={gettext("Abandon this quest?")}
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
          </div>
        </div>

        <%!-- Progress bar --%>
        <div>
          <div class="flex justify-between text-sm mb-1">
            <span class="text-cream">{format_amount(progress.saved)} / {format_amount(goal.target_amount)}</span>
            <span class="text-gold">{Decimal.to_string(progress.percentage)}%</span>
          </div>
          <div class="w-full bg-[#1a1208] border border-[#7a5c1e] h-5">
            <div
              class={["h-full transition-all", progress_bar_color(progress.percentage)]}
              style={"width: #{min(Decimal.to_float(progress.percentage), 100)}%"}
            />
          </div>
        </div>

        <%!-- Required monthly surplus --%>
        <div :if={progress.months_left > 0 && Decimal.gt?(progress.remaining, 0)} class="text-sm italic-fell text-muted">
          📜 {gettext("To reach thy goal, thou must save")}
          <span class="text-[#d4a017] font-mono">{format_amount(progress.required_monthly)}</span>
          {gettext("per month.")}
        </div>
        <div :if={Decimal.gte?(progress.percentage, 100)} class="text-sm italic-fell text-[#3d8b3d]">
          🎉 {gettext("Quest complete! Thy goal hath been achieved!")}
        </div>
        <div :if={progress.months_left <= 0 && Decimal.lt?(progress.percentage, 100)} class="text-sm italic-fell text-[#8b1a1a]">
          ⚠️ {gettext("The deadline hath passed and the quest remains unfinished.")}
        </div>

        <%!-- Contribution form --%>
        <div :if={@contribution_form && @contribution_goal && @contribution_goal.id == goal.id} class="ml-4 border-l-2 border-[#d4a017] pl-4">
          <h3 class="font-cinzel text-gold text-sm mb-2">
            {if @editing_contribution, do: gettext("Edit Contribution"), else: gettext("New Contribution")}
          </h3>
          <.form for={@contribution_form} phx-submit="save_contribution" class="space-y-2">
            <div class="flex flex-wrap items-end gap-3">
              <.input field={@contribution_form[:year]} type="number" label={gettext("Year")} min="1970" max="9999" />
              <.input field={@contribution_form[:month]} type="number" label={gettext("Month")} min="1" max="12" />
              <.input field={@contribution_form[:amount]} type="number" label={gettext("Amount")} placeholder="0.00" step="0.01" min="0" />
              <.input field={@contribution_form[:note]} label={gettext("Note")} placeholder={gettext("optional")} />
            </div>
            <div class="flex gap-2">
              <button type="submit" class="btn-medieval">{gettext("Save")}</button>
              <button type="button" phx-click="cancel_contribution" class="btn-medieval btn-danger">{gettext("Cancel")}</button>
            </div>
          </.form>
        </div>

        <%!-- Contributions table --%>
        <div :if={goal.tracking_mode == :manual && goal.contributions != []} class="ml-4">
          <h3 class="font-cinzel text-gold text-sm mb-2">{gettext("Contributions")}</h3>
          <div class="overflow-x-auto">
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
                <tr :for={c <- goal.contributions} class="border-b border-[#7a5c1e]/30 hover:bg-[#2e1f0e]">
                  <td class="py-1 px-2 text-cream">{c.year}</td>
                  <td class="py-1 px-2 text-cream">{c.month}</td>
                  <td class="py-1 px-2 text-right text-[#d4a017] font-mono">{format_amount(c.amount)}</td>
                  <td class="py-1 px-2 text-muted">{c.note || "—"}</td>
                  <td class="py-1 px-2 flex gap-1 justify-end">
                    <button phx-click="edit_contribution" phx-value-goal-id={goal.id} phx-value-id={c.id} class="text-muted hover:text-gold">
                      <.icon name="hero-pencil-square" class="size-4" />
                    </button>
                    <button
                      phx-click="delete_contribution"
                      phx-value-goal-id={goal.id}
                      phx-value-id={c.id}
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
        </div>
      </div>
    </Layouts.app>
    """
  end
end
