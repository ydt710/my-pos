-- =============================================
-- EXPORT SCRIPT 03b: CANNABIS PRODUCTS DATA
-- =============================================
-- Run this script after 03a_data_stock_locations.sql.
-- This script inserts MONKEY KING cannabis products.
-- =============================================

-- Insert MONKEY KING cannabis products (13 premium products)
INSERT INTO "public"."products" (
    "id", "name", "price", "image_url", "quantity", "category", 
    "thc_max", "cbd_max", "description", "indica", "is_special", 
    "is_new", "special_price", "bulk_prices"
) VALUES 

-- FLOWER PRODUCTS
('11111111-1111-1111-1111-111111111111', 'King Kong OG', 320.00, 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400', 25, 'flower', 28.5, 0.8, 'Premium indica-dominant strain with earthy, pine flavors. Perfect for evening relaxation. Hand-trimmed and cured to perfection by our master growers.', 85, true, false, 280.00, '[{"min_qty": 7, "price": 300.00}, {"min_qty": 14, "price": 280.00}, {"min_qty": 28, "price": 260.00}]'),

('22222222-2222-2222-2222-222222222222', 'Monkey Wrench', 280.00, 'https://images.unsplash.com/photo-1536431311719-398b6704d4cc?w=400', 35, 'flower', 24.2, 1.2, 'Our signature hybrid strain! Perfectly balanced euphoria with creative energy. Citrus and tropical fruit notes make this a customer favorite.', 50, false, true, null, '[{"min_qty": 7, "price": 260.00}, {"min_qty": 14, "price": 240.00}]'),

('33333333-3333-3333-3333-333333333333', 'Banana Hammock', 260.00, 'https://images.unsplash.com/photo-1574848100090-8b0f3b6ab7e6?w=400', 20, 'flower', 22.8, 0.5, 'Smooth sativa with sweet banana and tropical flavors. Great for daytime use and social activities. Dense, frosty buds with amazing bag appeal.', 25, false, false, null, '[{"min_qty": 7, "price": 240.00}, {"min_qty": 14, "price": 220.00}]'),

('44444444-4444-4444-4444-444444444444', 'Purple Gorilla', 300.00, 'https://images.unsplash.com/photo-1498749562436-31c8e5ae4d70?w=400', 15, 'flower', 26.7, 0.9, 'Beautiful purple indica with grape and berry flavors. Heavy-hitting nighttime strain perfect for pain relief and deep sleep. Limited batch available.', 90, true, true, 270.00, '[{"min_qty": 7, "price": 280.00}, {"min_qty": 14, "price": 260.00}]'),

-- PRE-ROLLS / JOINTS
('55555555-5555-5555-5555-555555555555', 'King Size Joint - OG Kush', 45.00, 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400', 50, 'joints', 24.5, 0.6, '1.5g pre-roll made with premium OG Kush flower. Perfectly rolled with organic hemp paper and glass tip. Ready to light and enjoy!', 75, false, false, null, '[{"min_qty": 5, "price": 42.00}, {"min_qty": 10, "price": 40.00}]'),

('66666666-6666-6666-6666-666666666666', 'Monkey Pack - Mixed Joints', 180.00, 'https://images.unsplash.com/photo-1585948044686-bce3230b0816?w=400', 25, 'joints', 25.0, 0.8, '5-pack of assorted premium pre-rolls. Mix of indica, sativa, and hybrid strains. Perfect variety pack for different moods and occasions.', 60, true, true, 160.00, null),

-- CONCENTRATES
('77777777-7777-7777-7777-777777777777', 'Royal Rosin - Live', 850.00, 'https://images.unsplash.com/photo-1545146344-7c1f4c0f7b4e?w=400', 12, 'concentrate', 78.2, 0.3, 'Premium live rosin extracted from fresh-frozen flower. Full spectrum terpene profile with incredible flavor. Solventless extraction method.', 70, true, false, null, '[{"min_qty": 2, "price": 800.00}, {"min_qty": 4, "price": 750.00}]'),

('88888888-8888-8888-8888-888888888888', 'Shatter - Golden Monkey', 420.00, 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=400', 20, 'concentrate', 85.5, 0.1, 'Crystal clear golden shatter with incredible potency. Clean BHO extraction with amazing flavor profile. Perfect for dabbing enthusiasts.', 80, false, false, null, '[{"min_qty": 2, "price": 400.00}, {"min_qty": 4, "price": 380.00}]'),

-- EDIBLES
('99999999-9999-9999-9999-999999999999', 'Monkey Munchies - Gummies', 120.00, 'https://images.unsplash.com/photo-1582543007554-7ad0b37bb8ad?w=400', 30, 'edibles', 10.0, 0.2, '10-pack of delicious fruit gummies. 10mg THC per piece, 100mg total. Made with real fruit flavors and natural ingredients. Lab tested for potency.', 50, false, true, null, '[{"min_qty": 3, "price": 110.00}, {"min_qty": 5, "price": 100.00}]'),

('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Space Brownies', 80.00, 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=400', 25, 'edibles', 50.0, 1.0, 'Classic cannabis brownies made with premium butter. 50mg THC per brownie. Rich chocolate flavor with perfectly balanced effects. Start low, go slow!', 65, false, false, null, '[{"min_qty": 3, "price": 75.00}, {"min_qty": 6, "price": 70.00}]'),

-- ACCESSORIES / HEADSHOP
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'King Kong Glass Bong', 450.00, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400', 8, 'headshop', 0, 0, 'Premium borosilicate glass water pipe. 14-inch tall with percolator and ice catcher. Thick glass construction with beautiful monkey design. Includes bowl piece.', 0, true, false, 400.00, null),

('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Monkey Grinder - 4 Piece', 85.00, 'https://images.unsplash.com/photo-1566648022557-34e6b1b40e66?w=400', 40, 'headshop', 0, 0, 'Premium aluminum 4-piece grinder with kief catcher. Sharp diamond-cut teeth for perfect grind every time. Monkey King logo engraved on top.', 0, false, true, null, '[{"min_qty": 3, "price": 80.00}, {"min_qty": 5, "price": 75.00}]'),

('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Rolling Papers - King Size', 25.00, 'https://images.unsplash.com/photo-1574848100090-8b0f3b6ab7e6?w=400', 100, 'headshop', 0, 0, 'Premium hemp rolling papers. King size with natural gum. 32 papers per pack. Slow and even burn for the perfect smoking experience.', 0, false, false, null, '[{"min_qty": 5, "price": 22.00}, {"min_qty": 10, "price": 20.00}]')

ON CONFLICT (id) DO NOTHING; 