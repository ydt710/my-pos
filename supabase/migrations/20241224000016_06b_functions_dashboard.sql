-- =============================================
-- EXPORT SCRIPT 06b: DASHBOARD FUNCTIONS
-- =============================================
-- This script creates dashboard and statistics functions.
-- =============================================

-- Drop existing dashboard functions with CASCADE
DROP FUNCTION IF EXISTS public.get_dashboard_stats() CASCADE;
DROP FUNCTION IF EXISTS public.get_cash_in_stats() CASCADE;
DROP FUNCTION IF EXISTS public.get_top_buyers(integer) CASCADE;
DROP FUNCTION IF EXISTS public.get_users_by_balance(integer, boolean) CASCADE;
DROP FUNCTION IF EXISTS public.get_outstanding_debt_by_user() CASCADE;
DROP FUNCTION IF EXISTS public.get_user_comprehensive_balance(uuid) CASCADE;

-- Function to get main dashboard stats
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
                -- Cash to collect = total of pending orders (online orders waiting to be marked complete)
                SELECT COALESCE(SUM(o.total), 0) 
                FROM public.orders o 
                WHERE o.status = 'pending' AND o.deleted_at IS NULL
            ),
            'cashCollectedToday', (
                -- Cash actually collected today from completed transactions (now includes admin credit adjustments)
                SELECT COALESCE(SUM(t.cash_amount), 0)
                FROM public.transactions t
                WHERE t.category IN ('debt_payment', 'cash_payment', 'overpayment_credit')
                AND t.created_at >= date_trunc('day', now() at time zone 'utc')
            ),
            'debtCreatedToday', (
                -- Total debt created today (only counts actual unpaid debt)
                SELECT COALESCE(SUM(ABS(t.balance_amount)), 0)
                FROM public.transactions t
                WHERE t.category IN ('pos_sale', 'online_sale', 'debit_adjustment')
                AND t.balance_amount < 0
                AND t.created_at >= date_trunc('day', now() at time zone 'utc')
                AND EXISTS (
                    -- Check if user still has negative balance after this transaction
                    SELECT 1 FROM public.profiles p 
                    WHERE p.id = t.user_id AND p.balance < 0
                )
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

-- Function to get cash-in statistics
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

-- Function to get users with most debt (lowest balance)
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

-- Function to get top buying users
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

-- Add new outstanding debt tracking function
CREATE OR REPLACE FUNCTION public.get_outstanding_debt_by_user()
RETURNS TABLE(
    user_id uuid, 
    user_name text, 
    email text, 
    outstanding_debt numeric,
    total_orders_unpaid integer,
    last_order_date timestamptz
)
AS $$
BEGIN
    RETURN QUERY
    WITH unpaid_orders AS (
        SELECT 
            o.user_id,
            o.id as order_id,
            o.total as order_total,
            o.created_at,
            COALESCE(SUM(t.balance_amount) FILTER (WHERE t.category IN ('cash_payment', 'debt_payment')), 0) as paid_amount
        FROM public.orders o
        LEFT JOIN public.transactions t ON o.id = t.order_id AND t.category IN ('cash_payment', 'debt_payment')
        WHERE o.status = 'completed' AND o.deleted_at IS NULL
        GROUP BY o.user_id, o.id, o.total, o.created_at
        HAVING o.total > COALESCE(SUM(t.balance_amount) FILTER (WHERE t.category IN ('cash_payment', 'debt_payment')), 0)
    )
    SELECT 
        uo.user_id,
        COALESCE(p.display_name, p.first_name || ' ' || p.last_name, p.email) as user_name,
        p.email,
        SUM(uo.order_total - uo.paid_amount) as outstanding_debt,
        COUNT(*)::integer as total_orders_unpaid,
        MAX(uo.created_at) as last_order_date
    FROM unpaid_orders uo
    JOIN public.profiles p ON uo.user_id = p.id
    GROUP BY uo.user_id, p.display_name, p.first_name, p.last_name, p.email
    ORDER BY outstanding_debt DESC;
END;
$$ LANGUAGE plpgsql;

-- Add comprehensive balance tracking function
CREATE OR REPLACE FUNCTION public.get_user_comprehensive_balance(p_user_id uuid)
RETURNS TABLE(
    user_id uuid,
    current_balance numeric,
    outstanding_debt numeric,
    available_credit numeric,
    total_spent numeric,
    total_paid numeric,
    last_transaction_date timestamptz
)
AS $$
BEGIN
    RETURN QUERY
    WITH user_stats AS (
        SELECT 
            p_user_id as uid,
            COALESCE(SUM(t.balance_amount), 0) as current_balance,
            COALESCE(SUM(ABS(t.balance_amount)) FILTER (WHERE t.category IN ('pos_sale', 'online_sale')), 0) as total_spent,
            COALESCE(SUM(t.balance_amount) FILTER (WHERE t.category IN ('cash_payment', 'debt_payment', 'overpayment_credit')), 0) as total_paid,
            MAX(t.created_at) as last_transaction_date
        FROM public.transactions t
        WHERE t.user_id = p_user_id
    ),
    unpaid_orders AS (
        SELECT 
            SUM(o.total - COALESCE(payments.paid_amount, 0)) as outstanding_debt
        FROM public.orders o
        LEFT JOIN (
            SELECT 
                order_id,
                SUM(balance_amount) as paid_amount
            FROM public.transactions t2
            WHERE t2.category IN ('cash_payment', 'debt_payment') AND t2.user_id = p_user_id
            GROUP BY order_id
        ) payments ON o.id = payments.order_id
        WHERE o.user_id = p_user_id 
        AND o.status = 'completed' 
        AND o.deleted_at IS NULL
        AND o.total > COALESCE(payments.paid_amount, 0)
    )
    SELECT 
        us.uid,
        us.current_balance,
        COALESCE(uo.outstanding_debt, 0) as outstanding_debt,
        CASE WHEN us.current_balance > 0 THEN us.current_balance ELSE 0 END as available_credit,
        us.total_spent,
        us.total_paid,
        us.last_transaction_date
    FROM user_stats us
    CROSS JOIN unpaid_orders uo;
END;
$$ LANGUAGE plpgsql; 