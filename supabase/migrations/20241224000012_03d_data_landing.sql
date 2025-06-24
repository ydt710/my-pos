-- =============================================
-- EXPORT SCRIPT 03d: LANDING PAGE DATA
-- =============================================
-- Run this script after 03c_data_stock_levels.sql.
-- This script inserts default landing page content.
-- =============================================

-- Insert default landing page content
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