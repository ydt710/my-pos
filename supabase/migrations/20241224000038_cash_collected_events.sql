-- =============================================
-- MIGRATION: Add get_cash_collected_events for event-level cash chart
-- =============================================
CREATE OR REPLACE FUNCTION public.get_cash_collected_events(
    p_start_date timestamptz,
    p_end_date timestamptz
)
RETURNS TABLE(period timestamptz, cash_collected numeric)
LANGUAGE sql
AS $$
    SELECT
        t.created_at AS period,
        t.cash_amount AS cash_collected
    FROM public.transactions t
    WHERE t.category IN ('debt_payment', 'cash_payment', 'overpayment_credit')
      AND t.created_at BETWEEN p_start_date AND p_end_date
    ORDER BY t.created_at;
$$;

-- Cash Collected Events Function for Individual Event Tracking
CREATE OR REPLACE FUNCTION public.get_cash_collected_events(p_start_date timestamptz, p_end_date timestamptz)
RETURNS TABLE (period timestamptz, cash_collected numeric)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.created_at as period,
        t.cash_amount as cash_collected
    FROM
        public.transactions t
    WHERE
        t.category IN ('debt_payment', 'cash_payment', 'overpayment_credit')
        AND t.created_at BETWEEN p_start_date AND p_end_date
        AND t.cash_amount > 0
    ORDER BY
        t.created_at;
END;
$$ LANGUAGE plpgsql;

-- Fix Credit and Debt over time charts to use proper time series generation

-- Update get_credit_over_time function to use proper time series generation
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
                             AND t.created_at BETWEEN p_start_date AND p_end_date
    GROUP BY
        gs.period_start
    ORDER BY
        gs.period_start;
END;
$$ LANGUAGE plpgsql;

-- Update get_debt_over_time function to use proper time series generation  
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
                             AND t.created_at BETWEEN p_start_date AND p_end_date
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