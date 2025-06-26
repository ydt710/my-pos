-- Add background images to existing landing categories
UPDATE landing_categories 
SET categories = jsonb_set(
  jsonb_set(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          categories,
          '{0,background_image}',
          '"https://wglybohfygczpapjxwwz.supabase.co/storage/v1/object/public/route420//dagga%20cat.webp"'
        ),
        '{1,background_image}',
        '"https://mjbizdaily.com/wp-content/uploads/2024/08/Pre-rolls_-joints-_2_.webp"'
      ),
      '{2,background_image}',
      '"https://bulkweedinbox.cc/wp-content/uploads/2024/12/Greasy-Pink.jpg"'
    ),
    '{3,background_image}',
    '"https://longislandinterventions.com/wp-content/uploads/2024/12/Edibles-1.jpg"'
  ),
  '{4,background_image}',
  '"https://wglybohfygczpapjxwwz.supabase.co/storage/v1/object/public/route420//bongs.webp"'
) 
WHERE id = 1; 