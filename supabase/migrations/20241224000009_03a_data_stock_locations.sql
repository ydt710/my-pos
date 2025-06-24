-- =============================================
-- EXPORT SCRIPT 03a: STOCK LOCATIONS DATA
-- =============================================
-- Run this script after 02c_tables_landing.sql.
-- This script inserts stock locations.
-- =============================================

-- Insert data into public.stock_locations
INSERT INTO "public"."stock_locations" ("id", "name") VALUES
('e0ff9565-e490-45e9-991f-298918e4514a', 'shop'),
('5f69d311-5373-47a3-b0b3-3a6a9b499b7c', 'facility'),
('7c3b2e5a-8b8e-4a9e-8b1a-2c3d4e5f6a7b', 'storage')
ON CONFLICT (name) DO NOTHING; 