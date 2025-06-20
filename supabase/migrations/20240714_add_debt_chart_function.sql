-- Creates a function to aggregate debt created vs. debt paid over a specified period.
CREATE OR REPLACE FUNCTION get_debt_created_vs_paid(filter_option text)
RETURNS TABLE(period text, debt_created numeric, debt_paid numeric) AS $$
DECLARE
    start_date timestamptz;
    end_date timestamptz;
    period_format text;
BEGIN
    -- Determine date range and format based on filter
    end_date := now();
    IF filter_option = 'today' THEN
        start_date := date_trunc('day', now());
        period_format := 'YYYY-MM-DD HH24:00';
    ELSIF filter_option = 'week' THEN
        start_date := date_trunc('week', now());
        period_format := 'YYYY-MM-DD';
    ELSIF filter_option = 'month' THEN
        start_date := date_trunc('month', now());
        period_format := 'YYYY-MM-DD';
    ELSIF filter_option = 'year' THEN
        start_date := date_trunc('year', now());
        period_format := 'YYYY-MM';
    ELSE
        start_date := '2000-01-01'::timestamptz; -- Default to all time if no filter
        period_format := 'YYYY-MM';
    END IF;

    RETURN QUERY
    WITH all_periods AS (
        SELECT to_char(gs.period_start, period_format) AS period
        FROM generate_series(start_date, end_date, '1 day'::interval) AS gs(period_start)
        GROUP BY period
    ),
    transactions_data AS (
        SELECT
            to_char(created_at, period_format) AS period,
            SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) AS total_debt_created,
            SUM(CASE WHEN amount > 0 AND type = 'payment' THEN amount ELSE 0 END) AS total_debt_paid
        FROM transactions
        WHERE created_at >= start_date AND created_at <= end_date
        GROUP BY period
    )
    SELECT
        ap.period,
        COALESCE(td.total_debt_created, 0) AS debt_created,
        COALESCE(td.total_debt_paid, 0) AS debt_paid
    FROM all_periods ap
    LEFT JOIN transactions_data td ON ap.period = td.period
    ORDER BY ap.period;

END;
$$ LANGUAGE plpgsql; 