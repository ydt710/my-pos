-- Add stock management fields to products table

-- Add low_stock_buffer field (default 1000 as recommended)
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS low_stock_buffer integer DEFAULT 1000;

-- Add is_out_of_stock checkbox field
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS is_out_of_stock boolean DEFAULT false;

-- Add comments for clarity
COMMENT ON COLUMN public.products.low_stock_buffer IS 'Minimum stock level before item shows as low stock in notifications';
COMMENT ON COLUMN public.products.is_out_of_stock IS 'Manual flag to mark product as out of stock (ignores stock levels)';

-- Create function to get low stock items for notifications
CREATE OR REPLACE FUNCTION public.get_low_stock_notifications()
RETURNS TABLE (
    product_id uuid,
    product_name text,
    current_stock integer,
    low_stock_buffer integer,
    location_name text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as product_id,
        p.name as product_name,
        COALESCE(sl.quantity, 0) as current_stock,
        p.low_stock_buffer,
        loc.name as location_name
    FROM public.products p
    LEFT JOIN public.stock_levels sl ON p.id = sl.product_id
    LEFT JOIN public.stock_locations loc ON sl.location_id = loc.id
    WHERE p.is_out_of_stock = false  -- Ignore manually marked out of stock items
        AND p.low_stock_buffer > 0   -- Only check items with buffer set
        AND COALESCE(sl.quantity, 0) <= p.low_stock_buffer  -- Stock is at or below buffer
        AND loc.name IN ('shop', 'facility')  -- Only check main locations
    ORDER BY p.name, loc.name;
END;
$$;

-- Grant permissions for the new function
GRANT EXECUTE ON FUNCTION public.get_low_stock_notifications() TO authenticated; 