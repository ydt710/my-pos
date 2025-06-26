-- =============================================
-- MIGRATION: Fix debt created stats for week/month/year to only count unpaid debt
-- =============================================
-- This migration updates get_debt_created_stats to ensure all periods only count
-- actual unpaid debt (user still has negative balance), not all sales.
-- =============================================

DROP FUNCTION IF EXISTS public.get_debt_created_stats() CASCADE;

CREATE OR REPLACE FUNCTION public.get_debt_created_stats()
RETURNS json
LANGUAGE plpgsql
AS $$
DECLARE
    time_boundaries RECORD;
BEGIN
    SELECT
        date_trunc('day', now() at time zone 'utc') AS today_start,
        date_trunc('week', now() at time zone 'utc') AS week_start,
        date_trunc('month', now() at time zone 'utc') AS month_start,
        date_trunc('year', now() at time zone 'utc') AS year_start
    INTO time_boundaries;

    RETURN (
        SELECT json_build_object(
            'today', COALESCE(SUM(ABS(t.balance_amount)) FILTER (
                WHERE t.created_at >= time_boundaries.today_start 
                AND t.category IN ('pos_sale', 'online_sale', 'debit_adjustment')
                AND t.balance_amount < 0
                AND EXISTS (
                    SELECT 1 FROM public.user_balances p 
                    WHERE p.user_id = t.user_id AND p.balance < 0
                )
            ), 0),
            'week', COALESCE(SUM(ABS(t.balance_amount)) FILTER (
                WHERE t.created_at >= time_boundaries.week_start 
                AND t.category IN ('pos_sale', 'online_sale', 'debit_adjustment')
                AND t.balance_amount < 0
                AND EXISTS (
                    SELECT 1 FROM public.user_balances p 
                    WHERE p.user_id = t.user_id AND p.balance < 0
                )
            ), 0),
            'month', COALESCE(SUM(ABS(t.balance_amount)) FILTER (
                WHERE t.created_at >= time_boundaries.month_start 
                AND t.category IN ('pos_sale', 'online_sale', 'debit_adjustment')
                AND t.balance_amount < 0
                AND EXISTS (
                    SELECT 1 FROM public.user_balances p 
                    WHERE p.user_id = t.user_id AND p.balance < 0
                )
            ), 0),
            'year', COALESCE(SUM(ABS(t.balance_amount)) FILTER (
                WHERE t.created_at >= time_boundaries.year_start 
                AND t.category IN ('pos_sale', 'online_sale', 'debit_adjustment')
                AND t.balance_amount < 0
                AND EXISTS (
                    SELECT 1 FROM public.user_balances p 
                    WHERE p.user_id = t.user_id AND p.balance < 0
                )
            ), 0),
            'all_time', COALESCE(SUM(ABS(t.balance_amount)) FILTER (
                WHERE t.category IN ('pos_sale', 'online_sale', 'debit_adjustment')
                AND t.balance_amount < 0
                AND EXISTS (
                    SELECT 1 FROM public.user_balances p 
                    WHERE p.user_id = t.user_id AND p.balance < 0
                )
            ), 0)
        )
        FROM public.transactions t
    );
END;
$$; 