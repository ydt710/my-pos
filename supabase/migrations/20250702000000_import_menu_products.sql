-- Import Menu Products Migration
-- This migration: 
-- 1. Removes storage location
-- 2. Fixes existing 420 mix Pre-Roll pricing
-- 3. Imports all menu products with correct pricing and categories

-- Remove storage location and its stock levels
DELETE FROM stock_levels WHERE location_id = (SELECT id FROM stock_locations WHERE name = 'storage');
DELETE FROM stock_locations WHERE name = 'storage';

-- Fix the existing 420 mix Pre-Roll pricing to match the menu (500+ @ 20, not 1000+ @ 24)
UPDATE products 
SET bulk_prices = '[{"min_qty": 500, "price": 20}]'::jsonb,
    price = 25
WHERE id = '9064ef14-d377-4d6a-b286-a07fa1877b67';

-- Delete existing products except the 420 mix Pre-Roll which is already correctly set up
DELETE FROM stock_levels WHERE product_id != '9064ef14-d377-4d6a-b286-a07fa1877b67';
DELETE FROM products WHERE id != '9064ef14-d377-4d6a-b286-a07fa1877b67';

-- Insert all the menu products
INSERT INTO products (name, price, category, description, bulk_prices, low_stock_buffer, is_out_of_stock, image_url) VALUES

-- BIG BUD GREENHOUSE @25 (bulk pricing: 500+ @ 20)
('Fat Boy', 25, 'flower', 'Premium greenhouse-grown cannabis strain', '[{"min_qty": 500, "price": 20}]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Fat+Boy'),
('Super Cheese', 25, 'flower', 'Premium greenhouse-grown cannabis strain', '[{"min_qty": 500, "price": 20}]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Super+Cheese'),
('Zkittles Cake', 25, 'flower', 'Premium greenhouse-grown cannabis strain', '[{"min_qty": 500, "price": 20}]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Zkittles+Cake'),
('Cherry Lime Reserve', 25, 'flower', 'Premium greenhouse-grown cannabis strain', '[{"min_qty": 500, "price": 20}]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Cherry+Lime+Reserve'),
('Diesel Dawg', 25, 'flower', 'Premium greenhouse-grown cannabis strain', '[{"min_qty": 500, "price": 20}]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Diesel+Dawg'),
('King Sherbet', 25, 'flower', 'Premium greenhouse-grown cannabis strain', '[{"min_qty": 500, "price": 20}]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=King+Sherbet'),
('Sour Cookies', 25, 'flower', 'Premium greenhouse-grown cannabis strain', '[{"min_qty": 500, "price": 20}]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Sour+Cookies'),
('Gelato Cake', 25, 'flower', 'Premium greenhouse-grown cannabis strain', '[{"min_qty": 500, "price": 20}]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Gelato+Cake'),

-- GREENHOUSE @18
('Gorilla Cookies', 18, 'flower', 'Quality greenhouse-grown cannabis strain', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Gorilla+Cookies'),
('Tora Bora', 18, 'flower', 'Quality greenhouse-grown cannabis strain', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Tora+Bora'),
('Hulk Berry', 18, 'flower', 'Quality greenhouse-grown cannabis strain', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Hulk+Berry'),
('Wifi Chemdawg', 18, 'flower', 'Quality greenhouse-grown cannabis strain', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Wifi+Chemdawg'),

-- INDOOR @45
('Black Cherry Punch', 45, 'flower', 'Premium indoor-grown cannabis strain', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Black+Cherry+Punch'),
('Fig Jam', 45, 'flower', 'Premium indoor-grown cannabis strain', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Fig+Jam'),
('Platinum Kush', 45, 'flower', 'Premium indoor-grown cannabis strain', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Platinum+Kush'),
('Red Delicious', 45, 'flower', 'Premium indoor-grown cannabis strain', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Red+Delicious'),
('Slurricane', 45, 'flower', 'Premium indoor-grown cannabis strain', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Slurricane'),
('Mandoran', 45, 'flower', 'Premium indoor-grown cannabis strain', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Mandoran'),
('Hitler', 45, 'flower', 'Premium indoor-grown cannabis strain', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Hitler'),

-- PRE ROLLS @25 (some have special pricing)
('Super Cheese Pre-Roll', 25, 'joints', 'Premium pre-rolled joint', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Super+Cheese+Pre-Roll'),
('Monkey Business Pre-Roll', 15, 'joints', 'Premium pre-rolled joint', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Monkey+Business'),
('LSD Pre-Roll', 25, 'joints', 'Premium pre-rolled joint', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=LSD'),
('10th Planet Pre-Roll', 25, 'joints', 'Premium pre-rolled joint', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=10th+Planet'),
('Bubba Kush Pre-Roll', 25, 'joints', 'Premium pre-rolled joint', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Bubba+Kush'),
('Papa Smurf Pre-Roll', 25, 'joints', 'Premium pre-rolled joint', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Papa+Smurf'),
('Zkittles Cake Pre-Roll', 25, 'joints', 'Premium pre-rolled joint', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Zkittles+Cake+Pre-Roll'),
('Cherry Lime Reserve Pre-Roll', 25, 'joints', 'Premium pre-rolled joint', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Cherry+Lime+Reserve+Pre-Roll'),
('King Sherbet Pre-Roll', 25, 'joints', 'Premium pre-rolled joint', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=King+Sherbet+Pre-Roll'),
('Super Runtzz Pre-Roll', 25, 'joints', 'Premium pre-rolled joint', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Super+Runtzz'),

-- EXTRACTS - EDIBLES
('Fizzy Drinks', 50, 'edibles', 'Cannabis-infused fizzy drinks', '[]', 100, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Fizzy+Drinks'),
('Jellies', 25, 'edibles', 'Cannabis-infused jellies', '[]', 100, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Jellies'),

-- EXTRACTS - DABS
('Dabs Variety', 150, 'concentrate', 'Premium cannabis concentrates and dabs', '[]', 50, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Dabs'),

-- EXTRACTS - VAPE PENS
('Vape Pen with Battery and Charger', 500, 'headshop', 'Complete vape pen setup with battery and charger', '[]', 20, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Vape+Pen'),

-- SMALL BUD - POPCORN
('Chocolate Kush Popcorn', 20, 'flower', 'Small bud popcorn quality', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Chocolate+Kush+Popcorn'),
('Jungle Cookies Popcorn', 18, 'flower', 'Small bud popcorn quality', '[]', 1000, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Jungle+Cookies+Popcorn'),

-- 420 STANDS (moved to headshop category as requested)
('420 Stand', 350, 'headshop', 'Premium 420 display stand', '[]', 10, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=420+Stand'),
('Dust', 5, 'headshop', 'Cannabis dust and shake', '[]', 100, false, 'https://via.placeholder.com/300x300/1a1c28/00f2fe?text=Dust');

-- Create stock levels for all new products at both facility and shop locations
INSERT INTO stock_levels (product_id, location_id, quantity)
SELECT p.id, l.id, 0
FROM products p
CROSS JOIN stock_locations l
WHERE p.id != '9064ef14-d377-4d6a-b286-a07fa1877b67'; -- Exclude the existing 420 mix Pre-Roll 