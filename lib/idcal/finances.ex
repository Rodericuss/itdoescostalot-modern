defmodule Idcal.Finances do
  @moduledoc """
  The Finances context — profiles and all financial data scoped to them.
  """

  import Ecto.Query, warn: false
  alias Idcal.Repo
  alias Idcal.Accounts.Scope
  alias Idcal.Finances.{Profile, IncomeCategory, IncomeSource, IncomeEntry}
  alias Idcal.Finances.{ExpenseCategory, ExpenseType, ExpenseEntry}
  alias Idcal.Finances.{BudgetOverride, SavingsGoal, SavingsContribution}
  alias Idcal.Finances.{MonthTemplate, MonthTemplateItem}
  alias Idcal.Finances.ProfileShare

  ## Profiles

  @doc "Lists all profiles owned by or shared with the scoped user."
  def list_profiles(%Scope{} = scope) do
    shared_ids =
      ProfileShare
      |> where(user_id: ^scope.user.id)
      |> select([s], s.profile_id)

    Profile
    |> where([p], p.user_id == ^scope.user.id or p.id in subquery(shared_ids))
    |> order_by(asc: :nickname)
    |> Repo.all()
  end

  @doc "Fetches a profile owned by or shared with the scoped user. Raises if not found."
  def get_profile!(%Scope{} = scope, id) do
    shared_ids =
      ProfileShare
      |> where(user_id: ^scope.user.id)
      |> select([s], s.profile_id)

    Profile
    |> where([p], p.user_id == ^scope.user.id or p.id in subquery(shared_ids))
    |> Repo.get!(id)
  end

  @doc "Checks if the user can edit a profile (owner or editor share)."
  def can_edit_profile?(%Scope{} = scope, %Profile{} = profile) do
    if profile.user_id == scope.user.id do
      true
    else
      Repo.exists?(
        from s in ProfileShare,
          where: s.profile_id == ^profile.id and s.user_id == ^scope.user.id and s.role == "editor"
      )
    end
  end

  @doc "Creates a profile owned by the scoped user."
  def create_profile(%Scope{} = scope, attrs) do
    %Profile{user_id: scope.user.id}
    |> Profile.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a profile."
  def update_profile(%Profile{} = profile, attrs) do
    profile
    |> Profile.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a profile and all its financial data."
  def delete_profile(%Profile{} = profile) do
    Repo.delete(profile)
  end

  @doc "Returns a changeset for tracking profile changes."
  def change_profile(%Profile{} = profile, attrs \\ %{}) do
    Profile.changeset(profile, attrs)
  end

  ## Profile sharing

  @doc "Lists all shares for a profile, with user preloaded."
  def list_profile_shares(%Profile{} = profile) do
    ProfileShare
    |> where(profile_id: ^profile.id)
    |> preload(:user)
    |> order_by(asc: :inserted_at)
    |> Repo.all()
  end

  @doc "Shares a profile with a user by email. Returns error if user not found or already shared."
  def share_profile(%Profile{} = profile, email, role \\ "viewer") do
    case Idcal.Accounts.get_user_by_email(email) do
      nil ->
        {:error, :user_not_found}

      user ->
        if user.id == profile.user_id do
          {:error, :cannot_share_with_self}
        else
          %ProfileShare{profile_id: profile.id, user_id: user.id}
          |> ProfileShare.changeset(%{role: role})
          |> Repo.insert()
        end
    end
  end

  @doc "Updates the role of a profile share."
  def update_profile_share(%ProfileShare{} = share, attrs) do
    share
    |> ProfileShare.changeset(attrs)
    |> Repo.update()
  end

  @doc "Removes a profile share."
  def delete_profile_share(%ProfileShare{} = share) do
    Repo.delete(share)
  end

  ## Income categories

  @doc "Lists income categories of a profile, with their sources preloaded."
  def list_income_categories(%Profile{} = profile) do
    IncomeCategory
    |> where(profile_id: ^profile.id)
    |> order_by([c], [desc: c.pinned, asc: c.name])
    |> preload(
      sources: ^from(s in IncomeSource, order_by: s.name, preload: [entries: ^from(e in IncomeEntry, order_by: [desc: e.year, desc: e.month])])
    )
    |> Repo.all()
  end

  @doc "Fetches an income category belonging to the profile."
  def get_income_category!(%Profile{} = profile, id) do
    IncomeCategory
    |> where(profile_id: ^profile.id)
    |> Repo.get!(id)
  end

  def create_income_category(%Profile{} = profile, attrs) do
    %IncomeCategory{profile_id: profile.id}
    |> IncomeCategory.changeset(attrs)
    |> Repo.insert()
  end

  def update_income_category(%IncomeCategory{} = category, attrs) do
    category
    |> IncomeCategory.changeset(attrs)
    |> Repo.update()
  end

  def delete_income_category(%IncomeCategory{} = category) do
    Repo.delete(category)
  end

  def change_income_category(%IncomeCategory{} = category, attrs \\ %{}) do
    IncomeCategory.changeset(category, attrs)
  end

  ## Income sources

  @doc "Fetches an income source belonging to the profile."
  def get_income_source!(%Profile{} = profile, id) do
    IncomeSource
    |> where(profile_id: ^profile.id)
    |> Repo.get!(id)
  end

  def create_income_source(%Profile{} = profile, attrs) do
    %IncomeSource{profile_id: profile.id}
    |> IncomeSource.changeset(attrs)
    |> Repo.insert()
  end

  def update_income_source(%IncomeSource{} = source, attrs) do
    source
    |> IncomeSource.changeset(attrs)
    |> Repo.update()
  end

  def delete_income_source(%IncomeSource{} = source) do
    Repo.delete(source)
  end

  def change_income_source(%IncomeSource{} = source, attrs \\ %{}) do
    IncomeSource.changeset(source, attrs)
  end

  ## Income entries

  @doc "Lists all entries of an income source, newest month first."
  def list_income_entries(%IncomeSource{} = source) do
    IncomeEntry
    |> where(income_source_id: ^source.id)
    |> order_by(desc: :year, desc: :month)
    |> Repo.all()
  end

  def get_income_entry!(%IncomeSource{} = source, id) do
    IncomeEntry
    |> where(income_source_id: ^source.id)
    |> Repo.get!(id)
  end

  def create_income_entry(%IncomeSource{} = source, attrs) do
    %IncomeEntry{income_source_id: source.id}
    |> IncomeEntry.changeset(attrs)
    |> Repo.insert()
  end

  def update_income_entry(%IncomeEntry{} = entry, attrs) do
    entry
    |> IncomeEntry.changeset(attrs)
    |> Repo.update()
  end

  def delete_income_entry(%IncomeEntry{} = entry) do
    Repo.delete(entry)
  end

  def change_income_entry(%IncomeEntry{} = entry, attrs \\ %{}) do
    IncomeEntry.changeset(entry, attrs)
  end

  ## Income resolution

  @doc """
  Resolves the income contributed by each source for a given month.

  Returns a list of `{source, amount}` tuples. A monthly source uses its
  `base_amount` unless an entry overrides it; a sporadic source contributes
  only when an entry exists for that month.
  """
  def income_breakdown_for_month(%Profile{} = profile, year, month) do
    sources =
      IncomeSource
      |> where(profile_id: ^profile.id)
      |> order_by(asc: :name)
      |> preload(:income_category)
      |> Repo.all()

    entries = entries_by_source(IncomeEntry, sources, year, month)

    Enum.flat_map(sources, fn source ->
      case resolve_amount(source, Map.get(entries, source.id)) do
        nil -> []
        amount -> [{source, amount}]
      end
    end)
  end

  @doc "Total income for a profile in the given month."
  def resolve_income_for_month(%Profile{} = profile, year, month) do
    profile
    |> income_breakdown_for_month(year, month)
    |> Enum.reduce(Decimal.new(0), fn {_source, amount}, acc -> Decimal.add(acc, amount) end)
  end

  ## Expense categories

  def list_expense_categories(%Profile{} = profile) do
    ExpenseCategory
    |> where(profile_id: ^profile.id)
    |> order_by([c], [desc: c.pinned, asc: c.name])
    |> preload(
      types: ^from(t in ExpenseType, order_by: t.name, preload: [entries: ^from(e in ExpenseEntry, order_by: [desc: e.year, desc: e.month])])
    )
    |> Repo.all()
  end

  def get_expense_category!(%Profile{} = profile, id) do
    ExpenseCategory
    |> where(profile_id: ^profile.id)
    |> Repo.get!(id)
  end

  def create_expense_category(%Profile{} = profile, attrs) do
    %ExpenseCategory{profile_id: profile.id}
    |> ExpenseCategory.changeset(attrs)
    |> Repo.insert()
  end

  def update_expense_category(%ExpenseCategory{} = category, attrs) do
    category
    |> ExpenseCategory.changeset(attrs)
    |> Repo.update()
  end

  def delete_expense_category(%ExpenseCategory{} = category) do
    Repo.delete(category)
  end

  def change_expense_category(%ExpenseCategory{} = category, attrs \\ %{}) do
    ExpenseCategory.changeset(category, attrs)
  end

  ## Expense types

  def get_expense_type!(%Profile{} = profile, id) do
    ExpenseType
    |> where(profile_id: ^profile.id)
    |> Repo.get!(id)
  end

  def create_expense_type(%Profile{} = profile, attrs) do
    %ExpenseType{profile_id: profile.id}
    |> ExpenseType.changeset(attrs)
    |> Repo.insert()
  end

  def update_expense_type(%ExpenseType{} = type, attrs) do
    type
    |> ExpenseType.changeset(attrs)
    |> Repo.update()
  end

  def delete_expense_type(%ExpenseType{} = type) do
    Repo.delete(type)
  end

  def change_expense_type(%ExpenseType{} = type, attrs \\ %{}) do
    ExpenseType.changeset(type, attrs)
  end

  ## Expense entries

  def list_expense_entries(%ExpenseType{} = type) do
    ExpenseEntry
    |> where(expense_type_id: ^type.id)
    |> order_by(desc: :year, desc: :month)
    |> Repo.all()
  end

  def get_expense_entry!(%ExpenseType{} = type, id) do
    ExpenseEntry
    |> where(expense_type_id: ^type.id)
    |> Repo.get!(id)
  end

  def create_expense_entry(%ExpenseType{} = type, attrs) do
    %ExpenseEntry{expense_type_id: type.id}
    |> ExpenseEntry.changeset(attrs)
    |> Repo.insert()
  end

  def update_expense_entry(%ExpenseEntry{} = entry, attrs) do
    entry
    |> ExpenseEntry.changeset(attrs)
    |> Repo.update()
  end

  def delete_expense_entry(%ExpenseEntry{} = entry) do
    Repo.delete(entry)
  end

  def change_expense_entry(%ExpenseEntry{} = entry, attrs \\ %{}) do
    ExpenseEntry.changeset(entry, attrs)
  end

  ## CSV Import

  @doc """
  Imports sporadic expense entries from CSV rows.
  Each row is `[category_name, type_name, amount, note]`.
  Creates categories/types on the fly if they don't exist.
  Returns `{:ok, count}` or `{:error, reason}`.
  """
  def import_expense_csv(%Profile{} = profile, rows, year, month) do
    Repo.transaction(fn ->
      Enum.reduce(rows, 0, fn row, count ->
        case row do
          [cat_name, type_name, amount_str | rest] ->
            note = List.first(rest)
            case Decimal.parse(String.trim(amount_str)) do
              {amount, ""} ->
                category = find_or_create_expense_category!(profile, String.trim(cat_name))
                type = find_or_create_expense_type!(profile, category, String.trim(type_name))
                {:ok, _} = create_expense_entry(type, %{
                  "year" => year,
                  "month" => month,
                  "amount" => amount,
                  "note" => if(note, do: String.trim(note), else: nil)
                })
                count + 1

              _ -> count
            end

          _ -> count
        end
      end)
    end)
  end

  defp find_or_create_expense_category!(profile, name) do
    case Repo.one(from c in ExpenseCategory, where: c.profile_id == ^profile.id and c.name == ^name) do
      nil ->
        {:ok, cat} = create_expense_category(profile, %{"name" => name})
        cat
      cat -> cat
    end
  end

  defp find_or_create_expense_type!(profile, category, name) do
    case Repo.one(from t in ExpenseType, where: t.profile_id == ^profile.id and t.expense_category_id == ^category.id and t.name == ^name) do
      nil ->
        {:ok, type} = create_expense_type(profile, %{
          "name" => name,
          "expense_category_id" => category.id,
          "recurrence" => "sporadic"
        })
        type
      type -> type
    end
  end

  ## Clone month

  @doc "Copies all sporadic income and expense entries from one month to another."
  def clone_month(%Profile{} = profile, from_year, from_month, to_year, to_month) do
    Repo.transaction(fn ->
      income_count = clone_income_entries(profile, from_year, from_month, to_year, to_month)
      expense_count = clone_expense_entries(profile, from_year, from_month, to_year, to_month)
      income_count + expense_count
    end)
  end

  defp clone_income_entries(profile, from_year, from_month, to_year, to_month) do
    sources =
      IncomeSource
      |> where(profile_id: ^profile.id, recurrence: :sporadic)
      |> Repo.all()

    source_ids = Enum.map(sources, & &1.id)

    entries =
      IncomeEntry
      |> where([e], e.income_source_id in ^source_ids and e.year == ^from_year and e.month == ^from_month)
      |> Repo.all()

    Enum.reduce(entries, 0, fn entry, count ->
      existing = Repo.one(from e in IncomeEntry,
        where: e.income_source_id == ^entry.income_source_id and e.year == ^to_year and e.month == ^to_month)

      if existing do
        count
      else
        source = Enum.find(sources, &(&1.id == entry.income_source_id))
        {:ok, _} = create_income_entry(source, %{
          "year" => to_year, "month" => to_month,
          "amount" => entry.amount, "note" => entry.note
        })
        count + 1
      end
    end)
  end

  defp clone_expense_entries(profile, from_year, from_month, to_year, to_month) do
    types =
      ExpenseType
      |> where(profile_id: ^profile.id, recurrence: :sporadic)
      |> Repo.all()

    type_ids = Enum.map(types, & &1.id)

    entries =
      ExpenseEntry
      |> where([e], e.expense_type_id in ^type_ids and e.year == ^from_year and e.month == ^from_month)
      |> Repo.all()

    Enum.reduce(entries, 0, fn entry, count ->
      existing = Repo.one(from e in ExpenseEntry,
        where: e.expense_type_id == ^entry.expense_type_id and e.year == ^to_year and e.month == ^to_month)

      if existing do
        count
      else
        type = Enum.find(types, &(&1.id == entry.expense_type_id))
        {:ok, _} = create_expense_entry(type, %{
          "year" => to_year, "month" => to_month,
          "amount" => entry.amount, "note" => entry.note
        })
        count + 1
      end
    end)
  end

  ## Month templates

  @doc "Lists all month templates for a profile."
  def list_month_templates(%Profile{} = profile) do
    MonthTemplate
    |> where(profile_id: ^profile.id)
    |> order_by(asc: :name)
    |> preload(:items)
    |> Repo.all()
  end

  @doc "Fetches a month template by id. Raises if not found."
  def get_month_template!(%Profile{} = profile, id) do
    MonthTemplate
    |> where(profile_id: ^profile.id)
    |> preload(:items)
    |> Repo.get!(id)
  end

  @doc "Saves the current month's sporadic entries as a named template."
  def save_month_as_template(%Profile{} = profile, year, month, name) do
    income_rows = income_breakdown_for_month(profile, year, month)
    expense_rows = expense_breakdown_for_month(profile, year, month)

    income_items =
      income_rows
      |> Enum.filter(fn {source, _} -> source.recurrence == :sporadic end)
      |> Enum.map(fn {source, amount} ->
        %{kind: "income", category_name: source.income_category.name, name: source.name, amount: amount}
      end)

    expense_items =
      expense_rows
      |> Enum.filter(fn {type, _} -> type.recurrence == :sporadic end)
      |> Enum.map(fn {type, amount} ->
        %{kind: "expense", category_name: type.expense_category.name, name: type.name, amount: amount}
      end)

    items = income_items ++ expense_items

    Repo.transaction(fn ->
      {:ok, template} =
        %MonthTemplate{profile_id: profile.id}
        |> MonthTemplate.changeset(%{name: name})
        |> Repo.insert()

      Enum.each(items, fn item_attrs ->
        %MonthTemplateItem{month_template_id: template.id}
        |> MonthTemplateItem.changeset(item_attrs)
        |> Repo.insert!()
      end)

      Repo.preload(template, :items)
    end)
  end

  @doc "Applies a template's items to a target month, creating entries for matching sources/types."
  def apply_month_template(%Profile{} = profile, template_id, year, month) do
    template = get_month_template!(profile, template_id)

    Repo.transaction(fn ->
      count =
        Enum.reduce(template.items, 0, fn item, acc ->
          case apply_template_item(profile, item, year, month) do
            {:ok, _} -> acc + 1
            :skip -> acc
          end
        end)

      count
    end)
  end

  defp apply_template_item(profile, %MonthTemplateItem{kind: "income"} = item, year, month) do
    source =
      IncomeSource
      |> where(profile_id: ^profile.id, name: ^item.name, recurrence: :sporadic)
      |> preload(:income_category)
      |> Repo.one()

    cond do
      is_nil(source) -> :skip
      source.income_category.name != item.category_name -> :skip
      true ->
        existing = Repo.one(from e in IncomeEntry,
          where: e.income_source_id == ^source.id and e.year == ^year and e.month == ^month)
        if existing, do: :skip, else: create_income_entry(source, %{"year" => year, "month" => month, "amount" => item.amount, "note" => item.note})
    end
  end

  defp apply_template_item(profile, %MonthTemplateItem{kind: "expense"} = item, year, month) do
    type =
      ExpenseType
      |> where(profile_id: ^profile.id, name: ^item.name, recurrence: :sporadic)
      |> preload(:expense_category)
      |> Repo.one()

    cond do
      is_nil(type) -> :skip
      type.expense_category.name != item.category_name -> :skip
      true ->
        existing = Repo.one(from e in ExpenseEntry,
          where: e.expense_type_id == ^type.id and e.year == ^year and e.month == ^month)
        if existing, do: :skip, else: create_expense_entry(type, %{"year" => year, "month" => month, "amount" => item.amount, "note" => item.note})
    end
  end

  @doc "Deletes a month template."
  def delete_month_template(%MonthTemplate{} = template) do
    Repo.delete(template)
  end

  ## Expense resolution

  def expense_breakdown_for_month(%Profile{} = profile, year, month) do
    types =
      ExpenseType
      |> where(profile_id: ^profile.id)
      |> order_by(asc: :name)
      |> preload([:expense_category, entries: ^from(e in ExpenseEntry, order_by: [desc: e.year, desc: e.month])])
      |> Repo.all()

    entries = entries_by_source(ExpenseEntry, types, year, month)

    Enum.flat_map(types, fn type ->
      case resolve_amount(type, Map.get(entries, type.id)) do
        nil -> []
        amount -> [{type, amount}]
      end
    end)
  end

  def expense_breakdown_grouped_by_category(%Profile{} = profile, year, month) do
    profile
    |> expense_breakdown_for_month(year, month)
    |> Enum.group_by(fn {type, _amount} -> type.expense_category end)
    |> Enum.map(fn {category, items} ->
      total = Enum.reduce(items, Decimal.new(0), fn {_, amt}, acc -> Decimal.add(acc, amt) end)
      {category, items, total}
    end)
    |> Enum.sort_by(fn {cat, _, _} -> cat.name end)
  end

  def resolve_expenses_for_month(%Profile{} = profile, year, month) do
    profile
    |> expense_breakdown_for_month(year, month)
    |> Enum.reduce(Decimal.new(0), fn {_type, amount}, acc -> Decimal.add(acc, amount) end)
  end

  ## Annual summary

  def annual_summary(%Profile{} = profile, year) do
    Enum.map(1..12, fn month ->
      tracked = Profile.tracking_started?(profile, year, month)
      income = resolve_income_for_month(profile, year, month)
      expenses = resolve_expenses_for_month(profile, year, month)
      balance = Decimal.sub(income, expenses)
      %{month: month, income: income, expenses: expenses, balance: balance, tracked: tracked}
    end)
  end

  ## Insights & Analytics

  @doc "Compares income/expenses for a month vs the previous month and same month last year."
  def trend_analysis(%Profile{} = profile, year, month) do
    current_income = resolve_income_for_month(profile, year, month)
    current_expenses = resolve_expenses_for_month(profile, year, month)

    {prev_year, prev_month} = prev_month(year, month)
    prev_income = resolve_income_for_month(profile, prev_year, prev_month)
    prev_expenses = resolve_expenses_for_month(profile, prev_year, prev_month)

    last_year_income = resolve_income_for_month(profile, year - 1, month)
    last_year_expenses = resolve_expenses_for_month(profile, year - 1, month)

    %{
      current: %{income: current_income, expenses: current_expenses, balance: Decimal.sub(current_income, current_expenses)},
      vs_prev_month: %{
        income_change: pct_change(prev_income, current_income),
        expense_change: pct_change(prev_expenses, current_expenses)
      },
      vs_last_year: %{
        income_change: pct_change(last_year_income, current_income),
        expense_change: pct_change(last_year_expenses, current_expenses)
      }
    }
  end

  @doc "Rolling average expense per category over the last `window` months (default 6)."
  def rolling_expense_averages(%Profile{} = profile, year, month, window \\ 6) do
    months = for i <- 0..(window - 1) do
      {y, m} = subtract_months(year, month, i)
      {y, m}
    end

    categories =
      ExpenseCategory
      |> where(profile_id: ^profile.id)
      |> Repo.all()

    Enum.map(categories, fn category ->
      totals =
        Enum.map(months, fn {y, m} ->
          profile
          |> expense_breakdown_for_month(y, m)
          |> Enum.filter(fn {type, _} -> type.expense_category_id == category.id end)
          |> Enum.reduce(Decimal.new(0), fn {_, amt}, acc -> Decimal.add(acc, amt) end)
        end)

      sum = Enum.reduce(totals, Decimal.new(0), &Decimal.add/2)
      avg = if window > 0, do: Decimal.div(sum, window) |> Decimal.round(2), else: Decimal.new(0)
      {category, avg}
    end)
    |> Enum.reject(fn {_, avg} -> Decimal.eq?(avg, 0) end)
    |> Enum.sort_by(fn {_, avg} -> Decimal.to_float(avg) end, :desc)
  end

  @doc "Income-to-expense ratio for each month of the year. nil when no expenses."
  def income_expense_ratio_over_year(%Profile{} = profile, year) do
    Enum.map(1..12, fn month ->
      income = resolve_income_for_month(profile, year, month)
      expenses = resolve_expenses_for_month(profile, year, month)

      ratio =
        if Decimal.gt?(expenses, 0) do
          Decimal.div(income, expenses) |> Decimal.round(2)
        else
          nil
        end

      %{month: month, ratio: ratio, income: income, expenses: expenses}
    end)
  end

  defp prev_month(year, 1), do: {year - 1, 12}
  defp prev_month(year, month), do: {year, month - 1}

  defp subtract_months(year, month, 0), do: {year, month}
  defp subtract_months(year, month, n) do
    {y, m} = prev_month(year, month)
    subtract_months(y, m, n - 1)
  end

  defp pct_change(old, new) do
    if Decimal.gt?(old, 0) do
      Decimal.sub(new, old)
      |> Decimal.div(old)
      |> Decimal.mult(100)
      |> Decimal.round(1)
    else
      nil
    end
  end

  ## Forecasting & Planning

  @doc "Projects cash flow for the next `months_ahead` months using recurring base amounts."
  def project_cash_flow(%Profile{} = profile, months_ahead, overrides \\ %{}) do
    today = Date.utc_today()

    income_sources =
      IncomeSource
      |> where(profile_id: ^profile.id, recurrence: :monthly)
      |> where([s], not is_nil(s.base_amount))
      |> Repo.all()

    expense_types =
      ExpenseType
      |> where(profile_id: ^profile.id, recurrence: :monthly)
      |> where([t], not is_nil(t.base_amount))
      |> Repo.all()

    Enum.map(1..months_ahead, fn offset ->
      {year, month} = advance_months(today.year, today.month, offset)

      projected_income =
        income_sources
        |> Enum.filter(fn s -> Map.get(overrides, {:income, s.id}, true) end)
        |> Enum.reduce(Decimal.new(0), fn s, acc ->
          amount = Map.get(overrides, {:income_amount, s.id}, s.base_amount)
          Decimal.add(acc, amount)
        end)

      projected_expenses =
        expense_types
        |> Enum.filter(fn t -> Map.get(overrides, {:expense, t.id}, true) end)
        |> Enum.reduce(Decimal.new(0), fn t, acc ->
          amount = Map.get(overrides, {:expense_amount, t.id}, t.base_amount)
          Decimal.add(acc, amount)
        end)

      balance = Decimal.sub(projected_income, projected_expenses)

      %{year: year, month: month, income: projected_income, expenses: projected_expenses, balance: balance}
    end)
  end

  @doc "Lists all recurring income sources for a profile (for what-if toggles)."
  def list_recurring_income_sources(%Profile{} = profile) do
    IncomeSource
    |> where(profile_id: ^profile.id, recurrence: :monthly)
    |> where([s], not is_nil(s.base_amount))
    |> order_by(asc: :name)
    |> preload(:income_category)
    |> Repo.all()
  end

  @doc "Lists all recurring expense types for a profile (for what-if toggles)."
  def list_recurring_expense_types(%Profile{} = profile) do
    ExpenseType
    |> where(profile_id: ^profile.id, recurrence: :monthly)
    |> where([t], not is_nil(t.base_amount))
    |> order_by(asc: :name)
    |> preload(:expense_category)
    |> Repo.all()
  end

  defp advance_months(year, month, offset) do
    total = (year * 12 + month - 1) + offset
    {div(total, 12), rem(total, 12) + 1}
  end

  ## Budget overrides

  @doc "Resolves the effective budget limit for a category in a given month (override > global)."
  def get_budget_for_month(%ExpenseCategory{} = category, year, month) do
    override =
      BudgetOverride
      |> where(expense_category_id: ^category.id, year: ^year, month: ^month)
      |> Repo.one()

    case override do
      %BudgetOverride{limit: limit} -> limit
      nil -> category.budget_limit
    end
  end

  @doc "Lists all budget overrides for a category, newest first."
  def list_budget_overrides(%ExpenseCategory{} = category) do
    BudgetOverride
    |> where(expense_category_id: ^category.id)
    |> order_by(desc: :year, desc: :month)
    |> Repo.all()
  end

  @doc "Creates a per-month budget override for a category."
  def create_budget_override(%ExpenseCategory{} = category, attrs) do
    %BudgetOverride{expense_category_id: category.id}
    |> BudgetOverride.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a budget override."
  def update_budget_override(%BudgetOverride{} = override, attrs) do
    override
    |> BudgetOverride.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a budget override."
  def delete_budget_override(%BudgetOverride{} = override) do
    Repo.delete(override)
  end

  @doc "Returns a changeset for tracking budget override changes."
  def change_budget_override(%BudgetOverride{} = override, attrs \\ %{}) do
    BudgetOverride.changeset(override, attrs)
  end

  @doc "Returns `[{category, %{limit, spent, percentage}}]` for all budgeted categories in a month."
  def budget_status_for_month(%Profile{} = profile, year, month) do
    categories =
      ExpenseCategory
      |> where(profile_id: ^profile.id)
      |> Repo.all()

    breakdown = expense_breakdown_for_month(profile, year, month)
    spent_by_category =
      Enum.reduce(breakdown, %{}, fn {type, amount}, acc ->
        Map.update(acc, type.expense_category_id, amount, &Decimal.add(&1, amount))
      end)

    Enum.flat_map(categories, fn category ->
      budget = get_budget_for_month(category, year, month)
      case budget do
        nil -> []
        limit ->
          spent = Map.get(spent_by_category, category.id, Decimal.new(0))
          pct = if Decimal.gt?(limit, 0), do: Decimal.div(spent, limit) |> Decimal.mult(100) |> Decimal.round(1), else: Decimal.new(0)
          [{category, %{limit: limit, spent: spent, percentage: pct}}]
      end
    end)
  end

  ## Savings goals

  @doc "Lists all savings goals for a profile, ordered by deadline, with contributions preloaded."
  def list_savings_goals(%Profile{} = profile) do
    SavingsGoal
    |> where(profile_id: ^profile.id)
    |> order_by(asc: :deadline)
    |> preload(contributions: ^from(c in SavingsContribution, order_by: [desc: c.year, desc: c.month]))
    |> Repo.all()
  end

  @doc "Fetches a savings goal belonging to the profile. Raises if not found."
  def get_savings_goal!(%Profile{} = profile, id) do
    SavingsGoal
    |> where(profile_id: ^profile.id)
    |> Repo.get!(id)
    |> Repo.preload(contributions: from(c in SavingsContribution, order_by: [desc: c.year, desc: c.month]))
  end

  @doc "Creates a savings goal for a profile."
  def create_savings_goal(%Profile{} = profile, attrs) do
    %SavingsGoal{profile_id: profile.id}
    |> SavingsGoal.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a savings goal."
  def update_savings_goal(%SavingsGoal{} = goal, attrs) do
    goal
    |> SavingsGoal.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a savings goal and all its contributions."
  def delete_savings_goal(%SavingsGoal{} = goal) do
    Repo.delete(goal)
  end

  @doc "Returns a changeset for tracking savings goal changes."
  def change_savings_goal(%SavingsGoal{} = goal, attrs \\ %{}) do
    SavingsGoal.changeset(goal, attrs)
  end

  ## Savings contributions

  @doc "Creates a manual contribution toward a savings goal."
  def create_savings_contribution(%SavingsGoal{} = goal, attrs) do
    %SavingsContribution{savings_goal_id: goal.id}
    |> SavingsContribution.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Fetches a contribution belonging to the savings goal. Raises if not found."
  def get_savings_contribution!(%SavingsGoal{} = goal, id) do
    SavingsContribution
    |> where(savings_goal_id: ^goal.id)
    |> Repo.get!(id)
  end

  @doc "Updates a savings contribution."
  def update_savings_contribution(%SavingsContribution{} = contribution, attrs) do
    contribution
    |> SavingsContribution.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a savings contribution."
  def delete_savings_contribution(%SavingsContribution{} = contribution) do
    Repo.delete(contribution)
  end

  @doc "Returns a changeset for tracking savings contribution changes."
  def change_savings_contribution(%SavingsContribution{} = contribution, attrs \\ %{}) do
    SavingsContribution.changeset(contribution, attrs)
  end

  @doc "Computes progress toward a savings goal: saved, remaining, percentage, months left, required monthly."
  def savings_goal_progress(%SavingsGoal{} = goal, %Profile{} = profile) do
    saved =
      case goal.tracking_mode do
        :manual ->
          goal.contributions
          |> Enum.reduce(Decimal.new(0), fn c, acc -> Decimal.add(acc, c.amount) end)

        :auto ->
          today = Date.utc_today()
          months_data = annual_summary(profile, today.year)
          months_data
          |> Enum.filter(& &1.tracked)
          |> Enum.reduce(Decimal.new(0), fn %{balance: b}, acc ->
            if Decimal.gt?(b, 0), do: Decimal.add(acc, b), else: acc
          end)
      end

    remaining = Decimal.sub(goal.target_amount, saved) |> Decimal.max(Decimal.new(0))
    today = Date.utc_today()
    months_left = months_until(today, goal.deadline)

    required_monthly =
      if months_left > 0 and Decimal.gt?(remaining, 0) do
        Decimal.div(remaining, months_left) |> Decimal.round(2)
      else
        Decimal.new(0)
      end

    pct =
      if Decimal.gt?(goal.target_amount, 0) do
        Decimal.div(saved, goal.target_amount) |> Decimal.mult(100) |> Decimal.round(1)
      else
        Decimal.new(0)
      end

    %{
      saved: saved,
      remaining: remaining,
      percentage: pct,
      months_left: months_left,
      required_monthly: required_monthly
    }
  end

  ## Pin/unpin categories

  @doc "Toggles the pinned status of an income category."
  def toggle_pin_income_category(%IncomeCategory{} = category) do
    category
    |> IncomeCategory.changeset(%{pinned: !category.pinned})
    |> Repo.update()
  end

  @doc "Toggles the pinned status of an expense category."
  def toggle_pin_expense_category(%ExpenseCategory{} = category) do
    category
    |> ExpenseCategory.changeset(%{pinned: !category.pinned})
    |> Repo.update()
  end

  ## Notes search

  @doc "Searches income and expense entries by note text within a profile."
  def search_entries_by_note(%Profile{} = profile, query) when is_binary(query) and query != "" do
    pattern = "%#{query}%"

    income_entries =
      from(e in IncomeEntry,
        join: s in IncomeSource, on: e.income_source_id == s.id,
        join: c in IncomeCategory, on: s.income_category_id == c.id,
        where: s.profile_id == ^profile.id and ilike(e.note, ^pattern),
        select: %{type: "income", category: c.name, name: s.name, year: e.year, month: e.month, amount: e.amount, note: e.note}
      )
      |> Repo.all()

    expense_entries =
      from(e in ExpenseEntry,
        join: t in ExpenseType, on: e.expense_type_id == t.id,
        join: c in ExpenseCategory, on: t.expense_category_id == c.id,
        where: t.profile_id == ^profile.id and ilike(e.note, ^pattern),
        select: %{type: "expense", category: c.name, name: t.name, year: e.year, month: e.month, amount: e.amount, note: e.note}
      )
      |> Repo.all()

    (income_entries ++ expense_entries)
    |> Enum.sort_by(fn e -> {e.year, e.month} end, :desc)
  end

  def search_entries_by_note(%Profile{}, _query), do: []

  ## Quick entry

  @doc "Creates a sporadic expense entry in one step: finds or creates category and type, then inserts entry."
  def quick_expense_entry(%Profile{} = profile, category_name, type_name, amount, year, month, note \\ nil) do
    Repo.transaction(fn ->
      category = find_or_create_expense_category!(profile, category_name)
      type = find_or_create_expense_type!(profile, category, type_name)

      {:ok, entry} = create_expense_entry(type, %{
        "year" => year, "month" => month,
        "amount" => amount, "note" => note
      })

      entry
    end)
  end

  ## Recurring calendar

  @doc "Returns a map of month => list of types/sources with gaps (months missing entries) for a year."
  def recurring_calendar(%Profile{} = profile, year) do
    income_sources =
      IncomeSource
      |> where(profile_id: ^profile.id, recurrence: :monthly)
      |> Repo.all()

    expense_types =
      ExpenseType
      |> where(profile_id: ^profile.id, recurrence: :monthly)
      |> Repo.all()

    income_entries =
      IncomeEntry
      |> where([e], e.income_source_id in ^Enum.map(income_sources, & &1.id) and e.year == ^year)
      |> Repo.all()

    expense_entries =
      ExpenseEntry
      |> where([e], e.expense_type_id in ^Enum.map(expense_types, & &1.id) and e.year == ^year)
      |> Repo.all()

    income_gaps =
      for source <- income_sources, month <- 1..12 do
        has_override = Enum.any?(income_entries, &(&1.income_source_id == source.id && &1.month == month))
        if !has_override && source.base_amount != nil, do: nil, else: {source.name, :income, month, has_override}
      end
      |> Enum.reject(&is_nil/1)

    expense_gaps =
      for type <- expense_types, month <- 1..12 do
        has_override = Enum.any?(expense_entries, &(&1.expense_type_id == type.id && &1.month == month))
        if !has_override && type.base_amount != nil, do: nil, else: {type.name, :expense, month, has_override}
      end
      |> Enum.reject(&is_nil/1)

    %{income: income_gaps, expense: expense_gaps, income_sources: income_sources, expense_types: expense_types}
  end

  defp months_until(from_date, to_date) do
    (to_date.year * 12 + to_date.month) - (from_date.year * 12 + from_date.month)
    |> max(0)
  end

  # Shared by income/expense resolution: map source_id => entry for the month.
  defp entries_by_source(schema, sources, year, month) do
    source_ids = Enum.map(sources, & &1.id)
    fk = if schema == IncomeEntry, do: :income_source_id, else: :expense_type_id

    schema
    |> where([e], field(e, ^fk) in ^source_ids and e.year == ^year and e.month == ^month)
    |> Repo.all()
    |> Map.new(fn entry -> {Map.get(entry, fk), entry} end)
  end

  # Resolves one source's amount for a month given an optional override entry.
  defp resolve_amount(source, entry) do
    cond do
      entry != nil -> entry.amount
      source.recurrence == :monthly -> source.base_amount
      true -> nil
    end
  end
end
