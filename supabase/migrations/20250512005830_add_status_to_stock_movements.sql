-- Add status column to stock_movements for production confirmation workflow
ALTER TABLE stock_movements
ADD COLUMN status TEXT DEFAULT 'done';

-- Set status to 'done' for existing production records if not already set
UPDATE stock_movements
SET status = 'done'
WHERE type = 'production' AND (status IS NULL OR status = ''); 