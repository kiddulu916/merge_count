-- Phase 4: extended (weekly / monthly / all-time) leaderboards.
--
-- READ-ONLY. No new tables, no new writes. This migration adds a single
-- aggregation RPC over the EXISTING `scores` table. The trust model from
-- Phase 2 is unchanged: clients still cannot write `scores` (only the
-- submit-score Edge Function does). This is purely a new read path.
--
-- Aggregation = SUM of daily bests over the date range. `scores` already holds
-- exactly one best row per (player, utc_date, difficulty) (enforced by the
-- unique constraint in 0001), so a plain SUM over the range IS the sum of daily
-- bests — rewarding consistency across the period rather than a single peak day.
--
-- The existing index idx_scores_board (utc_date, difficulty, score desc) covers
-- the (utc_date, difficulty) range scan this query performs.

create or replace function leaderboard_period(
  p_diff text,
  p_from date,
  p_to date
)
returns table(rank bigint, display_name text, total int, is_me boolean)
language sql stable security invoker as $$
  select rank() over (order by sum(s.score) desc) as rank,
         p.display_name,
         sum(s.score)::int as total,
         bool_or(s.player_id = auth.uid()) as is_me
  from scores s
  join players p on p.id = s.player_id
  where s.difficulty = p_diff
    and s.utc_date between p_from and p_to
  group by p.id, p.display_name
  order by total desc;
$$;

grant execute on function leaderboard_period(text, date, date) to anon, authenticated;
