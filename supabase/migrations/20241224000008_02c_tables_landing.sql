-- =============================================
-- EXPORT SCRIPT 02c: LANDING & SETTINGS TABLES
-- =============================================
-- Run this after 02b_tables_inventory.sql.
-- Creates landing page and settings tables
-- =============================================

-- Drop landing page and settings tables if they exist
DROP TABLE IF EXISTS "public"."settings" CASCADE;
DROP TABLE IF EXISTS "public"."landing_hero" CASCADE;
DROP TABLE IF EXISTS "public"."landing_categories" CASCADE;
DROP TABLE IF EXISTS "public"."landing_stores" CASCADE;
DROP TABLE IF EXISTS "public"."landing_featured_products" CASCADE;
DROP TABLE IF EXISTS "public"."landing_testimonials" CASCADE;

-- Table: public.settings
CREATE TABLE public.settings (
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
  constraint settings_pkey primary key (id)
);
ALTER TABLE "public"."settings" ENABLE ROW LEVEL SECURITY;

-- Landing Page Tables: public.landing_hero
CREATE TABLE "public"."landing_hero" (
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
ALTER TABLE "public"."landing_hero" ENABLE ROW LEVEL SECURITY;

-- Landing Page Tables: public.landing_categories
CREATE TABLE "public"."landing_categories" (
    "id" serial PRIMARY KEY,
    "title" text NOT NULL DEFAULT 'Our Categories',
    "subtitle" text NOT NULL DEFAULT 'Explore our premium selection',
    "categories" jsonb DEFAULT '[]'::jsonb,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "public"."landing_categories" ENABLE ROW LEVEL SECURITY;

-- Landing Page Tables: public.landing_stores
CREATE TABLE "public"."landing_stores" (
    "id" serial PRIMARY KEY,
    "title" text NOT NULL DEFAULT 'Our Locations',
    "description" text NOT NULL DEFAULT 'Find us at multiple convenient locations across the city.',
    "background_image_url" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "public"."landing_stores" ENABLE ROW LEVEL SECURITY;

-- Landing Page Tables: public.landing_featured_products
CREATE TABLE "public"."landing_featured_products" (
    "id" serial PRIMARY KEY,
    "title" text NOT NULL DEFAULT 'Featured Products',
    "subtitle" text NOT NULL DEFAULT 'Hand-picked selections from our premium collection',
    "product_ids" jsonb DEFAULT '[]'::jsonb,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "public"."landing_featured_products" ENABLE ROW LEVEL SECURITY;

-- Landing Page Tables: public.landing_testimonials
CREATE TABLE "public"."landing_testimonials" (
    "id" serial PRIMARY KEY,
    "title" text NOT NULL DEFAULT 'What Our Customers Say',
    "testimonials" jsonb DEFAULT '[]'::jsonb,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "public"."landing_testimonials" ENABLE ROW LEVEL SECURITY;

-- Create indexes for landing page tables
CREATE INDEX IF NOT EXISTS idx_landing_hero_updated_at ON public.landing_hero USING btree (updated_at);
CREATE INDEX IF NOT EXISTS idx_landing_categories_updated_at ON public.landing_categories USING btree (updated_at);
CREATE INDEX IF NOT EXISTS idx_landing_stores_updated_at ON public.landing_stores USING btree (updated_at);
CREATE INDEX IF NOT EXISTS idx_landing_featured_products_updated_at ON public.landing_featured_products USING btree (updated_at);
CREATE INDEX IF NOT EXISTS idx_landing_testimonials_updated_at ON public.landing_testimonials USING btree (updated_at); 