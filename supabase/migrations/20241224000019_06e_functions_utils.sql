-- =============================================
-- EXPORT SCRIPT 06e: UTILITY FUNCTIONS
-- =============================================
-- This script creates utility functions for invoices, settings, etc.
-- =============================================

-- Drop existing utility functions with CASCADE
DROP FUNCTION IF EXISTS generate_invoice_number() CASCADE;
DROP FUNCTION IF EXISTS calculate_tax_amount(numeric) CASCADE;
DROP FUNCTION IF EXISTS calculate_shipping_fee(numeric, boolean) CASCADE;
DROP FUNCTION IF EXISTS get_store_settings() CASCADE;

-- Professional Invoice System Functions

-- Function to generate professional invoice numbers (format: INV-2025-001234)
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    current_year int;
    next_number int;
    invoice_prefix text;
    invoice_number text;
BEGIN
    current_year := EXTRACT(year FROM NOW());
    invoice_prefix := 'INV-' || current_year || '-';
    
    -- Get the next sequential number for this year
    SELECT COALESCE(
        MAX(CAST(SUBSTRING(order_number FROM '(\d+)$') AS INTEGER)), 0
    ) + 1
    INTO next_number
    FROM orders 
    WHERE order_number LIKE invoice_prefix || '%'
    AND EXTRACT(year FROM created_at) = current_year;
    
    -- Format as 6-digit padded number
    invoice_number := invoice_prefix || LPAD(next_number::text, 6, '0');
    
    RETURN invoice_number;
END;
$$;

-- Function to calculate tax amount based on settings
CREATE OR REPLACE FUNCTION calculate_tax_amount(subtotal_amount numeric)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
    tax_rate numeric;
BEGIN
    SELECT s.tax_rate INTO tax_rate FROM settings s WHERE id = 1 LIMIT 1;
    IF tax_rate IS NULL THEN
        tax_rate := 15; -- Default to 15% if no settings
    END IF;
    
    RETURN ROUND(subtotal_amount * (tax_rate / 100), 2);
END;
$$;

-- Function to calculate shipping fee based on settings and order amount
CREATE OR REPLACE FUNCTION calculate_shipping_fee(subtotal_amount numeric, is_pos_order boolean DEFAULT false)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
    shipping_fee numeric;
    free_shipping_threshold numeric;
BEGIN
    -- POS orders don't have shipping
    IF is_pos_order THEN
        RETURN 0;
    END IF;
    
    SELECT s.shipping_fee, s.free_shipping_threshold 
    INTO shipping_fee, free_shipping_threshold 
    FROM settings s WHERE id = 1 LIMIT 1;
    
    IF shipping_fee IS NULL THEN
        shipping_fee := 50; -- Default shipping
    END IF;
    
    IF free_shipping_threshold IS NULL THEN
        free_shipping_threshold := 500; -- Default free shipping threshold
    END IF;
    
    -- Free shipping if order meets threshold
    IF subtotal_amount >= free_shipping_threshold THEN
        RETURN 0;
    ELSE
        RETURN shipping_fee;
    END IF;
END;
$$;

-- Function to get store settings for invoices
CREATE OR REPLACE FUNCTION get_store_settings()
RETURNS json
LANGUAGE sql
AS $$
    SELECT json_build_object(
        'store_name', COALESCE(store_name, 'My POS Store'),
        'store_email', COALESCE(store_email, 'store@example.com'),
        'store_phone', COALESCE(store_phone, '+27 11 123 4567'),
        'store_address', COALESCE(store_address, '123 Main Street, Johannesburg, 2000'),
        'currency', COALESCE(currency, 'ZAR'),
        'tax_rate', COALESCE(tax_rate, 15),
        'shipping_fee', COALESCE(shipping_fee, 50),
        'business_hours', COALESCE(business_hours, '{}')
    )
    FROM settings 
    WHERE id = 1 
    LIMIT 1;
$$; 