-- =============================================
-- MIGRATION: Fix stock_levels table - Add updated_at column
-- =============================================
-- This migration adds the missing updated_at column to stock_levels table
-- and creates a trigger to auto-update it on changes
-- =============================================

-- Add the missing updated_at column to stock_levels table
ALTER TABLE public.stock_levels 
ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now() NOT NULL;

-- Create or replace the function to set updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-update updated_at on stock_levels changes
DROP TRIGGER IF EXISTS trg_stock_levels_set_updated_at ON public.stock_levels;
CREATE TRIGGER trg_stock_levels_set_updated_at
  BEFORE UPDATE ON public.stock_levels
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Successfully added updated_at column to stock_levels table and created auto-update trigger.';
END $$; 