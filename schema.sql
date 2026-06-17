-- ============================================================
-- KFC LIVE LEADERBOARD — Supabase Schema
-- Run this entire file in the Supabase SQL Editor
-- ============================================================

-- Sequence for auto-assigning unique player numbers
CREATE SEQUENCE IF NOT EXISTS public.player_number_seq
  START WITH 1 INCREMENT BY 1 NO MAXVALUE;

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email         TEXT        NOT NULL,
  username      TEXT        UNIQUE,
  display_name  TEXT        NOT NULL DEFAULT '',
  player_number INTEGER     UNIQUE,
  role          TEXT        NOT NULL DEFAULT 'player' CHECK (role IN ('player','admin')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.match_stats (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  date             DATE        NOT NULL,
  goals            INTEGER     NOT NULL DEFAULT 0 CHECK (goals >= 0 AND goals <= 100),
  assists          INTEGER     NOT NULL DEFAULT 0 CHECK (assists >= 0 AND assists <= 100),
  motm             BOOLEAN     NOT NULL DEFAULT FALSE,
  status           TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  submitted_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  approved_at      TIMESTAMPTZ,
  rejection_reason TEXT,
  CONSTRAINT unique_player_date UNIQUE (user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_stats_user   ON public.match_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_stats_status ON public.match_stats(status);
CREATE INDEX IF NOT EXISTS idx_stats_date   ON public.match_stats(date);

-- ============================================================
-- LEADERBOARD VIEW (public, no email)
-- ============================================================
CREATE OR REPLACE VIEW public.leaderboard_view AS
SELECT
  p.id,
  p.display_name,
  p.player_number,
  COUNT(ms.id)::integer                                             AS matches_played,
  COALESCE(SUM(ms.goals),    0)::integer                           AS total_goals,
  COALESCE(SUM(ms.assists),  0)::integer                           AS total_assists,
  (COALESCE(SUM(ms.goals),0)+COALESCE(SUM(ms.assists),0))::integer AS total_ga,
  COUNT(CASE WHEN ms.motm = TRUE THEN 1 END)::integer              AS total_motm
FROM public.profiles p
LEFT JOIN public.match_stats ms
  ON p.id = ms.user_id AND ms.status = 'approved'
WHERE p.role = 'player'
GROUP BY p.id, p.display_name, p.player_number;

GRANT SELECT ON public.leaderboard_view TO anon, authenticated;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.profiles   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_stats ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (safe to re-run)
DO $$ BEGIN
  DROP POLICY IF EXISTS "profiles_public_read"   ON public.profiles;
  DROP POLICY IF EXISTS "profiles_own_update"    ON public.profiles;
  DROP POLICY IF EXISTS "profiles_insert"        ON public.profiles;
  DROP POLICY IF EXISTS "profiles_admin_all"     ON public.profiles;
  DROP POLICY IF EXISTS "stats_public_approved"  ON public.match_stats;
  DROP POLICY IF EXISTS "stats_own_read"         ON public.match_stats;
  DROP POLICY IF EXISTS "stats_own_insert"       ON public.match_stats;
  DROP POLICY IF EXISTS "stats_admin_all"        ON public.match_stats;
END $$;

-- PROFILES policies
CREATE POLICY "profiles_public_read" ON public.profiles
  FOR SELECT USING (TRUE);

CREATE POLICY "profiles_own_update" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "profiles_insert" ON public.profiles
  FOR INSERT WITH CHECK (TRUE);

CREATE POLICY "profiles_admin_all" ON public.profiles
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- MATCH_STATS policies
CREATE POLICY "stats_public_approved" ON public.match_stats
  FOR SELECT USING (status = 'approved');

CREATE POLICY "stats_own_read" ON public.match_stats
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "stats_own_insert" ON public.match_stats
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "stats_admin_all" ON public.match_stats
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ============================================================
-- GRANTS
-- ============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles    TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.match_stats TO authenticated;

-- ============================================================
-- TRIGGER: Auto-create profile on auth signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_name TEXT;
  v_role TEXT;
  v_num  INTEGER;
BEGIN
  v_name := COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email,'@',1));
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'player');
  IF v_role = 'player' THEN
    v_num := nextval('public.player_number_seq');
  END IF;
  INSERT INTO public.profiles (id, email, display_name, player_number, role)
  VALUES (NEW.id, NEW.email, v_name, v_num, v_role);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- FUNCTION: Resolve username → email (used for admin login)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_email_by_username(p_username TEXT)
RETURNS TEXT LANGUAGE sql SECURITY DEFINER AS $$
  SELECT email FROM public.profiles WHERE username = p_username LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION public.get_email_by_username TO anon, authenticated;

-- ============================================================
-- REALTIME (enables live leaderboard updates)
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.match_stats;

-- ============================================================
-- DONE. Next: follow README.md to create the admin account.
-- ============================================================
