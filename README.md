# KFC Live Leaderboard

A live, self-updating football/futsal leaderboard with player login, stats submission (with admin approval), and a full admin panel.

---

## Quick Setup (5 Steps)

### Step 1 — Create a Supabase Project
1. Go to [supabase.com](https://supabase.com) → New Project
2. Choose a name (e.g. `kfc-leaderboard`), a strong database password, and your region
3. Wait ~1 min for provisioning

### Step 2 — Run the Database Schema
1. In your Supabase dashboard → **SQL Editor → New query**
2. Paste the entire contents of **`schema.sql`** and click **Run**
3. You should see "Success. No rows returned."

### Step 3 — Create the Admin Account
1. In Supabase → **Authentication → Users → Add user → Create new user**
2. Email: `ms7goat@kfc-leaderboard.app` (or any email you like)
3. Password: `bakri69`
4. Click **Create User**
5. Now go back to **SQL Editor** and run this snippet:

```sql
UPDATE public.profiles
SET role = 'admin', username = 'ms7goat', display_name = 'Admin'
WHERE email = 'ms7goat@kfc-leaderboard.app';
```

> The admin can now log in using username `ms7goat` + password `bakri69` (or with the email directly).

### Step 4 — Add Supabase Credentials to the App
1. In Supabase → **Project Settings → API**
2. Copy your **Project URL** and **anon public** key
3. Open `index.html` and find these two lines near the top of the `<script>` block:

```javascript
const SUPABASE_URL      = 'YOUR_SUPABASE_URL_HERE';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY_HERE';
```

4. Replace the placeholder strings with your real values

### Step 5 — Deploy
The site is already deployed on GitHub Pages. After updating `index.html` with credentials, commit and push to the `main` branch. GitHub Pages will auto-redeploy within ~1 minute.

---

## Adding a Logo
Upload your logo file as `logo.png` to the repo root. It will automatically appear in the top-left nav bar. If no logo file is found, the "KFC" text badge is shown as a fallback.

---

## Features

### Public (no login required)
- 🏆 **Season Standings** — full leaderboard sorted by G+A
- ⚽ **Top Scorers** — ranked by goals
- 🎯 **Top Assisters** — ranked by assists
- ⭐ **Top MOTM** — ranked by Man of the Match awards
- 📅 **Monthly Stats** — per-month top scorer/assister/MOTM selector
- 🔴 **Live updates** — leaderboard refreshes automatically via Supabase real-time

### Player (login required)
- Create a permanent account with email + password + display name
- Player number is auto-assigned on signup (sequential, unique)
- Submit match stats: Goals (0–100), Assists (0–100), MOTM toggle
- One submission per calendar day (duplicate protection)
- View own submission history with approval status
- "Remember me" session persistence

### Admin (`ms7goat` / `bakri69`)
- Approval queue — approve or reject pending submissions individually
- Player management — edit display names, player numbers, view match history
- Manually add/backdate entries (for importing legacy data)
- Delete any individual entry
- All changes reflect on the leaderboard instantly

---

## Data Model

| Table | Key columns |
|-------|-------------|
| `profiles` | `id`, `email`, `username`, `display_name`, `player_number`, `role` |
| `match_stats` | `id`, `user_id`, `date`, `goals`, `assists`, `motm`, `status`, `submitted_at` |
| `leaderboard_view` | computed view — aggregates approved stats per player |

Leaderboard totals are always derived live from approved `match_stats` rows — no stale stored totals.
