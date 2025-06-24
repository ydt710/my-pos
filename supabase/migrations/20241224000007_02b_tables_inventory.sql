-- =============================================
-- EXPORT SCRIPT 02b: INVENTORY TABLES
-- =============================================
-- Run this after 02a_tables_core.sql.
-- Creates inventory and stock management tables
-- =============================================

-- Drop inventory tables if they exist
DROP TABLE IF EXISTS "public"."stock_locations" CASCADE;
DROP TABLE IF EXISTS "public"."stock_levels" CASCADE;
DROP TABLE IF EXISTS "public"."stock_movements" CASCADE;
DROP TABLE IF EXISTS "public"."reviews" CASCADE;
DROP TABLE IF EXISTS "public"."transactions" CASCADE;
DROP TABLE IF EXISTS "public"."user_product_prices" CASCADE;
DROP TABLE IF EXISTS "public"."stock_discrepancies" CASCADE;

-- Table: public.stock_locations
CREATE TABLE "public"."stock_locations" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "name" text NOT NULL,
    CONSTRAINT "stock_locations_pkey" PRIMARY KEY (id),
    CONSTRAINT "stock_locations_name_key" UNIQUE (name)
);
ALTER TABLE "public"."stock_locations" ENABLE ROW LEVEL SECURITY;

-- Table: public.stock_levels
CREATE TABLE "public"."stock_levels" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "product_id" uuid,
    "location_id" uuid,
    "quantity" int4 DEFAULT 0 NOT NULL,
    CONSTRAINT "stock_levels_pkey" PRIMARY KEY (id),
    CONSTRAINT "stock_levels_product_location_unique" UNIQUE (product_id, location_id)
);
ALTER TABLE "public"."stock_levels" ENABLE ROW LEVEL SECURITY;

-- Table: public.stock_movements
CREATE TABLE "public"."stock_movements" (
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
ALTER TABLE "public"."stock_movements" ENABLE ROW LEVEL SECURITY;

-- Table: public.reviews
CREATE TABLE "public"."reviews" (
    "id" uuid DEFAULT uuid_generate_v4() NOT NULL,
    "product_id" uuid,
    "user_id" uuid,
    "rating" int4,
    "comment" text,
    "created_at" timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL,
    CONSTRAINT "reviews_pkey" PRIMARY KEY (id),
    CONSTRAINT "reviews_rating_check" CHECK (rating >= 1 AND rating <= 5)
);
ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;

-- Table: public.transactions
CREATE TABLE "public"."transactions" (
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
ALTER TABLE "public"."transactions" ENABLE ROW LEVEL SECURITY;

-- Table: public.user_product_prices
CREATE TABLE "public"."user_product_prices" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "user_id" uuid,
    "product_id" uuid,
    "custom_price" numeric NOT NULL,
    "created_at" timestamp with time zone DEFAULT now(),
    CONSTRAINT "user_product_prices_pkey" PRIMARY KEY (id),
    CONSTRAINT "user_product_prices_user_product_unique" UNIQUE (user_id, product_id)
);
ALTER TABLE "public"."user_product_prices" ENABLE ROW LEVEL SECURITY;

-- Table: public.stock_discrepancies
CREATE TABLE public.stock_discrepancies (
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
ALTER TABLE "public"."stock_discrepancies" ENABLE ROW LEVEL SECURITY;

-- Create index for stock_discrepancies
CREATE INDEX IF NOT EXISTS idx_stock_discrepancies_transfer_id ON public.stock_discrepancies USING btree (transfer_id); 