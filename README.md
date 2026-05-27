<div align="center">

# IDCAL — It Does Cost A Lot

### _Track your finances with clarity_

A multi-user personal finance tracker with a **modern fintech aesthetic**.

![Elixir](https://img.shields.io/badge/Elixir-4B275F?style=for-the-badge&logo=elixir&logoColor=white)
![Phoenix](https://img.shields.io/badge/Phoenix_LiveView-FD4F00?style=for-the-badge&logo=phoenix-framework&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-336791?style=for-the-badge&logo=postgresql&logoColor=white)
![Tailwind](https://img.shields.io/badge/Tailwind_CSS-06B6D4?style=for-the-badge&logo=tailwindcss&logoColor=white)
![Chart.js](https://img.shields.io/badge/Chart.js-FF6384?style=for-the-badge&logo=chartdotjs&logoColor=white)

</div>

---

## The Idea

Most finance apps are either cold spreadsheets or overly complex. IDCAL keeps it simple — track income and expenses across months, see where your money goes, and plan ahead.

At its heart, one equation — computed live, never stored:

```
Monthly Balance  =  Σ Income (month)  −  Σ Expenses (month)
```

Both income and expenses can be **recurring monthly** (a base amount with optional per-month overrides) or **sporadic** (counted only when an explicit entry exists). The database is the single source of truth.

---

## Features

| | Feature | Description |
|---|---|---|
| | **Authentication** | Register, log in, log out — email + password via `phx.gen.auth` |
| | **Multiple Profiles** | Keep separate profiles per account (Personal, Freelance, etc.) |
| | **Income Tracking** | Categories → Sources → Entries, monthly or sporadic |
| | **Expense Tracking** | Categories → Types → Entries, same flexible model |
| | **Monthly Summary** | Income & expense breakdowns with colour-coded net balance |
| | **Annual Dashboard** | 12-month cards, bar charts, cumulative balance line chart |
| | **Category Breakdown** | Donut charts to see where your money goes |
| | **Real-time** | All updates in-page via Phoenix LiveView — no reloads |
| | **Bilingual** | English (en-US) & Brazilian Portuguese (pt-BR), switchable anytime |

---

## Design System

<table>
<tr>
<td>

**Color Palette**

| Role | Hex |
|---|---|
| Page Background | `#F8F7F5` |
| Cards | `#FFFFFF` |
| Brand | `#A31F34` |
| Text | `#1A1A1A` |
| Income | `#1D9E75` |
| Expenses | `#E24B4A` |
| Warning | `#BA7517` |

</td>
<td>

**Typography**

| Use | Font |
|---|---|
| UI text | `Inter` |
| Numbers / amounts | Serif |

**UI Vibe**
- Light, clean, modern
- White cards on warm off-white
- Subtle shadows for depth
- MIT Red brand accents

</td>
</tr>
</table>

---

## Architecture

```
User
 └── Profile
      ├── IncomeCategory
      │    └── IncomeSource (monthly / sporadic)
      │         └── IncomeEntry (per-month override or one-time)
      └── ExpenseCategory
           └── ExpenseType (monthly / sporadic)
                └── ExpenseEntry (per-month override or one-time)
```

> All financial data is scoped to a **Profile**, not directly to a User.
> Balances are always **computed dynamically** — nothing is cached or stored.

---

## Tech Stack

| Layer | Technology | Why |
|---|---|---|
| Language | **Elixir** | Functional, fault-tolerant, beautiful |
| Framework | **Phoenix LiveView** | Fullstack, real-time, no JS frontend |
| Database | **PostgreSQL** | Rock-solid relational store |
| Styling | **Tailwind CSS** | Utility-first + custom fintech theme |
| Auth | **phx.gen.auth** | Built-in Phoenix auth generator |
| Charts | **Chart.js** | Rendered via LiveView JS hooks |
| i18n | **Gettext** | en-US / pt-BR with runtime switching |
| Fonts | **Google Fonts** | Inter + serif for numbers |

---

## Getting Started

**Prerequisites:** Elixir, Erlang/OTP, and a running PostgreSQL server.

```bash
# Clone the repository
git clone https://github.com/Rodericuss/itdoescostalot-modern.git
cd itdoescostalot-modern

# Install dependencies + set up database
mix setup

# Start the development server
mix phx.server
```

Then visit **[`localhost:4000`](http://localhost:4000)**, register an account, and create your first profile.

### Other Commands

```bash
mix test           # Run the test suite
mix ecto.migrate   # Run pending migrations
```

---

## Page Map

| Route | Page | Description |
|---|---|---|
| `/register` | Registration | Create an account |
| `/log_in` | Login | Log in |
| `/profiles` | Profile Selection | Grid of profile cards |
| `/profiles/new` | Create Profile | Nickname form |
| `/profiles/:id` | Annual Dashboard | 12-month overview + charts |
| `/profiles/:id/income` | Income Management | Categories → Sources → Entries |
| `/profiles/:id/expenses` | Expense Management | Categories → Types → Entries |
| `/profiles/:id/month/:y/:m` | Monthly Detail | Breakdown tables + donut chart |

---

## Roadmap

| Phase | Status | Milestone |
|---|---|---|
| 1 — Foundation | Done | Phoenix app + auth + visual shell |
| 2 — Profiles | Done | Multi-profile CRUD |
| 3 — Income | Done | Full income management |
| 4 — Expenses | Done | Full expense management |
| 5 — Monthly View | Done | Detailed month breakdown + charts |
| 6 — Annual Dashboard | Done | 12-month overview + bar/line charts |
| 7 — Polish & UX | Done | Validation, responsive, empty states |
| 8 — i18n | Done | en-US / pt-BR bilingual support |
| 9 — Budgeting & Goals | Done | Budget targets + savings goals |
| 10 — Insights & Analytics | Done | Trends, averages, category drilldown |
| 11 — Forecasting | Done | Cash flow projection + "what if" scenarios |
| 12 — Data Management | Done | CSV export/import, templates, month cloning |
| 13 — Notifications | Done | Monthly reminders + budget alerts |
| 14 — Multi-user | Done | Shared profiles + profile comparison |
| 15 — UX Enhancements | Done | Quick entry, search, calendar, themes, multi-currency |

---

## License

Released under the [MIT License](LICENSE) — free for open-source and commercial use.

---

<div align="center">

**Built with Elixir**

</div>
