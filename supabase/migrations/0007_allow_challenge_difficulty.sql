-- Allow 'challenge' in scores.difficulty.
--
-- Migration 0001 defined the check constraint before the challenge tier existed.
-- The submit-score Edge Function correctly submits challenge runs (the function
-- already calls verifyRunChallenge and writes difficulty = 'challenge'), but the
-- insert fails with a check-constraint violation, so challenge scores are silently
-- dropped and never appear on the leaderboard.
--
-- Fix: widen the check constraint to include 'challenge'. The constraint is
-- unnamed (auto-named by Postgres as scores_difficulty_check), so we drop and
-- recreate it. No data migration needed -- no 'challenge' rows exist yet.

alter table scores
  drop constraint if exists scores_difficulty_check;

alter table scores
  add constraint scores_difficulty_check
  check (difficulty in ('easy', 'medium', 'hard', 'legendary', 'challenge'));
