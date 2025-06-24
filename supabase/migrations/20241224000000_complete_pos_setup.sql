-- =============================================
-- COMPLETE POS SYSTEM SETUP - ALL IN ONE
-- =============================================
-- This migration combines all export scripts into a single file
-- Run this for a complete database setup
-- =============================================

-- =============================================
-- PART 1: EXTENSIONS
-- =============================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";
CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";

-- =============================================
-- PART 2: CREATE ENUM TYPES
-- =============================================
DROP TYPE IF EXISTS public.transaction_category CASCADE;
CREATE TYPE public.transaction_category AS ENUM (
    'sale',
    'credit_payment', 
    'cash_payment',
    'overpayment_credit',
    'cash_change',
    'pos_sale',
    'online_sale', 
    'debt_payment',
    'cancellation',
    'credit_adjustment',
    'debit_adjustment',
    'balance_adjustment'
);

-- =============================================
-- PART 3: CREATE TABLES
-- =============================================

-- Core Tables
CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" uuid DEFAULT uuid_generate_v4() NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "name" text,
    "price" numeric,
    "image_url" text,
    "quantity" int4 DEFAULT 0 NOT NULL,
    "category" text DEFAULT 'flower' NOT NULL,
    "thc_max" numeric,
    "cbd_max" numeric,
    "description" text DEFAULT 'Add product description jou sleg wetter.' NOT NULL,
    "indica" int4,
    "average_rating" numeric,
    "review_count" int4 DEFAULT 0,
    "is_special" bool DEFAULT false,
    "is_new" bool DEFAULT false,
    "special_price" numeric,
    "bulk_prices" jsonb,
    CONSTRAINT "products_indica_check" CHECK (indica >= 0 AND indica <= 100),
    CONSTRAINT "products_pkey" PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "first_name" text,
    "last_name" text,
    "phone_number" text,
    "email" text,
    "created_at" timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL,
    "display_name" text,
    "address" text,
    "notifications" bool DEFAULT true,
    "dark_mode" bool DEFAULT false,
    "is_admin" bool DEFAULT false,
    "role" text DEFAULT 'user',
    "auth_user_id" uuid,
    "signature_url" text,
    "id_image_url" text,
    "signed_contract_url" text,
    "balance" numeric DEFAULT 0,
    CONSTRAINT "profiles_pkey" PRIMARY KEY (id),
    CONSTRAINT "profiles_auth_user_id_key" UNIQUE (auth_user_id)
);

CREATE TABLE IF NOT EXISTS "public"."orders" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "total" numeric NOT NULL,
    "status" text DEFAULT 'pending' NOT NULL,
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now(),
    "user_id" uuid,
    "guest_info" jsonb,
    "order_number" text,
    "deleted_at" timestamp without time zone,
    "deleted_by" uuid,
    "deleted_by_role" text,
    "payment_method" text DEFAULT 'cash',
    "is_pos_order" bool DEFAULT false,
    "note" text,
    "cash_given" numeric DEFAULT 0,
    "change_given" numeric DEFAULT 0,
    "subtotal" numeric DEFAULT 0,
    "tax" numeric DEFAULT 0,
    "shipping_fee" numeric DEFAULT 0,
    CONSTRAINT "orders_pkey" PRIMARY KEY (id),
    CONSTRAINT "orders_status_check" CHECK (status = ANY (ARRAY['pending', 'processing', 'completed', 'cancelled']))
);

CREATE TABLE IF NOT EXISTS "public"."order_items" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "order_id" uuid,
    "product_id" uuid,
    "quantity" int4 NOT NULL,
    "price" numeric NOT NULL,
    "created_at" timestamp with time zone DEFAULT now(),
    CONSTRAINT "order_items_pkey" PRIMARY KEY (id),
    CONSTRAINT "order_items_price_check" CHECK (price >= 0),
    CONSTRAINT "order_items_quantity_check" CHECK (quantity > 0)
);

-- Inventory Tables
CREATE TABLE IF NOT EXISTS "public"."stock_locations" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "name" text NOT NULL,
    CONSTRAINT "stock_locations_pkey" PRIMARY KEY (id),
    CONSTRAINT "stock_locations_name_key" UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS "public"."stock_levels" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "product_id" uuid,
    "location_id" uuid,
    "quantity" int4 DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now(),
    CONSTRAINT "stock_levels_pkey" PRIMARY KEY (id),
    CONSTRAINT "stock_levels_product_location_unique" UNIQUE (product_id, location_id)
);

CREATE TABLE IF NOT EXISTS "public"."stock_movements" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "product_id" uuid,
    "from_location_id" uuid,
    "to_location_id" uuid,
    "quantity" int4 NOT NULL,
    "type" text NOT NULL,
    "note" text,
    "created_at" timestamp with time zone DEFAULT now(),
    "status" text DEFAULT 'done',
    "created_by" uuid,
    "order_id" uuid,
    CONSTRAINT "stock_movements_pkey" PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS "public"."reviews" (
    "id" uuid DEFAULT uuid_generate_v4() NOT NULL,
    "product_id" uuid,
    "user_id" uuid,
    "rating" int4,
    "comment" text,
    "created_at" timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL,
    CONSTRAINT "reviews_pkey" PRIMARY KEY (id),
    CONSTRAINT "reviews_rating_check" CHECK (rating >= 1 AND rating <= 5)
);

CREATE TABLE IF NOT EXISTS "public"."transactions" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "user_id" uuid,
    "order_id" uuid,
    "method" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "note" text,
    "affects_balance" bool DEFAULT false NOT NULL,
    "affects_cash_collected" bool DEFAULT false NOT NULL,
    "cash_amount" numeric DEFAULT 0 NOT NULL,
    "balance_amount" numeric DEFAULT 0 NOT NULL,
    "total_amount" numeric DEFAULT 0 NOT NULL,
    "category" public.transaction_category NOT NULL,
    "description" text,
    CONSTRAINT "transactions_pkey" PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS "public"."user_product_prices" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "user_id" uuid,
    "product_id" uuid,
    "custom_price" numeric NOT NULL,
    "created_at" timestamp with time zone DEFAULT now(),
    CONSTRAINT "user_product_prices_pkey" PRIMARY KEY (id),
    CONSTRAINT "user_product_prices_user_product_unique" UNIQUE (user_id, product_id)
);

CREATE TABLE IF NOT EXISTS "public"."stock_discrepancies" (
    id serial not null,
    product_id uuid not null,
    expected_quantity numeric not null,
    actual_quantity numeric not null,
    reason text null,
    reported_by uuid null,
    created_at timestamp with time zone null default now(),
    transfer_id uuid null,
    constraint stock_discrepancies_pkey primary key (id)
);

-- Settings Table
CREATE TABLE IF NOT EXISTS public.settings (
    id serial not null,
    store_name text null,
    store_email text null,
    store_phone text null,
    store_address text null,
    currency text null,
    tax_rate numeric null,
    shipping_fee numeric null,
    min_order_amount numeric null,
    free_shipping_threshold numeric null,
    business_hours jsonb null,
    notification_email text null,
    maintenance_mode boolean null default false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    constraint settings_pkey primary key (id)
);

-- Landing Page Tables
CREATE TABLE IF NOT EXISTS "public"."landing_hero" (
    "id" serial PRIMARY KEY,
    "title" text NOT NULL DEFAULT 'MONKEY KING',
    "subtitle" text NOT NULL DEFAULT 'Family-Grown Cannabis, Crafted with Care',
    "description" text NOT NULL DEFAULT 'Premium quality cannabis products grown with love and expertise.',
    "background_image_url" text,
    "featured_products" jsonb DEFAULT '[]'::jsonb,
    "cta_text" text NOT NULL DEFAULT 'Shop Now',
    "cta_link" text NOT NULL DEFAULT '/products',
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."landing_categories" (
    "id" serial PRIMARY KEY,
    "title" text NOT NULL DEFAULT 'Our Categories',
    "subtitle" text NOT NULL DEFAULT 'Explore our premium selection',
    "categories" jsonb DEFAULT '[]'::jsonb,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."landing_stores" (
    "id" serial PRIMARY KEY,
    "title" text NOT NULL DEFAULT 'Our Locations',
    "description" text NOT NULL DEFAULT 'Find us at multiple convenient locations across the city.',
    "background_image_url" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."landing_featured_products" (
    "id" serial PRIMARY KEY,
    "title" text NOT NULL DEFAULT 'Featured Products',
    "subtitle" text NOT NULL DEFAULT 'Hand-picked selections from our premium collection',
    "product_ids" jsonb DEFAULT '[]'::jsonb,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS "public"."landing_testimonials" (
    "id" serial PRIMARY KEY,
    "title" text NOT NULL DEFAULT 'What Our Customers Say',
    "testimonials" jsonb DEFAULT '[]'::jsonb,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

-- Enable RLS on all tables
ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."stock_locations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."stock_levels" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."stock_movements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."transactions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."user_product_prices" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."stock_discrepancies" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."landing_hero" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."landing_categories" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."landing_stores" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."landing_featured_products" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."landing_testimonials" ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_stock_discrepancies_transfer_id ON public.stock_discrepancies USING btree (transfer_id);
CREATE INDEX IF NOT EXISTS idx_landing_hero_updated_at ON public.landing_hero USING btree (updated_at);
CREATE INDEX IF NOT EXISTS idx_landing_categories_updated_at ON public.landing_categories USING btree (updated_at);
CREATE INDEX IF NOT EXISTS idx_landing_stores_updated_at ON public.landing_stores USING btree (updated_at);
CREATE INDEX IF NOT EXISTS idx_landing_featured_products_updated_at ON public.landing_featured_products USING btree (updated_at);
CREATE INDEX IF NOT EXISTS idx_landing_testimonials_updated_at ON public.landing_testimonials USING btree (updated_at);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id_created_at ON public.transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_category_created_at ON public.transactions(category, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_order_id ON public.transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_orders_user_id_status ON public.orders(user_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_auth_user_id ON public.profiles(auth_user_id); 