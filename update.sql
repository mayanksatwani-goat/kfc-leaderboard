-- ============================================================
-- KFC Leaderboard — Update: Saves, Tackles, Stat Overrides
-- Run this in Supabase SQL Editor
-- ============================================================

-- Add saves + tackles columns to match_stats
ALTER TABLE public.match_stats
  ADD COLUMN IF NOT EXISTS saves   INTEGER NOT NULL DEFAULT 0 CHECK (saves   >= 0 AND saves   <= 200),
  ADD COLUMN IF NOT EXISTS tackles INTEGER NOT NULL DEFAULT 0 CHECK (tackles >= 0 AND tackles <= 200);

-- ── Stat Overrides table (admin can directly set cumulative adjustments) ──
CREATE TABLE IF NOT EXISTS public.stat_overrides (
  user_id     UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  goals_adj   INTEGER NOT NULL DEFAULT 0,
  assists_adj INTEGER NOT NULL DEFAULT 0,
  saves_adj   INTEGER NOT NULL DEFAULT 0,
  tackles_adj INTEGER NOT NULL DEFAULT 0,
  motm_adj    INTEGER NOT NULL DEFAULT 0,
  matches_adj INTEGER NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.stat_overrides ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "overrides_public_read" ON public.stat_overrides;
DROP POLICY IF EXISTS "overrides_admin_all"   ON public.stat_overrides;

CREATE POLICY "overrides_public_read" ON public.stat_overrides FOR SELECT USING (TRUE);
CREATE POLICY "overrides_admin_all"   ON public.stat_overrides FOR ALL    USING (is_admin());

GRANT SELECT            ON public.stat_overrides TO anon;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.stat_overrides TO authenticated;

-- ── Rebuild leaderboard_view with saves, tackles, and override support ──
CREATE OR REPLACE VIEW public.leaderboard_view AS
SELECT
  p.id,
  p.display_name,
  p.player_number,
  (COUNT(ms.id)                                          + COALESCE(so.matches_adj,0))::integer AS matches_played,
  (COALESCE(SUM(ms.goals),   0)                          + COALESCE(so.goals_adj,  0))::integer AS total_goals,
  (COALESCE(SUM(ms.assists), 0)                          + COALESCE(so.assists_adj,0))::integer AS total_assists,
  (COALESCE(SUM(ms.goals),0)+COALESCE(SUM(ms.assists),0)+ COALESCE(so.goals_adj,0)+COALESCE(so.assists_adj,0))::integer AS total_ga,
  (COUNT(CASE WHEN ms.motm=TRUE THEN 1 END)              + COALESCE(so.motm_adj,   0))::integer AS total_motm,
  (COALESCE(SUM(ms.saves),   0)                          + COALESCE(so.saves_adj,  0))::integer AS total_saves,
  (COALESCE(SUM(ms.tackles), 0)                          + COALESCE(so.tackles_adj,0))::integer AS total_tackles
FROM public.profiles p
LEFT JOIN public.match_stats ms   ON p.id = ms.user_id AND ms.status = 'approved'
LEFT JOIN public.stat_overrides so ON p.id = so.user_id
WHERE p.role = 'player'
GROUP BY p.id, p.display_name, p.player_number,
         so.goals_adj, so.assists_adj, so.saves_adj, so.tackles_adj, so.motm_adj, so.matches_adj;

GRANT SELECT ON public.leaderboard_view TO anon, authenticated;
