

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."get_users_with_metadata"() RETURNS TABLE("id" "uuid", "email" "text", "created_at" timestamp with time zone, "raw_user_meta_data" "jsonb")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
    -- Check if user is admin
    if not auth.is_admin() then
        raise exception 'Only administrators can view user metadata';
    end if;

    return query
    select 
        au.id,
        au.email::text,
        au.created_at,
        au.raw_user_meta_data
    from auth.users au
    order by au.created_at desc;
end;
$$;


ALTER FUNCTION "public"."get_users_with_metadata"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (new.id, new.email);
    RETURN new;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_product_quantity"("product_id" "uuid", "amount" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
begin
  update products
  set quantity = quantity + amount
  where id = product_id;
end;
$$;


ALTER FUNCTION "public"."increment_product_quantity"("product_id" "uuid", "amount" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
        AND is_admin = true
    );
END;
$$;


ALTER FUNCTION "public"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_product_rating"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  -- Update the product's average rating and review count
  update public.products
  set 
    average_rating = (
      select round(avg(rating)::numeric, 1)
      from public.reviews
      where product_id = new.product_id
    ),
    review_count = (
      select count(*)
      from public.reviews
      where product_id = new.product_id
    )
  where id = new.product_id;
  
  return new;
end;
$$;


ALTER FUNCTION "public"."update_product_rating"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_admin_status"("user_id" "uuid", "is_admin" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
    current_metadata jsonb;
begin
    -- Check if user is admin
    if not auth.is_admin() then
        raise exception 'Only administrators can update user roles';
    end if;

    -- Get current metadata
    select raw_user_meta_data into current_metadata
    from auth.users
    where id = user_id;

    -- Update the metadata
    update auth.users
    set raw_user_meta_data = 
        case 
            when current_metadata is null then 
                jsonb_build_object('is_admin', is_admin)
            else
                current_metadata || jsonb_build_object('is_admin', is_admin)
        end
    where id = user_id;

    -- Also update the profiles table to keep them in sync
    update auth.users
    set raw_user_meta_data = raw_user_meta_data || jsonb_build_object('is_admin', is_admin)
    where id = user_id;

    update public.profiles
    set is_admin = is_admin
    where id = user_id;
end;
$$;


ALTER FUNCTION "public"."update_user_admin_status"("user_id" "uuid", "is_admin" boolean) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."app_users" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "is_admin" boolean DEFAULT false
);


ALTER TABLE "public"."app_users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."credit_ledger" (
    "id" integer NOT NULL,
    "user_id" "uuid",
    "type" "text" NOT NULL,
    "amount" numeric NOT NULL,
    "order_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "note" "text",
    "method" "text"
);


ALTER TABLE "public"."credit_ledger" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."credit_ledger_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."credit_ledger_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."credit_ledger_id_seq" OWNED BY "public"."credit_ledger"."id";



CREATE TABLE IF NOT EXISTS "public"."order_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid",
    "product_id" "uuid",
    "quantity" integer NOT NULL,
    "price" numeric(10,2) NOT NULL,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "order_items_price_check" CHECK (("price" >= (0)::numeric)),
    CONSTRAINT "order_items_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."order_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "total" numeric(10,2) NOT NULL,
    "status" character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "user_id" "uuid",
    "guest_info" "jsonb",
    "order_number" "text",
    "deleted_at" timestamp without time zone,
    "deleted_by" "uuid",
    "deleted_by_role" "text",
    "payment_method" "text" DEFAULT 'cash'::"text",
    "debt" numeric DEFAULT 0,
    "cash_given" numeric DEFAULT 0,
    "change_given" numeric DEFAULT 0,
    CONSTRAINT "orders_status_check" CHECK ((("status")::"text" = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'completed'::character varying, 'cancelled'::character varying])::"text"[])))
);


ALTER TABLE "public"."orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "name" "text",
    "price" numeric,
    "image_url" "text",
    "quantity" integer DEFAULT 0 NOT NULL,
    "category" "text" DEFAULT 'flower'::"text" NOT NULL,
    "thc_min" numeric(6,2),
    "thc_max" numeric(6,2),
    "cbd_min" numeric(6,2),
    "cbd_max" numeric(6,2),
    "description" "text" DEFAULT 'Add product description jou sleg wetter.'::"text",
    "indica" integer,
    "average_rating" numeric(3,1),
    "review_count" integer DEFAULT 0,
    "is_special" boolean DEFAULT false,
    "is_new" boolean DEFAULT false,
    CONSTRAINT "products_indica_check" CHECK ((("indica" >= 0) AND ("indica" <= 100)))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "first_name" "text",
    "last_name" "text",
    "phone_number" "text",
    "email" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "display_name" "text",
    "address" "text",
    "notifications" boolean DEFAULT true,
    "dark_mode" boolean DEFAULT false,
    "is_admin" boolean DEFAULT false,
    "role" "text" DEFAULT 'user'::"text",
    "auth_user_id" "uuid",
    "balance" numeric(12,2) DEFAULT 0
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reviews" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "product_id" "uuid",
    "user_id" "uuid",
    "rating" integer,
    "comment" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_levels" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid",
    "location_id" "uuid",
    "quantity" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."stock_levels" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_locations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL
);


ALTER TABLE "public"."stock_locations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid",
    "from_location_id" "uuid",
    "to_location_id" "uuid",
    "quantity" integer NOT NULL,
    "type" "text" NOT NULL,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "status" "text" DEFAULT 'done'::"text"
);


ALTER TABLE "public"."stock_movements" OWNER TO "postgres";


ALTER TABLE ONLY "public"."credit_ledger" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."credit_ledger_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."app_users"
    ADD CONSTRAINT "app_users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."app_users"
    ADD CONSTRAINT "app_users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."credit_ledger"
    ADD CONSTRAINT "credit_ledger_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock_levels"
    ADD CONSTRAINT "stock_levels_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock_levels"
    ADD CONSTRAINT "stock_levels_product_id_location_id_key" UNIQUE ("product_id", "location_id");



ALTER TABLE ONLY "public"."stock_locations"
    ADD CONSTRAINT "stock_locations_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."stock_locations"
    ADD CONSTRAINT "stock_locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_credit_ledger_type" ON "public"."credit_ledger" USING "btree" ("type");



CREATE INDEX "idx_credit_ledger_user_id" ON "public"."credit_ledger" USING "btree" ("user_id");



CREATE INDEX "idx_credit_ledger_user_type" ON "public"."credit_ledger" USING "btree" ("user_id", "type");



CREATE INDEX "idx_order_items_order_id" ON "public"."order_items" USING "btree" ("order_id");



CREATE INDEX "idx_order_items_product_id" ON "public"."order_items" USING "btree" ("product_id");



CREATE INDEX "idx_orders_guest_email" ON "public"."orders" USING "btree" ((("guest_info" ->> 'email'::"text")));



CREATE UNIQUE INDEX "idx_orders_order_number" ON "public"."orders" USING "btree" ("order_number");



CREATE INDEX "idx_orders_status" ON "public"."orders" USING "btree" ("status");



CREATE INDEX "idx_orders_user_id" ON "public"."orders" USING "btree" ("user_id");



CREATE INDEX "idx_products_active" ON "public"."products" USING "btree" ("id") WHERE ("quantity" > 0);



CREATE INDEX "idx_products_category_quantity" ON "public"."products" USING "btree" ("category", "quantity");



CREATE INDEX "idx_products_id" ON "public"."products" USING "btree" ("id");



CREATE INDEX "idx_products_quantity" ON "public"."products" USING "btree" ("quantity");



CREATE INDEX "idx_profiles_id" ON "public"."profiles" USING "btree" ("id");



CREATE INDEX "reviews_product_id_idx" ON "public"."reviews" USING "btree" ("product_id");



CREATE INDEX "reviews_user_id_idx" ON "public"."reviews" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "update_orders_updated_at" BEFORE UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."app_users"
    ADD CONSTRAINT "app_users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."credit_ledger"
    ADD CONSTRAINT "credit_ledger_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id");



ALTER TABLE ONLY "public"."credit_ledger"
    ADD CONSTRAINT "credit_ledger_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_auth_user_id_fkey" FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_levels"
    ADD CONSTRAINT "stock_levels_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."stock_locations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_levels"
    ADD CONSTRAINT "stock_levels_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_from_location_id_fkey" FOREIGN KEY ("from_location_id") REFERENCES "public"."stock_locations"("id");



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_to_location_id_fkey" FOREIGN KEY ("to_location_id") REFERENCES "public"."stock_locations"("id");



CREATE POLICY "Admins can delete any order item" ON "public"."order_items" FOR DELETE USING ((((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true));



CREATE POLICY "Admins can delete ledger" ON "public"."credit_ledger" FOR DELETE USING ((((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true));



CREATE POLICY "Admins can delete products" ON "public"."products" FOR DELETE USING ((((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true));



CREATE POLICY "Admins can do anything on stock_levels" ON "public"."stock_levels" USING ((((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true));



CREATE POLICY "Admins can do anything on stock_locations" ON "public"."stock_locations" USING ((((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true));



CREATE POLICY "Admins can do anything on stock_movements" ON "public"."stock_movements" USING ((((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true));



CREATE POLICY "Admins can insert ledger" ON "public"."credit_ledger" FOR INSERT WITH CHECK ((((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true));



CREATE POLICY "Admins can insert products" ON "public"."products" FOR INSERT WITH CHECK ((((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true));



CREATE POLICY "Admins can update any order item" ON "public"."order_items" FOR UPDATE USING ((((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true));



CREATE POLICY "Admins can update ledger" ON "public"."credit_ledger" FOR UPDATE USING ((((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true));



CREATE POLICY "Admins can update products" ON "public"."products" FOR UPDATE USING ((((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true));



CREATE POLICY "Allow users to insert their own orders" ON "public"."orders" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Allow users to select their own orders" ON "public"."orders" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Allow users to update their own orders" ON "public"."orders" FOR UPDATE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Allow users, admins, and pos to select orders" ON "public"."orders" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."auth_user_id" = "auth"."uid"()) OR ("profiles"."role" = ANY (ARRAY['admin'::"text", 'pos'::"text"])))))));



CREATE POLICY "Allow users, admins, and pos to update orders" ON "public"."orders" FOR UPDATE USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."auth_user_id" = "auth"."uid"()) OR ("profiles"."role" = ANY (ARRAY['admin'::"text", 'pos'::"text"])))))));



CREATE POLICY "Anyone can view products" ON "public"."products" FOR SELECT USING (true);



CREATE POLICY "Authenticated users can create reviews" ON "public"."reviews" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Authenticated users can insert orders" ON "public"."orders" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Users and admins can insert order items" ON "public"."order_items" FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."orders" "o"
  WHERE (("o"."id" = "order_items"."order_id") AND ("o"."user_id" = "auth"."uid"())))) OR (((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true)));



CREATE POLICY "Users and admins can view ledger" ON "public"."credit_ledger" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "credit_ledger"."user_id") AND ("p"."auth_user_id" = "auth"."uid"())))) OR (((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true)));



CREATE POLICY "Users and admins can view order items" ON "public"."order_items" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."orders" "o"
  WHERE (("o"."id" = "order_items"."order_id") AND ("o"."user_id" = "auth"."uid"())))) OR (((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'is_admin'::"text"))::boolean = true)));



CREATE POLICY "Users can create their own profile" ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "auth_user_id"));



CREATE POLICY "Users can delete their own reviews" ON "public"."reviews" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read their own profile" ON "public"."profiles" FOR SELECT USING (("auth"."uid"() = "auth_user_id"));



CREATE POLICY "Users can update their own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "auth_user_id"));



CREATE POLICY "Users can update their own reviews" ON "public"."reviews" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view all reviews" ON "public"."reviews" FOR SELECT USING (true);



ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































































































































GRANT ALL ON FUNCTION "public"."get_users_with_metadata"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_users_with_metadata"() TO "service_role";
GRANT ALL ON FUNCTION "public"."get_users_with_metadata"() TO "authenticated";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_product_quantity"("product_id" "uuid", "amount" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."increment_product_quantity"("product_id" "uuid", "amount" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_product_quantity"("product_id" "uuid", "amount" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."is_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_product_rating"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_product_rating"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_product_rating"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_admin_status"("user_id" "uuid", "is_admin" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_admin_status"("user_id" "uuid", "is_admin" boolean) TO "service_role";
GRANT ALL ON FUNCTION "public"."update_user_admin_status"("user_id" "uuid", "is_admin" boolean) TO "authenticated";


















GRANT ALL ON TABLE "public"."app_users" TO "anon";
GRANT ALL ON TABLE "public"."app_users" TO "authenticated";
GRANT ALL ON TABLE "public"."app_users" TO "service_role";



GRANT ALL ON TABLE "public"."credit_ledger" TO "anon";
GRANT ALL ON TABLE "public"."credit_ledger" TO "authenticated";
GRANT ALL ON TABLE "public"."credit_ledger" TO "service_role";



GRANT ALL ON SEQUENCE "public"."credit_ledger_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."credit_ledger_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."credit_ledger_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."order_items" TO "anon";
GRANT ALL ON TABLE "public"."order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."order_items" TO "service_role";



GRANT ALL ON TABLE "public"."orders" TO "anon";
GRANT ALL ON TABLE "public"."orders" TO "authenticated";
GRANT ALL ON TABLE "public"."orders" TO "service_role";



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."reviews" TO "anon";
GRANT ALL ON TABLE "public"."reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."reviews" TO "service_role";



GRANT ALL ON TABLE "public"."stock_levels" TO "anon";
GRANT ALL ON TABLE "public"."stock_levels" TO "authenticated";
GRANT ALL ON TABLE "public"."stock_levels" TO "service_role";



GRANT ALL ON TABLE "public"."stock_locations" TO "anon";
GRANT ALL ON TABLE "public"."stock_locations" TO "authenticated";
GRANT ALL ON TABLE "public"."stock_locations" TO "service_role";



GRANT ALL ON TABLE "public"."stock_movements" TO "anon";
GRANT ALL ON TABLE "public"."stock_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."stock_movements" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;
