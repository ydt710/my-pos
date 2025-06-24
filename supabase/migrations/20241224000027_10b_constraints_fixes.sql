-- =============================================
-- EXPORT SCRIPT 10b: CONSTRAINTS FIXES
-- =============================================
-- This script contains data validation and constraint fixes.
-- Run this script after 10a_performance_fixes.sql.
-- =============================================

-- Fix 7: Ensure proper constraints exist
-- Add check constraints for data integrity
DO $$
BEGIN
    -- Ensure cash_amount and balance_amount are reasonable
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'transactions_amounts_reasonable') THEN
        ALTER TABLE public.transactions 
        ADD CONSTRAINT transactions_amounts_reasonable 
        CHECK (
            cash_amount >= -10000 AND cash_amount <= 10000 AND
            balance_amount >= -10000 AND balance_amount <= 10000 AND
            total_amount >= 0 AND total_amount <= 10000
        );
    END IF;
    
    -- Ensure order totals are reasonable
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_total_reasonable') THEN
        ALTER TABLE public.orders 
        ADD CONSTRAINT orders_total_reasonable 
        CHECK (total >= 0 AND total <= 10000);
    END IF;
EXCEPTION 
    WHEN OTHERS THEN 
        -- Constraints may already exist, continue
        NULL;
END $$;

-- Fix 8: Custom Pricing System Fixes
-- Ensure unique constraint exists for user_product_prices
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'user_product_prices_user_product_unique') THEN
        ALTER TABLE public.user_product_prices 
        ADD CONSTRAINT user_product_prices_user_product_unique 
        UNIQUE (user_id, product_id);
    END IF;
EXCEPTION 
    WHEN OTHERS THEN 
        -- Constraint may already exist, continue
        NULL;
END $$;

-- Add helpful comment for custom pricing table
COMMENT ON TABLE public.user_product_prices IS 'User-specific custom product pricing: allows setting different prices for specific customers';
COMMENT ON COLUMN public.user_product_prices.custom_price IS 'Custom price for this user/product combination (overrides regular and bulk pricing)'; 