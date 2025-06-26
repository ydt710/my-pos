-- Add missing stock management functions

-- Function to confirm production is done
CREATE OR REPLACE FUNCTION public.confirm_production_done(p_movement_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_movement record;
    v_current_qty integer := 0;
BEGIN
    -- Get the production movement
    SELECT * INTO v_movement 
    FROM public.stock_movements 
    WHERE id = p_movement_id AND type = 'production' AND status = 'pending';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Production movement not found or already completed';
    END IF;

    -- Get current stock level
    SELECT quantity INTO v_current_qty
    FROM public.stock_levels
    WHERE product_id = v_movement.product_id AND location_id = v_movement.to_location_id;
    
    -- Update stock level (increase by produced quantity)
    IF v_current_qty IS NOT NULL THEN
        UPDATE public.stock_levels 
        SET quantity = v_current_qty + v_movement.quantity,
            updated_at = NOW()
        WHERE product_id = v_movement.product_id AND location_id = v_movement.to_location_id;
    ELSE
        -- Create new stock level record if doesn't exist
        INSERT INTO public.stock_levels (product_id, location_id, quantity, updated_at)
        VALUES (v_movement.product_id, v_movement.to_location_id, v_movement.quantity, NOW());
    END IF;

    -- Mark production as completed
    UPDATE public.stock_movements 
    SET status = 'completed' 
    WHERE id = p_movement_id;
END;
$$;

-- Function to accept a stock transfer
CREATE OR REPLACE FUNCTION public.accept_stock_transfer(p_transfer_id uuid, p_actual_quantity integer)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_transfer record;
    v_from_qty integer := 0;
    v_to_qty integer := 0;
BEGIN
    -- Get the transfer details
    SELECT * INTO v_transfer 
    FROM public.stock_movements 
    WHERE id = p_transfer_id AND type = 'transfer' AND status = 'pending';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transfer not found or already processed';
    END IF;

    -- Validate actual quantity
    IF p_actual_quantity < 0 THEN
        RAISE EXCEPTION 'Actual quantity cannot be negative';
    END IF;

    -- Update FROM location stock (reduce by transferred quantity)
    SELECT quantity INTO v_from_qty
    FROM public.stock_levels
    WHERE product_id = v_transfer.product_id AND location_id = v_transfer.from_location_id;
    
    IF v_from_qty IS NOT NULL THEN
        UPDATE public.stock_levels 
        SET quantity = v_from_qty - v_transfer.quantity,
            updated_at = NOW()
        WHERE product_id = v_transfer.product_id AND location_id = v_transfer.from_location_id;
    END IF;

    -- Update TO location stock (increase by actual received quantity)
    SELECT quantity INTO v_to_qty
    FROM public.stock_levels
    WHERE product_id = v_transfer.product_id AND location_id = v_transfer.to_location_id;
    
    IF v_to_qty IS NOT NULL THEN
        UPDATE public.stock_levels 
        SET quantity = v_to_qty + p_actual_quantity,
            updated_at = NOW()
        WHERE product_id = v_transfer.product_id AND location_id = v_transfer.to_location_id;
    ELSE
        -- Create new stock level record if doesn't exist
        INSERT INTO public.stock_levels (product_id, location_id, quantity, updated_at)
        VALUES (v_transfer.product_id, v_transfer.to_location_id, p_actual_quantity, NOW());
    END IF;

    -- If there's a discrepancy, log it
    IF p_actual_quantity != v_transfer.quantity THEN
        INSERT INTO public.stock_discrepancies (
            product_id, 
            expected_quantity, 
            actual_quantity, 
            reason, 
            reported_by, 
            transfer_id,
            created_at
        ) VALUES (
            v_transfer.product_id,
            v_transfer.quantity,
            p_actual_quantity,
            'Transfer quantity discrepancy - expected ' || v_transfer.quantity || ' but received ' || p_actual_quantity,
            v_transfer.created_by,
            p_transfer_id,
            NOW()
        );
    END IF;

    -- Mark transfer as completed
    UPDATE public.stock_movements 
    SET status = 'completed' 
    WHERE id = p_transfer_id;
END;
$$;

-- Function to reject a stock transfer
CREATE OR REPLACE FUNCTION public.reject_stock_transfer(p_transfer_id uuid, p_actual_quantity integer, p_reason text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_transfer record;
    v_from_qty integer := 0;
    v_to_qty integer := 0;
BEGIN
    -- Get the transfer details
    SELECT * INTO v_transfer 
    FROM public.stock_movements 
    WHERE id = p_transfer_id AND type = 'transfer' AND status = 'pending';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transfer not found or already processed';
    END IF;

    -- Validate actual quantity
    IF p_actual_quantity < 0 THEN
        RAISE EXCEPTION 'Actual quantity cannot be negative';
    END IF;

    -- Update FROM location stock (reduce by expected transfer quantity)
    SELECT quantity INTO v_from_qty
    FROM public.stock_levels
    WHERE product_id = v_transfer.product_id AND location_id = v_transfer.from_location_id;
    
    IF v_from_qty IS NOT NULL THEN
        UPDATE public.stock_levels 
        SET quantity = v_from_qty - v_transfer.quantity,
            updated_at = NOW()
        WHERE product_id = v_transfer.product_id AND location_id = v_transfer.from_location_id;
    END IF;

    -- Update TO location stock (add actual received quantity if any)
    IF p_actual_quantity > 0 THEN
        SELECT quantity INTO v_to_qty
        FROM public.stock_levels
        WHERE product_id = v_transfer.product_id AND location_id = v_transfer.to_location_id;
        
        IF v_to_qty IS NOT NULL THEN
            UPDATE public.stock_levels 
            SET quantity = v_to_qty + p_actual_quantity,
                updated_at = NOW()
            WHERE product_id = v_transfer.product_id AND location_id = v_transfer.to_location_id;
        ELSE
            -- Create new stock level record if doesn't exist
            INSERT INTO public.stock_levels (product_id, location_id, quantity, updated_at)
            VALUES (v_transfer.product_id, v_transfer.to_location_id, p_actual_quantity, NOW());
        END IF;
    END IF;

    -- Log the discrepancy
    INSERT INTO public.stock_discrepancies (
        product_id, 
        expected_quantity, 
        actual_quantity, 
        reason, 
        reported_by, 
        transfer_id,
        created_at
    ) VALUES (
        v_transfer.product_id,
        v_transfer.quantity,
        p_actual_quantity,
        'REJECTED TRANSFER: ' || COALESCE(p_reason, 'No reason provided'),
        v_transfer.created_by,
        p_transfer_id,
        NOW()
    );

    -- Mark transfer as rejected
    UPDATE public.stock_movements 
    SET status = 'rejected' 
    WHERE id = p_transfer_id;
END;
$$;

-- Function to get pending transfers count for notifications
CREATE OR REPLACE FUNCTION public.get_pending_transfers_count()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_count integer;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM public.stock_movements
    WHERE type = 'transfer' AND status = 'pending';
    
    RETURN COALESCE(v_count, 0);
END;
$$;

-- Function to get pending transfers specifically for shop notifications
CREATE OR REPLACE FUNCTION public.get_pending_shop_transfers_count()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_count integer;
    v_shop_id uuid;
BEGIN
    -- Get shop location ID
    SELECT id INTO v_shop_id FROM public.stock_locations WHERE name = 'shop' LIMIT 1;
    
    IF v_shop_id IS NULL THEN
        RETURN 0;
    END IF;
    
    SELECT COUNT(*) INTO v_count
    FROM public.stock_movements
    WHERE type = 'transfer' 
        AND status = 'pending' 
        AND to_location_id = v_shop_id;
    
    RETURN COALESCE(v_count, 0);
END;
$$; 