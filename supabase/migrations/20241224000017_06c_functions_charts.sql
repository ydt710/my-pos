-- =============================================
-- EXPORT SCRIPT 06c: CHART FUNCTIONS
-- =============================================
-- This script creates chart and reporting functions.
-- =============================================

-- Drop existing chart functions with CASCADE
DROP FUNCTION IF EXISTS public.get_revenue_chart_data(text) CASCADE;
DROP FUNCTION IF EXISTS public.get_debt_created_vs_paid(text) CASCADE;
DROP FUNCTION IF EXISTS public.get_cash_collected_chart_data(text, timestamptz, timestamptz) CASCADE;
DROP FUNCTION IF EXISTS public.get_cash_paid_over_time(text, timestamptz, timestamptz) CASCADE;
DROP FUNCTION IF EXISTS public.get_credit_over_time(text, timestamptz, timestamptz) CASCADE;
DROP FUNCTION IF EXISTS public.get_debt_over_time(text, timestamptz, timestamptz) CASCADE;
DROP FUNCTION IF EXISTS public.get_total_spent_top_users(timestamptz, timestamptz, integer) CASCADE;

-- Chart Functions
CREATE OR REPLACE FUNCTION public.get_revenue_chart_data(filter_option text)
RETURNS TABLE(period timestamptz, revenue numeric)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        time_series.period,
        COALESCE(SUM(CASE WHEN t.category IN ('sale', 'pos_sale', 'online_sale') THEN ABS(t.balance_amount) ELSE 0 END), 0) AS revenue
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
            )::timestamptz,
            now()::timestamptz,
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
                    WHEN filter_option = 'today' THEN date_trunc('day', now())
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

CREATE OR REPLACE FUNCTION public.get_cash_collected_chart_data(p_period text, p_start_date timestamptz, p_end_date timestamptz)
RETURNS TABLE (period_start timestamptz, cash_collected numeric)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        gs.period_start,
        COALESCE(SUM(t.cash_amount), 0) AS cash_collected
    FROM
        generate_series(
            date_trunc(CASE WHEN p_period = 'day' THEN 'hour' ELSE p_period END, p_start_date),
            p_end_date,
            (CASE WHEN p_period = 'day' THEN '1 hour' ELSE '1 ' || p_period END)::interval
        ) AS gs(period_start)
    LEFT JOIN
        public.transactions t ON date_trunc(CASE WHEN p_period = 'day' THEN 'hour' ELSE p_period END, t.created_at) = gs.period_start
                             AND t.category IN ('debt_payment', 'cash_payment', 'overpayment_credit')
    GROUP BY
        gs.period_start
    ORDER BY
        gs.period_start;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_total_spent_top_users(p_start_date timestamptz, p_end_date timestamptz, p_limit integer)
RETURNS TABLE(user_id uuid, user_name text, total_spent numeric)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        prof.id as user_id,
        COALESCE(prof.display_name, prof.first_name || ' ' || prof.last_name, prof.email) as user_name,
        COALESCE(SUM(t.total_amount), 0) as total_spent
    FROM
        public.profiles prof
    JOIN
        public.transactions t ON prof.id = t.user_id
    WHERE
        t.category IN ('pos_sale', 'online_sale')
        AND t.created_at BETWEEN p_start_date AND p_end_date
    GROUP BY
        prof.id, prof.display_name, prof.first_name, prof.last_name, prof.email
    ORDER BY
        total_spent DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_cash_paid_over_time(p_period text, p_start_date timestamptz, p_end_date timestamptz)
RETURNS TABLE (period timestamptz, cash_paid numeric)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        gs.period_start as period,
        COALESCE(SUM(t.cash_amount), 0) AS cash_paid
    FROM
        generate_series(
            date_trunc(p_period, p_start_date),
            p_end_date,
            ('1 ' || p_period)::interval
        ) AS gs(period_start)
    LEFT JOIN
        public.transactions t ON date_trunc(p_period, t.created_at) = gs.period_start
                             AND t.category = 'debt_payment'
    GROUP BY
        gs.period_start
    ORDER BY
        gs.period_start;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_credit_over_time(p_period text, p_start_date timestamptz, p_end_date timestamptz)
RETURNS TABLE (period timestamptz, credit numeric)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        gs.period_start as period,
        COALESCE(SUM(t.balance_amount), 0) AS credit
    FROM
        generate_series(
            date_trunc(CASE WHEN p_period = 'day' THEN 'hour' ELSE p_period END, p_start_date),
            p_end_date,
            (CASE WHEN p_period = 'day' THEN '1 hour' ELSE '1 ' || p_period END)::interval
        ) AS gs(period_start)
    LEFT JOIN
        public.transactions t ON date_trunc(CASE WHEN p_period = 'day' THEN 'hour' ELSE p_period END, t.created_at) = gs.period_start
                             AND t.category = 'overpayment_credit'
    GROUP BY
        gs.period_start
    ORDER BY
        gs.period_start;
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
            date_trunc(CASE WHEN p_period = 'day' THEN 'hour' ELSE p_period END, p_start_date),
            p_end_date,
            (CASE WHEN p_period = 'day' THEN '1 hour' ELSE '1 ' || p_period END)::interval
        ) AS gs(period_start)
    LEFT JOIN
        public.transactions t ON date_trunc(CASE WHEN p_period = 'day' THEN 'hour' ELSE p_period END, t.created_at) = gs.period_start
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