# RLS Policies Best Practices Guide

## 🚨 Problem: Multiple Permissive Policies

When you see the error: **"Table public.transactions has multiple permissive policies for role authenticated for action SELECT"**, it means you have duplicate or overlapping RLS policies for the same table and action.

## ✅ Solution Summary

1. **One Policy Per Action Per Role**: Each table should have only ONE policy per action (SELECT, INSERT, UPDATE, DELETE) per role (authenticated, anon, service_role).

2. **Use OR Logic**: Instead of multiple SELECT policies, combine conditions using `OR` in a single policy.

3. **Avoid Duplicates Across Migration Files**: Don't define the same policy in multiple migration files.

## 📋 Best Practices

### ✅ GOOD: Single Consolidated Policy
```sql
-- ✅ GOOD - One policy with OR conditions
CREATE POLICY "transactions_select_policy" ON "public"."transactions"
FOR SELECT TO authenticated
USING (
    -- Users can see their own transactions
    user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid())
    OR
    -- Admins can see all transactions
    public.is_admin()
    OR
    -- POS users can see all transactions
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE auth_user_id = auth.uid() 
        AND role = 'pos'
    )
);
```

### ❌ BAD: Multiple Policies for Same Action
```sql
-- ❌ BAD - Multiple SELECT policies cause conflicts
CREATE POLICY "users_view_own_transactions" ON "public"."transactions"
FOR SELECT TO authenticated
USING (user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid()));

CREATE POLICY "admins_view_all_transactions" ON "public"."transactions"
FOR SELECT TO authenticated
USING (public.is_admin());

CREATE POLICY "pos_view_all_transactions" ON "public"."transactions"
FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE auth_user_id = auth.uid() AND role = 'pos'));
```

## 🔧 Policy Naming Convention

Use descriptive names that indicate:
- Table name
- Action (select/insert/update/delete/all)
- Purpose

Examples:
- `transactions_select_policy`
- `orders_admin_manage_policy`
- `products_public_read_policy`
- `profiles_user_update_policy`

## 📁 File Organization

### Option 1: Centralized RLS Files
```
migrations/
├── 01_schema.sql
├── 02_data.sql
├── 03_functions.sql
├── 04_rls_policies.sql  ← All RLS policies here
└── 05_grants.sql
```

### Option 2: Table-Specific RLS Files
```
migrations/
├── 01_schema.sql
├── 02_data.sql
├── 03_functions.sql
├── 04a_rls_core_tables.sql     ← Core business tables
├── 04b_rls_landing_tables.sql  ← Landing page tables
├── 04c_rls_stock_tables.sql    ← Stock management tables
└── 05_grants.sql
```

## 🔄 Migration Strategy

### When Adding New Policies:
1. **Always use `DROP POLICY IF EXISTS`** before creating
2. **Check existing migration files** for conflicts
3. **Test in development branch** before production

```sql
-- Always start with DROP IF EXISTS
DROP POLICY IF EXISTS "policy_name" ON "table_name";

-- Then create the new policy
CREATE POLICY "policy_name" ON "table_name"
FOR ACTION TO role
USING (condition)
WITH CHECK (condition);
```

## 🧪 Testing RLS Policies

### Test Each User Role:
```sql
-- Test as regular user
SET session_presets.claim_user_id = 'user-uuid-here';
SELECT * FROM transactions; -- Should only see own transactions

-- Test as admin
SET session_presets.claim_is_admin = 'true';
SELECT * FROM transactions; -- Should see all transactions

-- Test as POS user
SET session_presets.claim_user_role = 'pos';
SELECT * FROM transactions; -- Should see all transactions
```

## 🚀 Quick Fix for Current Issue

Run this migration to consolidate all duplicate policies:

```bash
# Apply the consolidation migration
supabase db push

# Or manually apply the SQL from the migration file
psql -f supabase/migrations/20241230000000_consolidate_rls_policies.sql
```

## 📊 Policy Performance Tips

1. **Use indexes** on columns referenced in policies:
```sql
CREATE INDEX idx_transactions_user_id ON transactions(user_id);
CREATE INDEX idx_profiles_auth_user_id ON profiles(auth_user_id);
```

2. **Avoid complex subqueries** in policies when possible
3. **Use EXISTS** instead of IN for better performance
4. **Test policy performance** with large datasets

## 🔍 Debugging RLS Issues

### Check Current Policies:
```sql
-- View all policies for a table
SELECT schemaname, tablename, policyname, cmd, roles, qual 
FROM pg_policies 
WHERE tablename = 'transactions';
```

### Check Policy Conflicts:
```sql
-- Find duplicate policy names
SELECT tablename, policyname, COUNT(*) 
FROM pg_policies 
GROUP BY tablename, policyname 
HAVING COUNT(*) > 1;
```

## ✨ Remember

- **One policy per action per role** - This is the golden rule
- **Use OR conditions** to combine logic in single policies
- **Test thoroughly** in development before production
- **Keep migration files clean** and avoid duplicates
- **Use descriptive names** for easy maintenance 