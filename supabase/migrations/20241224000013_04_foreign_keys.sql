-- =============================================
-- EXPORT SCRIPT 04: FOREIGN KEYS (CLEAN REWRITE)
-- =============================================
-- Run this script after 03_data.sql.
-- This script adds all foreign key constraints to the tables.
-- It is idempotent and can be run multiple times safely.
-- =============================================

-- Foreign Keys for: public.order_items
ALTER TABLE "public"."order_items" DROP CONSTRAINT IF EXISTS "order_items_order_id_fkey";
ALTER TABLE "public"."order_items" ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;

ALTER TABLE "public"."order_items" DROP CONSTRAINT IF EXISTS "order_items_product_id_fkey";
ALTER TABLE "public"."order_items" ADD CONSTRAINT "order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;

-- Foreign Keys for: public.orders
ALTER TABLE "public"."orders" DROP CONSTRAINT IF EXISTS "orders_user_id_fkey";
ALTER TABLE "public"."orders" ADD CONSTRAINT "orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;

-- Foreign Keys for: public.profiles
ALTER TABLE "public"."profiles" DROP CONSTRAINT IF EXISTS "profiles_auth_user_id_fkey";
ALTER TABLE "public"."profiles" ADD CONSTRAINT "profiles_auth_user_id_fkey" FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

-- Foreign Keys for: public.reviews
ALTER TABLE "public"."reviews" DROP CONSTRAINT IF EXISTS "reviews_product_id_fkey";
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;

ALTER TABLE "public"."reviews" DROP CONSTRAINT IF EXISTS "reviews_user_id_fkey";
ALTER TABLE "public"."reviews" ADD CONSTRAINT "reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

-- Foreign Keys for: public.stock_levels
ALTER TABLE "public"."stock_levels" DROP CONSTRAINT IF EXISTS "stock_levels_location_id_fkey";
ALTER TABLE "public"."stock_levels" ADD CONSTRAINT "stock_levels_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."stock_locations"("id") ON DELETE CASCADE;

ALTER TABLE "public"."stock_levels" DROP CONSTRAINT IF EXISTS "stock_levels_product_id_fkey";
ALTER TABLE "public"."stock_levels" ADD CONSTRAINT "stock_levels_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;

-- Foreign Keys for: public.stock_movements
ALTER TABLE "public"."stock_movements" DROP CONSTRAINT IF EXISTS "stock_movements_created_by_fkey";
ALTER TABLE "public"."stock_movements" ADD CONSTRAINT "stock_movements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;

ALTER TABLE "public"."stock_movements" DROP CONSTRAINT IF EXISTS "stock_movements_from_location_id_fkey";
ALTER TABLE "public"."stock_movements" ADD CONSTRAINT "stock_movements_from_location_id_fkey" FOREIGN KEY ("from_location_id") REFERENCES "public"."stock_locations"("id") ON DELETE SET NULL;

ALTER TABLE "public"."stock_movements" DROP CONSTRAINT IF EXISTS "stock_movements_product_id_fkey";
ALTER TABLE "public"."stock_movements" ADD CONSTRAINT "stock_movements_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;

ALTER TABLE "public"."stock_movements" DROP CONSTRAINT IF EXISTS "stock_movements_to_location_id_fkey";
ALTER TABLE "public"."stock_movements" ADD CONSTRAINT "stock_movements_to_location_id_fkey" FOREIGN KEY ("to_location_id") REFERENCES "public"."stock_locations"("id") ON DELETE SET NULL;

-- Foreign Keys for: public.transactions
ALTER TABLE "public"."transactions" DROP CONSTRAINT IF EXISTS "transactions_order_id_fkey";
ALTER TABLE "public"."transactions" ADD CONSTRAINT "transactions_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE SET NULL;

ALTER TABLE "public"."transactions" DROP CONSTRAINT IF EXISTS "transactions_user_id_fkey";
ALTER TABLE "public"."transactions" ADD CONSTRAINT "transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;

-- Foreign Keys for: public.user_product_prices
ALTER TABLE "public"."user_product_prices" DROP CONSTRAINT IF EXISTS "user_product_prices_product_id_fkey";
ALTER TABLE "public"."user_product_prices" ADD CONSTRAINT "user_product_prices_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;

ALTER TABLE "public"."user_product_prices" DROP CONSTRAINT IF EXISTS "user_product_prices_user_id_fkey";
ALTER TABLE "public"."user_product_prices" ADD CONSTRAINT "user_product_prices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE; 