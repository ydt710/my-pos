-- =============================================
-- EXPORT SCRIPT 02a: CORE TABLES
-- =============================================
-- Run this after 01_extensions.sql.
-- Creates core business tables: profiles, products, orders
-- =============================================

-- Create the transaction category enum type that matches the current system
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

-- Drop core tables if they exist
DROP TABLE IF EXISTS "public"."products" CASCADE;
DROP TABLE IF EXISTS "public"."profiles" CASCADE;
DROP TABLE IF EXISTS "public"."orders" CASCADE;
DROP TABLE IF EXISTS "public"."order_items" CASCADE;

-- Table: public.products
CREATE TABLE "public"."products" (
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
ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;

-- Table: public.profiles
CREATE TABLE "public"."profiles" (
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
    CONSTRAINT "profiles_pkey" PRIMARY KEY (id),
    CONSTRAINT "profiles_auth_user_id_key" UNIQUE (auth_user_id)
);
ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;

-- Table: public.orders
CREATE TABLE "public"."orders" (
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
ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;

-- Table: public.order_items
CREATE TABLE "public"."order_items" (
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
ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY; 