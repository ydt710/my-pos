-- =============================================
-- MIGRATION: Fix Transactions Table & Functions
-- =============================================
-- This migration fixes the missing category column and adds all required functions
-- =============================================

-- 1. Create the missing enum type
DROP TYPE IF EXISTS public.transaction_category CASCADE;
CREATE TYPE public.transaction_category AS ENUM (
    'sale', 'credit_payment', 'cash_payment', 'overpayment_credit',
    'cash_change', 'pos_sale', 'online_sale', 'debt_payment',
    'cancellation', 'credit_adjustment', 'debit_adjustment', 'balance_adjustment'
);

-- 2. Add the missing category column to transactions table
ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS category public.transaction_category NOT NULL DEFAULT 'sale';

-- 3. Create missing indexes
CREATE INDEX IF NOT EXISTS idx_transactions_category_created_at ON public.transactions(category, created_at DESC);

-- 4. Update any existing records
UPDATE public.transactions 
SET category = 'sale' 
WHERE category IS NULL OR category = 'sale';

-- 5. Create user_balances view
CREATE OR REPLACE VIEW "public"."user_balances" AS
SELECT
    p.id AS user_id,
    p.auth_user_id,
    p.display_name AS name,
    p.email,
    p.phone_number AS phone,
    COALESCE(SUM(t.balance_amount), 0) AS balance
FROM 
    public.profiles p
LEFT JOIN 
    public.transactions t ON p.id = t.user_id
GROUP BY 
    p.id, p.auth_user_id, p.display_name, p.email, p.phone_number;

-- 6. Create is_admin function
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE auth_user_id = auth.uid() AND is_admin = true
  );
$$;

-- 7. Create dashboard stats function
CREATE OR REPLACE FUNCTION public.get_dashboard_stats()
RETURNS json
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN (
        SELECT json_build_object(
            'totalOrders', (SELECT COUNT(*) FROM public.orders WHERE deleted_at IS NULL),
            'totalRevenue', (SELECT COALESCE(SUM(total), 0) FROM public.orders WHERE status = 'completed' AND deleted_at IS NULL),
            'cashToCollect', (
                SELECT COALESCE(SUM(o.total), 0) 
                FROM public.orders o 
                WHERE o.status = 'pending' AND o.deleted_at IS NULL
            ),
            'cashCollectedToday', (
                SELECT COALESCE(SUM(t.cash_amount), 0)
                FROM public.transactions t
                WHERE t.category IN ('debt_payment', 'cash_payment', 'overpayment_credit')
                AND t.created_at >= date_trunc('day', now() at time zone 'utc')
            ),
            'debtCreatedToday', (
                SELECT COALESCE(SUM(ABS(t.balance_amount)), 0)
                FROM public.transactions t
                WHERE t.category IN ('pos_sale', 'online_sale', 'debit_adjustment')
                AND t.created_at >= date_trunc('day', now() at time zone 'utc')
            ),
            'topProducts', (
                SELECT COALESCE(json_agg(top_prods), '[]'::json)
                FROM (
                    SELECT p.name, SUM(oi.quantity) AS quantity
                    FROM public.order_items oi
                    JOIN public.products p ON oi.product_id = p.id
                    JOIN public.orders o ON oi.order_id = o.id
                    WHERE o.deleted_at IS NULL
                    GROUP BY p.name
                    ORDER BY quantity DESC
                    LIMIT 5
                ) top_prods
            )
        )
    );
END;
$$;

-- 8. Create chart functions
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
                    WHEN filter_option = 'today' THEN date_trunc('day', now())
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
        COALESCE(SUM(CASE WHEN t.category IN ('pos_sale', 'online_sale', 'debit_adjustment') THEN ABS(t.balance_amount) ELSE 0 END), 0) AS debt_created,
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
            date_trunc(p_period, p_start_date),
            p_end_date,
            ('1 ' || p_period)::interval
        ) AS gs(period_start)
    LEFT JOIN
        public.transactions t ON date_trunc(p_period, t.created_at) = gs.period_start
                             AND t.category IN ('debt_payment', 'cash_payment', 'overpayment_credit')
    GROUP BY
        gs.period_start
    ORDER BY
        gs.period_start;
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
            date_trunc(p_period, p_start_date),
            p_end_date,
            ('1 ' || p_period)::interval
        ) AS gs(period_start)
    LEFT JOIN
        public.transactions t ON date_trunc(p_period, t.created_at) = gs.period_start
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
            date_trunc(p_period, p_start_date),
            p_end_date,
            ('1 ' || p_period)::interval
        ) AS gs(period_start)
    LEFT JOIN
        public.transactions t ON date_trunc(p_period, t.created_at) = gs.period_start
                             AND t.category IN ('pos_sale', 'online_sale', 'debit_adjustment')
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

-- 9. Create additional helper functions
CREATE OR REPLACE FUNCTION public.get_cash_in_stats()
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
            'today', COALESCE(SUM(t.cash_amount) FILTER (WHERE t.created_at >= time_boundaries.today_start AND t.category IN ('debt_payment', 'cash_payment', 'overpayment_credit')), 0),
            'week', COALESCE(SUM(t.cash_amount) FILTER (WHERE t.created_at >= time_boundaries.week_start AND t.category IN ('debt_payment', 'cash_payment', 'overpayment_credit')), 0),
            'month', COALESCE(SUM(t.cash_amount) FILTER (WHERE t.created_at >= time_boundaries.month_start AND t.category IN ('debt_payment', 'cash_payment', 'overpayment_credit')), 0),
            'year', COALESCE(SUM(t.cash_amount) FILTER (WHERE t.created_at >= time_boundaries.year_start AND t.category IN ('debt_payment', 'cash_payment', 'overpayment_credit')), 0),
            'all_time', COALESCE(SUM(t.cash_amount) FILTER (WHERE t.category IN ('debt_payment', 'cash_payment', 'overpayment_credit')), 0)
        )
        FROM public.transactions t
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_top_buyers(p_limit integer)
RETURNS TABLE(user_id uuid, name text, email text, total numeric)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id as user_id,
        p.display_name as name,
        p.email,
        SUM(o.total) as total
    FROM public.orders o
    JOIN public.profiles p ON o.user_id = p.id
    WHERE o.status = 'completed' AND o.deleted_at IS NULL
    GROUP BY p.id, p.display_name, p.email
    ORDER BY total DESC
    LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_users_by_balance(p_limit integer, p_debt_only boolean DEFAULT true)
RETURNS TABLE(user_id uuid, name text, email text, balance numeric)
LANGUAGE sql
AS $$
  SELECT user_id, name, email, balance
  FROM public.user_balances
  WHERE (p_debt_only = true AND balance < 0) OR (p_debt_only = false)
  ORDER BY balance ASC
  LIMIT p_limit;
$$;

-- 10. Grant permissions
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_dashboard_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_revenue_chart_data(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_debt_created_vs_paid(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_cash_collected_chart_data(text, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_cash_paid_over_time(text, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_credit_over_time(text, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_debt_over_time(text, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_total_spent_top_users(timestamptz, timestamptz, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_cash_in_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_top_buyers(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_users_by_balance(integer, boolean) TO authenticated;

GRANT SELECT ON public.user_balances TO authenticated;
GRANT SELECT ON public.user_balances TO anon; 