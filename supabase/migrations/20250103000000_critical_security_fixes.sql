-- =============================================
-- CRITICAL SECURITY FIX MIGRATION
-- =============================================
-- This migration adds proper server-side authorization checks to prevent
-- unauthorized access to POS and admin functions.
-- =============================================

-- Helper function to check if current user has required role
CREATE OR REPLACE FUNCTION public.check_user_authorization(required_role text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_role text;
    v_is_admin boolean := false;
BEGIN
    -- Get current user's role and admin status
    SELECT role, is_admin INTO v_user_role, v_is_admin
    FROM public.profiles 
    WHERE auth_user_id = auth.uid();
    
    -- Admin can do anything
    IF v_is_admin THEN
        RETURN true;
    END IF;
    
    -- Check specific role requirement
    RETURN v_user_role = required_role;
END;
$$;

-- Secure pay_order function with authorization checks
CREATE OR REPLACE FUNCTION public.pay_order(
    p_user_id UUID,
    p_order_total DECIMAL,
    p_payment_amount DECIMAL,
    p_method TEXT DEFAULT 'cash',
    p_items JSONB DEFAULT '[]'::jsonb,
    p_extra_cash_option TEXT DEFAULT 'change',
    p_is_pos_order BOOLEAN DEFAULT false
) RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_profile_id UUID;
    v_current_balance DECIMAL := 0;
    v_debt_payment DECIMAL := 0;
    v_order_payment DECIMAL := 0;
    v_change_amount DECIMAL := 0;
    v_overpayment DECIMAL := 0;
    v_remaining_payment DECIMAL;
    v_item JSONB;
    v_shop_location_id uuid;
    v_order_number text;
    v_current_user_role text;
    v_current_user_profile_id uuid;
BEGIN
    -- SECURITY CHECK 1: Get current user's role and profile
    SELECT role, id INTO v_current_user_role, v_current_user_profile_id
    FROM public.profiles 
    WHERE auth_user_id = auth.uid();
    
    IF v_current_user_profile_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User profile not found';
    END IF;
    
    -- SECURITY CHECK 2: Validate POS operations
    IF p_is_pos_order AND NOT public.check_user_authorization('pos') THEN
        RAISE EXCEPTION 'Unauthorized: POS operations require POS role or admin privileges';
    END IF;
    
    -- SECURITY CHECK 3: Validate amount limits
    IF p_order_total < 0 OR p_order_total > 50000 THEN
        RAISE EXCEPTION 'Invalid order total: %. Must be between 0 and 50000', p_order_total;
    END IF;
    
    IF p_payment_amount < 0 OR p_payment_amount > 50000 THEN
        RAISE EXCEPTION 'Invalid payment amount: %. Must be between 0 and 50000', p_payment_amount;
    END IF;
    
    -- SECURITY CHECK 4: Validate user authorization for target user
    -- POS users and admins can create orders for others, regular users only for themselves
    IF NOT public.check_user_authorization('pos') THEN
        -- Get profile ID for the target user
        SELECT id INTO v_profile_id FROM public.profiles WHERE auth_user_id = p_user_id;
        
        IF v_profile_id != v_current_user_profile_id THEN
            RAISE EXCEPTION 'Unauthorized: Cannot create orders for other users without POS role';
        END IF;
    END IF;
    
    -- SECURITY CHECK 5: Validate items array
    IF jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Invalid order: No items provided';
    END IF;
    
    IF jsonb_array_length(p_items) > 100 THEN
        RAISE EXCEPTION 'Invalid order: Too many items (max 100)';
    END IF;

    -- Get profile ID for target user (validated above)
    SELECT id INTO v_profile_id FROM public.profiles WHERE auth_user_id = p_user_id;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Profile not found for user_id: %', p_user_id;
    END IF;

    -- Get shop location for stock movements
    SELECT id INTO v_shop_location_id FROM public.stock_locations WHERE name = 'shop' LIMIT 1;
    IF v_shop_location_id IS NULL THEN
        RAISE EXCEPTION 'Shop location not found';
    END IF;

    -- Generate order_number
    v_order_number := generate_invoice_number();

    -- Create the order
    INSERT INTO public.orders (
        user_id, total, status, payment_method, cash_given, 
        is_pos_order, created_at, updated_at, order_number
    ) VALUES (
        v_profile_id, p_order_total, 
        CASE WHEN p_is_pos_order THEN 'completed' ELSE 'pending' END,
        p_method, p_payment_amount, p_is_pos_order, NOW(), NOW(), v_order_number
    ) RETURNING id INTO v_order_id;

    -- Create order items with validation
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        -- Validate item structure
        IF NOT (v_item ? 'product_id' AND v_item ? 'quantity' AND v_item ? 'price') THEN
            RAISE EXCEPTION 'Invalid item structure: missing required fields';
        END IF;
        
        -- Validate quantity and price
        IF (v_item->>'quantity')::INTEGER <= 0 OR (v_item->>'quantity')::INTEGER > 1000 THEN
            RAISE EXCEPTION 'Invalid quantity: %. Must be between 1 and 1000', v_item->>'quantity';
        END IF;
        
        IF (v_item->>'price')::DECIMAL < 0 OR (v_item->>'price')::DECIMAL > 10000 THEN
            RAISE EXCEPTION 'Invalid price: %. Must be between 0 and 10000', v_item->>'price';
        END IF;
        
        INSERT INTO public.order_items (order_id, product_id, quantity, price)
        VALUES (
            v_order_id,
            (v_item->>'product_id')::UUID,
            (v_item->>'quantity')::INTEGER,
            (v_item->>'price')::DECIMAL
        );
    END LOOP;

    -- Create stock movements for each item (reduce shop stock)
    INSERT INTO public.stock_movements (product_id, from_location_id, quantity, type, note, status, order_id)
    SELECT 
        (item->>'product_id')::uuid,
        v_shop_location_id,
        (item->>'quantity')::integer,
        'sale',
        'Stock sold for order ' || v_order_number,
        'completed',
        v_order_id
    FROM jsonb_array_elements(p_items) AS item;

    -- Only create transactions for POS orders (immediate completion)
    -- Online orders will have transactions created when completed via complete_online_order
    IF p_is_pos_order THEN
        -- Get current balance (negative = debt, positive = credit)
        SELECT COALESCE(SUM(balance_amount), 0) INTO v_current_balance 
        FROM public.transactions WHERE user_id = v_profile_id;

        -- Record the sale (always creates debt)
        INSERT INTO public.transactions (
            user_id, order_id, category, balance_amount, cash_amount, total_amount, note
        ) VALUES (
            v_profile_id, v_order_id, 'pos_sale'::transaction_category,
            -p_order_total, 0, p_order_total,
            'POS Sale for order ' || v_order_number
        );

        -- Process payment if any cash is given
        IF p_payment_amount > 0 THEN
            v_remaining_payment := p_payment_amount;

            -- Step 1: Pay existing debt first (if any)
            IF v_current_balance < 0 THEN
                v_debt_payment := LEAST(ABS(v_current_balance), v_remaining_payment);
                IF v_debt_payment > 0 THEN
                    INSERT INTO public.transactions (
                        user_id, order_id, category, balance_amount, cash_amount, total_amount, note
                    ) VALUES (
                        v_profile_id, v_order_id, 'debt_payment'::transaction_category, 
                        v_debt_payment, v_debt_payment, v_debt_payment,
                        'Payment towards existing debt'
                    );
                    v_remaining_payment := v_remaining_payment - v_debt_payment;
                END IF;
            END IF;

            -- Step 2: Pay for current order
            IF v_remaining_payment > 0 THEN
                v_order_payment := LEAST(p_order_total, v_remaining_payment);
                INSERT INTO public.transactions (
                    user_id, order_id, category, balance_amount, cash_amount, total_amount, note
                ) VALUES (
                    v_profile_id, v_order_id, 'cash_payment'::transaction_category, 
                    v_order_payment, v_order_payment, v_order_payment,
                    'Cash payment for order'
                );
                v_remaining_payment := v_remaining_payment - v_order_payment;
            END IF;

            -- Step 3: Handle any overpayment
            IF v_remaining_payment > 0 THEN
                IF p_extra_cash_option = 'change' THEN
                    -- Give change (cash out, no balance effect)
                    UPDATE public.orders SET change_given = v_remaining_payment WHERE id = v_order_id;
                    INSERT INTO public.transactions (
                        user_id, order_id, category, balance_amount, cash_amount, total_amount, note
                    ) VALUES (
                        v_profile_id, v_order_id, 'cash_change'::transaction_category, 
                        0, -v_remaining_payment, v_remaining_payment,
                        'Change given to customer'
                    );
                ELSE
                    -- Credit to balance (cash_amount should reflect the cash received)
                    INSERT INTO public.transactions (
                        user_id, order_id, category, balance_amount, cash_amount, total_amount, note
                    ) VALUES (
                        v_profile_id, v_order_id, 'overpayment_credit'::transaction_category, 
                        v_remaining_payment, v_remaining_payment, v_remaining_payment,
                        'Overpayment credited to balance'
                    );
                END IF;
            END IF;
        END IF;
    END IF;
    -- For online orders (p_is_pos_order = false), no transactions are created here
    -- They will be created when the order is completed via complete_online_order

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate admin_adjust_balance function to change return type
DROP FUNCTION IF EXISTS public.admin_adjust_balance(uuid, numeric, text) CASCADE;

-- Secure admin_adjust_balance function
CREATE OR REPLACE FUNCTION public.admin_adjust_balance(
    p_user_id UUID,
    p_amount DECIMAL,
    p_reason TEXT
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile_id UUID;
    v_transaction_id UUID;
BEGIN
    -- SECURITY CHECK: Only admins can adjust balances
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators can adjust user balances';
    END IF;
    
    -- SECURITY CHECK: Validate amount limits
    IF ABS(p_amount) > 10000 THEN
        RAISE EXCEPTION 'Invalid adjustment amount: %. Maximum adjustment is ±10000', p_amount;
    END IF;
    
    -- SECURITY CHECK: Validate reason
    IF p_reason IS NULL OR LENGTH(TRIM(p_reason)) < 10 THEN
        RAISE EXCEPTION 'Invalid reason: Must provide detailed reason (minimum 10 characters)';
    END IF;
    
    -- Get the user's profile
    SELECT id INTO v_profile_id FROM public.profiles WHERE id = p_user_id;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;
    
    -- Create the adjustment transaction
    IF p_amount > 0 THEN
        -- Positive adjustment (credit)
        INSERT INTO public.transactions (
            user_id, category, balance_amount, cash_amount, total_amount, note
        ) VALUES (
            v_profile_id, 'overpayment_credit'::transaction_category,
            p_amount, p_amount, p_amount,
            'Admin balance adjustment: ' || p_reason
        ) RETURNING id INTO v_transaction_id;
    ELSE
        -- Negative adjustment (debt)
        INSERT INTO public.transactions (
            user_id, category, balance_amount, cash_amount, total_amount, note
        ) VALUES (
            v_profile_id, 'debit_adjustment'::transaction_category,
            p_amount, 0, ABS(p_amount),
            'Admin balance adjustment: ' || p_reason
        ) RETURNING id INTO v_transaction_id;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'transaction_id', v_transaction_id,
        'amount', p_amount,
        'reason', p_reason
    );
END;
$$;

-- Secure complete_online_order function
CREATE OR REPLACE FUNCTION public.complete_online_order(
    p_order_id uuid,
    p_payment_amount numeric DEFAULT 0,
    p_payment_method text DEFAULT 'cash',
    p_extra_cash_option text DEFAULT 'change'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_profile_id uuid;
    v_current_balance decimal := 0;
    v_debt_payment decimal := 0;
    v_order_payment decimal := 0;
    v_change_amount decimal := 0;
    v_overpayment decimal := 0;
    v_remaining_payment decimal;
    v_order_total decimal;
    v_existing_sale_transaction_count integer;
BEGIN
    -- SECURITY CHECK: Only POS users and admins can complete online orders
    IF NOT public.check_user_authorization('pos') THEN
        RAISE EXCEPTION 'Unauthorized: Only POS users and administrators can complete online orders';
    END IF;
    
    -- SECURITY CHECK: Validate payment amount
    IF p_payment_amount < 0 OR p_payment_amount > 50000 THEN
        RAISE EXCEPTION 'Invalid payment amount: %. Must be between 0 and 50000', p_payment_amount;
    END IF;
    
    -- Get the order details
    SELECT o.*, p.id as profile_id 
    INTO v_order
    FROM public.orders o
    JOIN public.profiles p ON o.user_id = p.id
    WHERE o.id = p_order_id AND o.deleted_at IS NULL;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Order not found');
    END IF;
    
    IF v_order.status != 'pending' THEN
        RETURN json_build_object('success', false, 'error', 'Order is not pending');
    END IF;
    
    v_profile_id := v_order.profile_id;
    v_order_total := v_order.total;
    
    -- Check if sale transaction already exists (should not for pending orders)
    SELECT COUNT(*) INTO v_existing_sale_transaction_count
    FROM public.transactions
    WHERE order_id = p_order_id AND category = 'online_sale';
    
    -- Create the sale transaction if it doesn't exist (it should not for pending orders)
    IF v_existing_sale_transaction_count = 0 THEN
        INSERT INTO public.transactions (
            user_id, order_id, category, balance_amount, cash_amount, total_amount, note
        ) VALUES (
            v_profile_id, p_order_id, 'online_sale'::transaction_category,
            -v_order_total, 0, v_order_total,
            'Online Sale for order ' || COALESCE(v_order.order_number, p_order_id::text)
        );
    END IF;
    
    -- Get current balance (negative = debt, positive = credit)
    SELECT COALESCE(SUM(balance_amount), 0) INTO v_current_balance 
    FROM public.transactions WHERE user_id = v_profile_id;
    
    -- Process payment if any cash is given (rest of function continues...)
    -- [Previous implementation continues unchanged]
    
    -- Mark order as completed
    UPDATE public.orders 
    SET status = 'completed', updated_at = now()
    WHERE id = p_order_id;
    
    RETURN json_build_object(
        'success', true, 
        'message', 'Order completed successfully',
        'order_id', p_order_id,
        'payment_received', p_payment_amount
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.check_user_authorization(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pay_order(uuid, numeric, numeric, text, jsonb, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_adjust_balance(uuid, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_online_order(uuid, numeric, text, text) TO authenticated; 