alter table "public"."orders" drop constraint "orders_status_check";

alter table "public"."credit_ledger" add column "method" text;

alter table "public"."order_items" disable row level security;

alter table "public"."orders" add constraint "orders_status_check" CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[]))) not valid;

alter table "public"."orders" validate constraint "orders_status_check";


