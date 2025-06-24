# 🚀 Production Deployment Guide

Update your online Supabase to match your local development with ALL the latest features.

## 🎯 **What Will Be Deployed**

After this deployment, your production will have:
- ✅ **13 Cannabis Products** (King Kong OG, Monkey Wrench, etc.)
- ✅ **Complete POS System** with working `pay_order()` function
- ✅ **Landing Page Management** with admin panel
- ✅ **Dashboard & Charts** (revenue, debt, cash flow)
- ✅ **Storage Buckets** (products, signatures, contracts, etc.)
- ✅ **All Database Functions** (31+ functions + triggers)
- ✅ **RLS Security Policies** for data protection
- ✅ **Admin Tools** (balance adjustments, user management)

## 🌐 **Method 1: Direct SQL Deployment (Recommended)**

### **Step 1: Access Production Dashboard**
1. Go to: https://supabase.com/dashboard/project/wglybohfygczpapjxwwz
2. Navigate to: **SQL Editor**
3. Click: **New Query**

### **Step 2: Run Export Scripts (Complete Database)**
Copy and paste each script from `supabase/export/` in this order:

#### **🔧 Script 1: Extensions**
```sql
-- Copy content from: supabase/export/01_extensions.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";
CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";
```

#### **🔧 Script 2: Tables & Cannabis Products**
```sql
-- Copy ENTIRE content from: supabase/export/02_tables.sql
-- Copy ENTIRE content from: supabase/export/03_data.sql
-- This creates all tables AND loads 13 cannabis products
```

#### **🔧 Script 3: Relationships & Views**
```sql
-- Copy content from: supabase/export/04_foreign_keys.sql
-- Copy content from: supabase/export/05_views.sql
```

#### **🔧 Script 4: ALL FUNCTIONS (Critical)**
```sql
-- Copy ENTIRE content from: supabase/export/06_functions.sql
-- This includes ALL 31 functions including pay_order()
```

#### **🔧 Script 5: Security & Storage**
```sql
-- Copy content from: supabase/export/07_rls_and_storage.sql
-- This creates storage buckets and RLS policies
```

#### **🔧 Script 6: Permissions & Triggers**
```sql
-- Copy content from: supabase/export/08_grants_and_triggers.sql
```

#### **🔧 Script 7: Cleanup & Latest Fixes**
```sql
-- Copy content from: supabase/export/09_cleanup_old_enums.sql
-- Copy content from: supabase/export/10_latest_fixes.sql
```

### **Alternative: 4-Part Function Deployment**
If you prefer the manageable chunks, use these instead of script 4:

```sql
-- Copy content from: functions_part1_core.sql
-- Copy content from: functions_part2_charts.sql  
-- Copy content from: functions_part3_business.sql
-- Copy content from: functions_part4_triggers.sql
```

## 🌍 **Method 2: Environment Variables Setup**

### **For Vercel Deployment:**
1. Go to: https://vercel.com/dashboard
2. Select your project
3. Go to: **Settings** → **Environment Variables**
4. Add these variables:

```bash
PUBLIC_SUPABASE_URL=https://wglybohfygczpapjxwwz.supabase.co
PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndnbHlib2hmeWdjenBhcGp4d3d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYyMDI2OTYsImV4cCI6MjA2MTc3ODY5Nn0.F9Ja7Npo2aj-1EzgmG275aF_nkm6BvY7MprqQKhpFp0
```

### **For Netlify Deployment:**
1. Go to: Netlify Dashboard
2. Select your site
3. Go to: **Site Settings** → **Environment Variables**
4. Add the same variables as above

### **For Other Platforms:**
Set the environment variables in your platform's settings using the same values.

## 🔧 **Method 3: Supabase CLI Deployment**

If you have Docker working and want to use CLI:

```bash
# Link to production project
supabase link --project-ref wglybohfygczpapjxwwz

# Deploy all migrations
supabase db push

# Deploy functions (if any)
supabase functions deploy
```

## ✅ **Verification Steps**

After deployment, verify everything is working:

### **Step 1: Test Database Connection**
Add this to any page to test:
```javascript
import { testDatabaseConnection } from '$lib/supabase';

// Test the connection
const result = await testDatabaseConnection();
console.log('Database test:', result);
```

### **Step 2: Test Key Functions**
In Supabase SQL Editor, run these tests:
```sql
-- Test 1: Dashboard stats
SELECT get_dashboard_stats();

-- Test 2: Cannabis products loaded
SELECT COUNT(*) FROM products; -- Should return 13

-- Test 3: Storage buckets exist
SELECT * FROM storage.buckets;

-- Test 4: Landing page data
SELECT * FROM landing_hero;

-- Test 5: Functions exist
SELECT proname FROM pg_proc WHERE proname LIKE 'get_dashboard%';
```

### **Step 3: Test Landing Page**
Visit your production site and check:
- Landing page loads without errors
- Products display correctly
- Admin panel accessible at `/admin/landing`

### **Step 4: Test POS System**
- Dashboard loads with statistics
- Charts display data
- POS transactions work
- Admin balance adjustments functional

## 🚨 **Common Issues & Solutions**

### **Issue: Function Not Found Errors**
**Solution:** Run the functions scripts again (06_functions.sql or 4-part functions)

### **Issue: Storage Bucket Errors**
**Solution:** Re-run script 07_rls_and_storage.sql

### **Issue: Products Not Showing**
**Solution:** Re-run script 03_data.sql to load cannabis products

### **Issue: Dashboard Showing Zeros**
**Solution:** Check RLS policies with script 10_latest_fixes.sql

### **Issue: Environment Variables Not Working**
**Solution:** 
1. Verify variables are set correctly in hosting platform
2. Redeploy your application after setting variables
3. Check browser console for connection logs

## 🎉 **Success Indicators**

Your production deployment is successful when:
- ✅ Dashboard loads without 404 errors
- ✅ Charts display actual data
- ✅ 13 cannabis products visible in admin
- ✅ Landing page loads correctly
- ✅ File uploads work (product images, signatures)
- ✅ POS transactions process successfully
- ✅ Admin tools functional (balance adjustments)
- ✅ Console shows "🌐 Supabase: Using PRODUCTION database"

## 📊 **Production Performance Optimizations**

After deployment, consider these optimizations:

### **Database Indexes** (Already included in scripts)
- Products category/price indexes
- Transactions user_id/created_at indexes
- Orders status/date indexes

### **Storage Optimization**
- Enable image transformations in Supabase dashboard
- Set up CDN for product images
- Configure automatic image compression

### **Monitoring Setup**
- Enable Supabase monitoring in dashboard
- Set up error alerts for critical functions
- Monitor database performance metrics

## 🎯 **Post-Deployment Tasks**

1. **Configure Store Settings**
   - Update store name, address, contact info
   - Set tax rates and shipping fees
   - Configure business hours

2. **Customize Landing Page**
   - Update hero section with your branding
   - Add real testimonials
   - Configure featured products

3. **Set Up Admin Users**
   - Create admin accounts
   - Test admin panel functionality
   - Configure user permissions

4. **Product Management**
   - Review and customize the 13 cannabis products
   - Update pricing and descriptions
   - Add product images

5. **Test Complete Workflow**
   - Test customer signup/login
   - Test POS order processing
   - Test admin balance adjustments
   - Test report generation

---

**🎊 Congratulations! Your production POS system now matches your local development with all the latest features!**

Your 24-hour development marathon has culminated in a fully functional, production-ready cannabis POS system! 