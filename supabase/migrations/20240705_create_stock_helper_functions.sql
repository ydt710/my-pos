-- Function to get stock quantity for a product at a specific location
CREATE OR REPLACE FUNCTION public.get_stock_by_location(p_product_id UUID, p_location_name TEXT)
RETURNS INT AS $$
DECLARE
    v_location_id UUID;
    v_stock_quantity INT;
BEGIN
    -- Get the location ID from the name
    SELECT id INTO v_location_id FROM public.stock_locations WHERE name = p_location_name;
    IF v_location_id IS NULL THEN
        RAISE EXCEPTION 'Location not found: %', p_location_name;
    END IF;

    -- Get the stock quantity
    SELECT quantity INTO v_stock_quantity 
    FROM public.stock_levels 
    WHERE product_id = p_product_id AND location_id = v_location_id;

    RETURN COALESCE(v_stock_quantity, 0);
END;
$$ LANGUAGE plpgsql;

-- Function to decrease stock atomically at a specific location
CREATE OR REPLACE FUNCTION public.decrease_stock(p_product_id UUID, p_quantity INT, p_location_name TEXT)
RETURNS VOID AS $$
DECLARE
    v_location_id UUID;
BEGIN
    -- Get the location ID from the name
    SELECT id INTO v_location_id FROM public.stock_locations WHERE name = p_location_name;
    IF v_location_id IS NULL THEN
        RAISE EXCEPTION 'Location not found: %', p_location_name;
    END IF;

    -- Update stock level
    INSERT INTO public.stock_levels (product_id, location_id, quantity)
    VALUES (p_product_id, v_location_id, -p_quantity)
    ON CONFLICT (product_id, location_id)
    DO UPDATE SET quantity = stock_levels.quantity - p_quantity;
END;
$$ LANGUAGE plpgsql; 