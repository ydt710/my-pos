-- =============================================
-- MIGRATION: Fix get_order_summary integer casting (correct FILTER placement)
-- =============================================
-- This migration casts all COUNT(*) results to integer after FILTER to match the function signature.
-- =============================================

CREATE OR REPLACE FUNCTION public.get_order_summary(
    p_start_date timestamptz DEFAULT NULL,
    p_end_date timestamptz DEFAULT NULL,
    p_status text DEFAULT NULL
)
RETURNS TABLE(
    total_orders integer,
    total_revenue numeric,
    average_order_value numeric,
    completed_orders integer,
    completed_revenue numeric,
    pending_orders integer,
    pending_revenue numeric,
    guest_orders integer,
    registered_orders integer
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        CAST(COUNT(*) FILTER (WHERE o.deleted_at IS NULL) AS integer) AS total_orders,
        COALESCE(SUM(o.total) FILTER (WHERE o.status = 'completed' AND o.deleted_at IS NULL), 0) AS total_revenue,
        CASE WHEN COUNT(*) FILTER (WHERE o.deleted_at IS NULL) > 0
            THEN COALESCE(SUM(o.total) FILTER (WHERE o.deleted_at IS NULL), 0) / COUNT(*) FILTER (WHERE o.deleted_at IS NULL)
            ELSE 0 END AS average_order_value,
        CAST(COUNT(*) FILTER (WHERE o.status = 'completed' AND o.deleted_at IS NULL) AS integer) AS completed_orders,
        COALESCE(SUM(o.total) FILTER (WHERE o.status = 'completed' AND o.deleted_at IS NULL), 0) AS completed_revenue,
        CAST(COUNT(*) FILTER (WHERE o.status = 'pending' AND o.deleted_at IS NULL) AS integer) AS pending_orders,
        COALESCE(SUM(o.total) FILTER (WHERE o.status = 'pending' AND o.deleted_at IS NULL), 0) AS pending_revenue,
        CAST(COUNT(*) FILTER (WHERE o.guest_info IS NOT NULL AND o.deleted_at IS NULL) AS integer) AS guest_orders,
        CAST(COUNT(*) FILTER (WHERE o.guest_info IS NULL AND o.deleted_at IS NULL) AS integer) AS registered_orders
    FROM public.orders o
    WHERE (p_start_date IS NULL OR o.created_at >= p_start_date)
      AND (p_end_date IS NULL OR o.created_at <= p_end_date)
      AND (p_status IS NULL OR o.status = p_status)
      AND o.deleted_at IS NULL;
END;
$$; 