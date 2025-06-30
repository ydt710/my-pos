-- Fix dashboard stats function - profiles table doesn't have balance column
-- Balance is calculated from transactions table
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
                -- Cash to collect = orders that are actively being processed for collection
                -- NOT pending online orders (which are just placed but not ready for collection)
                SELECT COALESCE(SUM(o.total), 0) 
                FROM public.orders o 
                WHERE o.status = 'processing' AND o.deleted_at IS NULL
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
                -- Check users who currently have negative balance from all their transactions
                SELECT COALESCE(SUM(ABS(t.balance_amount)), 0)
                FROM public.transactions t
                WHERE t.category IN ('pos_sale', 'online_sale', 'debit_adjustment')
                AND t.balance_amount < 0
                AND t.created_at >= date_trunc('day', now() at time zone 'utc')
                AND EXISTS (
                    -- Check if user currently has negative balance from all transactions
                    SELECT 1 
                    FROM public.transactions t2 
                    WHERE t2.user_id = t.user_id 
                    GROUP BY t2.user_id
                    HAVING SUM(t2.balance_amount) < 0
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