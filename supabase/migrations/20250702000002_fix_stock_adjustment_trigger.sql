-- Fix the handle_stock_movement function to handle adjustment movements
CREATE OR REPLACE FUNCTION public.handle_stock_movement()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    v_current_stock integer;
BEGIN
    -- Handle different movement types
    IF NEW.type = 'sale' AND NEW.from_location_id IS NOT NULL THEN
        -- Reduce stock from source location
        UPDATE public.stock_levels
        SET quantity = quantity - NEW.quantity,
            updated_at = now()
        WHERE product_id = NEW.product_id AND location_id = NEW.from_location_id;
        
    ELSIF NEW.type = 'restock' AND NEW.to_location_id IS NOT NULL THEN
        -- Add stock to destination location
        INSERT INTO public.stock_levels (product_id, location_id, quantity, created_at, updated_at)
        VALUES (NEW.product_id, NEW.to_location_id, NEW.quantity, now(), now())
        ON CONFLICT (product_id, location_id)
        DO UPDATE SET quantity = stock_levels.quantity + NEW.quantity, updated_at = now();
        
    ELSIF NEW.type = 'adjustment' AND NEW.to_location_id IS NOT NULL THEN
        -- For adjustments, the quantity field contains the change amount
        -- (new_quantity - old_quantity), so we add it to current stock
        INSERT INTO public.stock_levels (product_id, location_id, quantity, created_at, updated_at)
        VALUES (NEW.product_id, NEW.to_location_id, NEW.quantity, now(), now())
        ON CONFLICT (product_id, location_id)
        DO UPDATE SET quantity = stock_levels.quantity + NEW.quantity, updated_at = now();
        
    ELSIF NEW.type = 'production' AND NEW.status = 'completed' AND NEW.to_location_id IS NOT NULL THEN
        -- Add produced quantity to destination location (facility)
        INSERT INTO public.stock_levels (product_id, location_id, quantity, created_at, updated_at)
        VALUES (NEW.product_id, NEW.to_location_id, NEW.quantity, now(), now())
        ON CONFLICT (product_id, location_id)
        DO UPDATE SET quantity = stock_levels.quantity + NEW.quantity, updated_at = now();
        
    ELSIF NEW.type = 'transfer' AND NEW.status = 'completed' THEN
        -- Handle completed transfers: reduce from source, add to destination
        IF NEW.from_location_id IS NOT NULL THEN
            UPDATE public.stock_levels
            SET quantity = quantity - NEW.quantity,
                updated_at = now()
            WHERE product_id = NEW.product_id AND location_id = NEW.from_location_id;
        END IF;
        
        IF NEW.to_location_id IS NOT NULL THEN
            INSERT INTO public.stock_levels (product_id, location_id, quantity, created_at, updated_at)
            VALUES (NEW.product_id, NEW.to_location_id, NEW.quantity, now(), now())
            ON CONFLICT (product_id, location_id)
            DO UPDATE SET quantity = stock_levels.quantity + NEW.quantity, updated_at = now();
        END IF;
    END IF;

    RETURN NEW;
END;
$function$; 