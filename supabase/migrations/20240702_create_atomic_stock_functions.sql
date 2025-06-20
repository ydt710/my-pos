-- Function to confirm a production movement is done
CREATE OR REPLACE FUNCTION confirm_production_done(p_movement_id UUID)
RETURNS VOID AS $$
DECLARE
  v_movement RECORD;
BEGIN
  -- 1. Get the stock movement details and lock the row
  SELECT * INTO v_movement FROM public.stock_movements WHERE id = p_movement_id FOR UPDATE;

  -- 2. Check if movement exists and is pending
  IF v_movement IS NULL THEN
    RAISE EXCEPTION 'Production movement not found: %', p_movement_id;
  END IF;
  
  IF v_movement.status != 'pending' THEN
    -- Movement is not pending, so we can ignore it.
    -- Or raise an exception if this is considered an error.
    RETURN;
  END IF;

  -- 3. Update the stock level at the destination (facility)
  INSERT INTO public.stock_levels (product_id, location_id, quantity)
  VALUES (v_movement.product_id, v_movement.to_location_id, v_movement.quantity)
  ON CONFLICT (product_id, location_id)
  DO UPDATE SET quantity = stock_levels.quantity + v_movement.quantity;

  -- 4. Update the movement status to 'done'
  UPDATE public.stock_movements
  SET status = 'done'
  WHERE id = p_movement_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Function to accept a stock transfer
CREATE OR REPLACE FUNCTION accept_stock_transfer(p_transfer_id UUID, p_actual_quantity INT)
RETURNS VOID AS $$
DECLARE
    v_transfer RECORD;
    v_facility_id UUID;
    v_shop_id UUID;
BEGIN
    -- Get transfer details
    SELECT * INTO v_transfer FROM public.stock_movements WHERE id = p_transfer_id FOR UPDATE;

    IF v_transfer IS NULL THEN
        RAISE EXCEPTION 'Transfer not found: %', p_transfer_id;
    END IF;

    IF v_transfer.status != 'pending' THEN
        RETURN; -- Or raise an exception
    END IF;

    v_facility_id := v_transfer.from_location_id;
    v_shop_id := v_transfer.to_location_id;

    -- Update shop stock with actual quantity
    IF p_actual_quantity > 0 THEN
      INSERT INTO public.stock_levels (product_id, location_id, quantity)
      VALUES (v_transfer.product_id, v_shop_id, p_actual_quantity)
      ON CONFLICT (product_id, location_id)
      DO UPDATE SET quantity = stock_levels.quantity + p_actual_quantity;
    END IF;

    -- Deduct from facility stock (this was missing from the original logic)
    -- The original transferToShop deducted from facility immediately, which is not ideal.
    -- A better flow would be to only deduct when the transfer is accepted.
    -- For now, let's assume the original deduction in transferToShop is what we want
    -- and this function just marks the transfer complete.
    -- If there's a discrepancy, that's handled by reject.

    -- Update movement status and quantity
    UPDATE public.stock_movements
    SET status = 'done', quantity = p_actual_quantity
    WHERE id = p_transfer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 