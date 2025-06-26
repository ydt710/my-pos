-- =============================================
-- MIGRATION: Fix debt created vs paid and debt over time chart functions to use user_balances
-- =============================================
-- This migration updates get_debt_created_vs_paid and get_debt_over_time to use the user_balances view
-- instead of the profiles table for checking negative balances.
-- =============================================

DROP FUNCTION IF EXISTS public.get_debt_created_vs_paid(text) CASCADE;
DROP FUNCTION IF EXISTS public.get_debt_over_time(text, timestamptz, timestamptz) CASCADE;

CREATE OR REPLACE FUNCTION public.get_debt_created_vs_paid(filter_option text)
RETURNS TABLE(period timestamptz, debt_created numeric, debt_paid numeric)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        time_series.period::timestamptz,
        COALESCE(SUM(CASE WHEN t.category IN ('pos_sale', 'online_sale', 'debit_adjustment') 
                          AND t.balance_amount < 0
                          AND EXISTS (
                              SELECT 1 FROM public.user_balances p 
                              WHERE p.user_id = t.user_id AND p.balance < 0
                          )
                          THEN ABS(t.balance_amount) ELSE 0 END), 0) AS debt_created,
        COALESCE(SUM(CASE WHEN t.category = 'debt_payment' THEN t.balance_amount ELSE 0 END), 0) AS debt_paid
    FROM
        (SELECT generate_series(
            date_trunc(
                CASE WHEN filter_option = 'today' THEN 'hour' ELSE 'day' END,
                (CASE
                    WHEN filter_option = 'today' THEN now()
                    WHEN filter_option = 'week' THEN date_trunc('week', now())
                    WHEN filter_option = 'month' THEN date_trunc('month', now())
                    WHEN filter_option = 'year' THEN date_trunc('year', now())
                    ELSE now() - interval '1 year'
                END)
            ),
            now(),
            (CASE WHEN filter_option = 'today' THEN '1 hour' ELSE '1 day' END)::interval
        ) AS period) AS time_series
    LEFT JOIN
        public.transactions t ON date_trunc(CASE WHEN filter_option = 'today' THEN 'hour' ELSE 'day' END, t.created_at) = time_series.period
    GROUP BY
        time_series.period
    ORDER BY
        time_series.period;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_debt_over_time(p_period text, p_start_date timestamptz, p_end_date timestamptz)
RETURNS TABLE (period timestamptz, debt numeric)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        gs.period_start as period,
        COALESCE(SUM(ABS(t.balance_amount)), 0) AS debt
    FROM
        generate_series(
            date_trunc(p_period, p_start_date),
            p_end_date,
            ('1 ' || p_period)::interval
        ) AS gs(period_start)
    LEFT JOIN
        public.transactions t ON date_trunc(p_period, t.created_at) = gs.period_start
                             AND t.category IN ('pos_sale', 'online_sale', 'debit_adjustment')
                             AND t.balance_amount < 0
                             AND EXISTS (
                                 SELECT 1 FROM public.user_balances p 
                                 WHERE p.user_id = t.user_id AND p.balance < 0
                             )
    GROUP BY
        gs.period_start
    ORDER BY
        gs.period_start;
END;
$$ LANGUAGE plpgsql; 