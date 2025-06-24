-- =============================================
-- INITIAL DATA AND FUNCTIONS
-- =============================================

-- =============================================
-- PART 1: INITIAL DATA
-- =============================================

-- Insert stock locations
INSERT INTO "public"."stock_locations" ("id", "name") VALUES
('e0ff9565-e490-45e9-991f-298918e4514a', 'shop'),
('5f69d311-5373-47a3-b0b3-3a6a9b499b7c', 'facility'),
('7c3b2e5a-8b8e-4a9e-8b1a-2c3d4e5f6a7b', 'storage')
ON CONFLICT (name) DO NOTHING;

-- Insert MONKEY KING cannabis products
INSERT INTO "public"."products" (
    "id", "name", "price", "image_url", "quantity", "category", 
    "thc_max", "cbd_max", "description", "indica", "is_special", 
    "is_new", "special_price", "bulk_prices"
) VALUES 
('11111111-1111-1111-1111-111111111111', 'King Kong OG', 320.00, 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400', 25, 'flower', 28.5, 0.8, 'Premium indica-dominant strain with earthy, pine flavors. Perfect for evening relaxation. Hand-trimmed and cured to perfection by our master growers.', 85, true, false, 280.00, '[{"min_qty": 7, "price": 300.00}, {"min_qty": 14, "price": 280.00}, {"min_qty": 28, "price": 260.00}]'),
('22222222-2222-2222-2222-222222222222', 'Monkey Wrench', 280.00, 'https://images.unsplash.com/photo-1536431311719-398b6704d4cc?w=400', 35, 'flower', 24.2, 1.2, 'Our signature hybrid strain! Perfectly balanced euphoria with creative energy. Citrus and tropical fruit notes make this a customer favorite.', 50, false, true, null, '[{"min_qty": 7, "price": 260.00}, {"min_qty": 14, "price": 240.00}]'),
('33333333-3333-3333-3333-333333333333', 'Banana Hammock', 260.00, 'https://images.unsplash.com/photo-1574848100090-8b0f3b6ab7e6?w=400', 20, 'flower', 22.8, 0.5, 'Smooth sativa with sweet banana and tropical flavors. Great for daytime use and social activities. Dense, frosty buds with amazing bag appeal.', 25, false, false, null, '[{"min_qty": 7, "price": 240.00}, {"min_qty": 14, "price": 220.00}]'),
('44444444-4444-4444-4444-444444444444', 'Purple Gorilla', 300.00, 'https://images.unsplash.com/photo-1498749562436-31c8e5ae4d70?w=400', 15, 'flower', 26.7, 0.9, 'Beautiful purple indica with grape and berry flavors. Heavy-hitting nighttime strain perfect for pain relief and deep sleep. Limited batch available.', 90, true, true, 270.00, '[{"min_qty": 7, "price": 280.00}, {"min_qty": 14, "price": 260.00}]'),
('55555555-5555-5555-5555-555555555555', 'King Size Joint - OG Kush', 45.00, 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400', 50, 'joints', 24.5, 0.6, '1.5g pre-roll made with premium OG Kush flower. Perfectly rolled with organic hemp paper and glass tip. Ready to light and enjoy!', 75, false, false, null, '[{"min_qty": 5, "price": 42.00}, {"min_qty": 10, "price": 40.00}]'),
('66666666-6666-6666-6666-666666666666', 'Monkey Pack - Mixed Joints', 180.00, 'https://images.unsplash.com/photo-1585948044686-bce3230b0816?w=400', 25, 'joints', 25.0, 0.8, '5-pack of assorted premium pre-rolls. Mix of indica, sativa, and hybrid strains. Perfect variety pack for different moods and occasions.', 60, true, true, 160.00, null),
('77777777-7777-7777-7777-777777777777', 'Royal Rosin - Live', 850.00, 'https://images.unsplash.com/photo-1545146344-7c1f4c0f7b4e?w=400', 12, 'concentrate', 78.2, 0.3, 'Premium live rosin extracted from fresh-frozen flower. Full spectrum terpene profile with incredible flavor. Solventless extraction method.', 70, true, false, null, '[{"min_qty": 2, "price": 800.00}, {"min_qty": 4, "price": 750.00}]'),
('88888888-8888-8888-8888-888888888888', 'Shatter - Golden Monkey', 420.00, 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=400', 20, 'concentrate', 85.5, 0.1, 'Crystal clear golden shatter with incredible potency. Clean BHO extraction with amazing flavor profile. Perfect for dabbing enthusiasts.', 80, false, false, null, '[{"min_qty": 2, "price": 400.00}, {"min_qty": 4, "price": 380.00}]'),
('99999999-9999-9999-9999-999999999999', 'Monkey Munchies - Gummies', 120.00, 'https://images.unsplash.com/photo-1582543007554-7ad0b37bb8ad?w=400', 30, 'edibles', 10.0, 0.2, '10-pack of delicious fruit gummies. 10mg THC per piece, 100mg total. Made with real fruit flavors and natural ingredients. Lab tested for potency.', 50, false, true, null, '[{"min_qty": 3, "price": 110.00}, {"min_qty": 5, "price": 100.00}]'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Space Brownies', 80.00, 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=400', 25, 'edibles', 50.0, 1.0, 'Classic cannabis brownies made with premium butter. 50mg THC per brownie. Rich chocolate flavor with perfectly balanced effects. Start low, go slow!', 65, false, false, null, '[{"min_qty": 3, "price": 75.00}, {"min_qty": 6, "price": 70.00}]'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'King Kong Glass Bong', 450.00, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400', 8, 'headshop', 0, 0, 'Premium borosilicate glass water pipe. 14-inch tall with percolator and ice catcher. Thick glass construction with beautiful monkey design. Includes bowl piece.', 0, true, false, 400.00, null),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Monkey Grinder - 4 Piece', 85.00, 'https://images.unsplash.com/photo-1566648022557-34e6b1b40e66?w=400', 40, 'headshop', 0, 0, 'Premium aluminum 4-piece grinder with kief catcher. Sharp diamond-cut teeth for perfect grind every time. Monkey King logo engraved on top.', 0, false, true, null, '[{"min_qty": 3, "price": 80.00}, {"min_qty": 5, "price": 75.00}]'),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Rolling Papers - King Size', 25.00, 'https://images.unsplash.com/photo-1574848100090-8b0f3b6ab7e6?w=400', 100, 'headshop', 0, 0, 'Premium hemp rolling papers. King size with natural gum. 32 papers per pack. Slow and even burn for the perfect smoking experience.', 0, false, false, null, '[{"min_qty": 5, "price": 22.00}, {"min_qty": 10, "price": 20.00}]')
ON CONFLICT (id) DO NOTHING;

-- Insert stock levels
INSERT INTO "public"."stock_levels" ("product_id", "location_id", "quantity") VALUES
('11111111-1111-1111-1111-111111111111', 'e0ff9565-e490-45e9-991f-298918e4514a', 25),
('22222222-2222-2222-2222-222222222222', 'e0ff9565-e490-45e9-991f-298918e4514a', 35),
('33333333-3333-3333-3333-333333333333', 'e0ff9565-e490-45e9-991f-298918e4514a', 20),
('44444444-4444-4444-4444-444444444444', 'e0ff9565-e490-45e9-991f-298918e4514a', 15),
('55555555-5555-5555-5555-555555555555', 'e0ff9565-e490-45e9-991f-298918e4514a', 50),
('66666666-6666-6666-6666-666666666666', 'e0ff9565-e490-45e9-991f-298918e4514a', 25),
('77777777-7777-7777-7777-777777777777', 'e0ff9565-e490-45e9-991f-298918e4514a', 12),
('88888888-8888-8888-8888-888888888888', 'e0ff9565-e490-45e9-991f-298918e4514a', 20),
('99999999-9999-9999-9999-999999999999', 'e0ff9565-e490-45e9-991f-298918e4514a', 30),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'e0ff9565-e490-45e9-991f-298918e4514a', 25),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'e0ff9565-e490-45e9-991f-298918e4514a', 8),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'e0ff9565-e490-45e9-991f-298918e4514a', 40),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'e0ff9565-e490-45e9-991f-298918e4514a', 100)
ON CONFLICT (product_id, location_id) DO NOTHING;

-- Insert default settings
INSERT INTO public.settings (
    id, store_name, store_email, store_phone, store_address, 
    currency, tax_rate, shipping_fee, min_order_amount, 
    free_shipping_threshold, business_hours, notification_email, 
    maintenance_mode
) VALUES (
    1, 'My POS Store', 'admin@mypos.com', '+27 123 456 7890', 
    '123 Main St, City, Country', 'ZAR', 15.0, 50.0, 100.0, 
    500.0, '{"monday": "9:00-17:00", "tuesday": "9:00-17:00", "wednesday": "9:00-17:00", "thursday": "9:00-17:00", "friday": "9:00-17:00", "saturday": "9:00-15:00", "sunday": "closed"}',
    'notifications@mypos.com', false
) ON CONFLICT (id) DO UPDATE SET
    store_name = EXCLUDED.store_name,
    currency = EXCLUDED.currency,
    tax_rate = EXCLUDED.tax_rate;

-- Insert landing page content
INSERT INTO "public"."landing_hero" (title, subtitle, description, featured_products, cta_text, cta_link)
VALUES (
    'MONKEY KING',
    'Family-Grown Cannabis, Crafted with Care',
    'Premium quality cannabis products grown with love and expertise by our family for yours.',
    '["11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222", "44444444-4444-4444-4444-444444444444"]'::jsonb,
    'Shop Now',
    '/products'
) ON CONFLICT DO NOTHING;

INSERT INTO "public"."landing_categories" (title, subtitle, categories)
VALUES (
    'Our Categories',
    'Explore our premium selection of carefully curated cannabis products',
    '[
        {
            "id": "flower",
            "name": "Premium Flower",
            "description": "Hand-selected, perfectly cured cannabis flower",
            "color": "#00f2fe"
        },
        {
            "id": "joints",
            "name": "Pre-Rolls",
            "description": "Expertly rolled joints ready to enjoy",
            "color": "#43e97b"
        },
        {
            "id": "concentrate",
            "name": "Concentrates",
            "description": "High-potency extracts and concentrates",
            "color": "#ff6a00"
        },
        {
            "id": "edibles",
            "name": "Edibles",
            "description": "Delicious cannabis-infused treats",
            "color": "#b993d6"
        },
        {
            "id": "headshop",
            "name": "Accessories",
            "description": "Premium smoking accessories and tools",
            "color": "#fcdd43"
        }
    ]'::jsonb
) ON CONFLICT DO NOTHING;

INSERT INTO "public"."landing_stores" (title, description)
VALUES (
    'Visit Our Locations',
    'We operate multiple convenient locations across the city, each offering the same premium quality products and exceptional service you expect from Monkey King Cannabis.'
) ON CONFLICT DO NOTHING;

INSERT INTO "public"."landing_featured_products" (title, subtitle, product_ids)
VALUES (
    'Featured Products',
    'Hand-picked selections from our premium collection',
    '["11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222", "44444444-4444-4444-4444-444444444444", "77777777-7777-7777-7777-777777777777"]'::jsonb
) ON CONFLICT DO NOTHING;

INSERT INTO "public"."landing_testimonials" (title, testimonials)
VALUES (
    'What Our Customers Say',
    '[
        {
            "name": "Sarah M.",
            "rating": 5,
            "comment": "Absolutely the best quality I have found anywhere. The staff is knowledgeable and the product selection is outstanding.",
            "verified": true
        },
        {
            "name": "Michael R.",
            "rating": 5,
            "comment": "Family-grown really makes a difference. You can taste the care and attention that goes into every product.",
            "verified": true
        },
        {
            "name": "Jennifer L.",
            "rating": 5,
            "comment": "Clean, professional, and always consistent quality. My go-to dispensary for over two years now.",
            "verified": true
        },
        {
            "name": "David K.",
            "rating": 5,
            "comment": "The pre-rolls are perfectly rolled and the flower is always fresh. Great prices too!",
            "verified": true
        }
    ]'::jsonb
) ON CONFLICT DO NOTHING;

-- =============================================
-- PART 2: FOREIGN KEYS
-- =============================================

-- Foreign Keys for order_items
ALTER TABLE "public"."order_items" DROP CONSTRAINT IF EXISTS "order_items_order_id_fkey";
ALTER TABLE "public"."order_items" ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;

ALTER TABLE "public"."order_items" DROP CONSTRAINT IF EXISTS "order_items_product_id_fkey";
ALTER TABLE "public"."order_items" ADD CONSTRAINT "order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;

-- Foreign Keys for orders
ALTER TABLE "public"."orders" DROP CONSTRAINT IF EXISTS "orders_user_id_fkey";
ALTER TABLE "public"."orders" ADD CONSTRAINT "orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;

-- Foreign Keys for profiles
ALTER TABLE "public"."profiles" DROP CONSTRAINT IF EXISTS "profiles_auth_user_id_fkey";
ALTER TABLE "public"."profiles" ADD CONSTRAINT "profiles_auth_user_id_fkey" FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

-- Foreign Keys for reviews
ALTER TABLE "public"."reviews" DROP CONSTRAINT IF EXISTS "reviews_product_id_fkey";
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;

ALTER TABLE "public"."reviews" DROP CONSTRAINT IF EXISTS "reviews_user_id_fkey";
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

-- Foreign Keys for stock_levels
ALTER TABLE "public"."stock_levels" DROP CONSTRAINT IF EXISTS "stock_levels_location_id_fkey";
ALTER TABLE "public"."stock_levels" ADD CONSTRAINT "stock_levels_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."stock_locations"("id") ON DELETE CASCADE;

ALTER TABLE "public"."stock_levels" DROP CONSTRAINT IF EXISTS "stock_levels_product_id_fkey";
ALTER TABLE "public"."stock_levels" ADD CONSTRAINT "stock_levels_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;

-- Foreign Keys for stock_movements
ALTER TABLE "public"."stock_movements" DROP CONSTRAINT IF EXISTS "stock_movements_created_by_fkey";
ALTER TABLE "public"."stock_movements" ADD CONSTRAINT "stock_movements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;

ALTER TABLE "public"."stock_movements" DROP CONSTRAINT IF EXISTS "stock_movements_from_location_id_fkey";
ALTER TABLE "public"."stock_movements" ADD CONSTRAINT "stock_movements_from_location_id_fkey" FOREIGN KEY ("from_location_id") REFERENCES "public"."stock_locations"("id") ON DELETE SET NULL;

ALTER TABLE "public"."stock_movements" DROP CONSTRAINT IF EXISTS "stock_movements_product_id_fkey";
ALTER TABLE "public"."stock_movements" ADD CONSTRAINT "stock_movements_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;

ALTER TABLE "public"."stock_movements" DROP CONSTRAINT IF EXISTS "stock_movements_to_location_id_fkey";
ALTER TABLE "public"."stock_movements" ADD CONSTRAINT "stock_movements_to_location_id_fkey" FOREIGN KEY ("to_location_id") REFERENCES "public"."stock_locations"("id") ON DELETE SET NULL;

-- Foreign Keys for transactions
ALTER TABLE "public"."transactions" DROP CONSTRAINT IF EXISTS "transactions_order_id_fkey";
ALTER TABLE "public"."transactions" ADD CONSTRAINT "transactions_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE SET NULL;

ALTER TABLE "public"."transactions" DROP CONSTRAINT IF EXISTS "transactions_user_id_fkey";
ALTER TABLE "public"."transactions" ADD CONSTRAINT "transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;

-- Foreign Keys for user_product_prices
ALTER TABLE "public"."user_product_prices" DROP CONSTRAINT IF EXISTS "user_product_prices_product_id_fkey";
ALTER TABLE "public"."user_product_prices" ADD CONSTRAINT "user_product_prices_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;

ALTER TABLE "public"."user_product_prices" DROP CONSTRAINT IF EXISTS "user_product_prices_user_id_fkey";
ALTER TABLE "public"."user_product_prices" ADD CONSTRAINT "user_product_prices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;

-- =============================================
-- PART 3: VIEWS
-- =============================================

CREATE OR REPLACE VIEW "public"."user_balances" AS
SELECT
    p.id AS user_id,
    p.auth_user_id,
    p.display_name AS name,
    p.email,
    p.phone_number AS phone,
    COALESCE(SUM(t.balance_amount), 0) AS balance
FROM 
    public.profiles p
LEFT JOIN 
    public.transactions t ON p.id = t.user_id
GROUP BY 
    p.id, p.auth_user_id, p.display_name, p.email, p.phone_number; 