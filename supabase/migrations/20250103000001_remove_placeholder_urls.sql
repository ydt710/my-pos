-- Remove placeholder URLs and replace with null for proper fallback handling
-- This will fix the ERR_NAME_NOT_RESOLVED errors for via.placeholder.com

UPDATE products 
SET image_url = NULL 
WHERE image_url LIKE '%via.placeholder.com%'; 