# 🚀 Quick Setup Guide for Featured Section

## ⚠️ **IMPORTANT: Run This First!**

The featured section won't work until you create the database tables. Here's what to do:

### 1. **Copy This SQL** (Run in Supabase SQL Editor)

```sql
-- Create featured products table
CREATE TABLE IF NOT EXISTS public.featured_products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create featured brands table
CREATE TABLE IF NOT EXISTS public.featured_brands (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_id UUID NOT NULL REFERENCES public.brands(id) ON DELETE CASCADE,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create image slides table
CREATE TABLE IF NOT EXISTS public.image_slides (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT,
    description TEXT,
    image_url TEXT NOT NULL,
    link_url TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_featured_products_sort ON public.featured_products(sort_order, is_active);
CREATE INDEX IF NOT EXISTS idx_featured_brands_sort ON public.featured_brands(sort_order, is_active);
CREATE INDEX IF NOT EXISTS idx_image_slides_sort ON public.image_slides(sort_order, is_active);

-- Enable RLS
ALTER TABLE public.featured_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.featured_brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.image_slides ENABLE ROW LEVEL SECURITY;

-- Add policies (allow all operations for now)
CREATE POLICY "Allow all operations on featured_products" ON public.featured_products FOR ALL USING (true);
CREATE POLICY "Allow all operations on featured_brands" ON public.featured_brands FOR ALL USING (true);
CREATE POLICY "Allow all operations on image_slides" ON public.image_slides FOR ALL USING (true);
```

### 2. **Verify Storage Bucket**
Make sure `product-images` bucket exists in your Supabase storage.

### 3. **Refresh the Page**
After running the SQL, refresh `/pages/featured.html`

## ✅ **What This Fixes:**

- ❌ **"No products found"** in search
- ❌ **400 errors** when loading featured content
- ❌ **Storage bucket not found** errors
- ❌ **Tables don't exist** errors

## 🎯 **After Setup:**

- ✅ Product search will work
- ✅ Featured products can be added
- ✅ Featured brands can be managed
- ✅ Image slides can be uploaded
- ✅ All CRUD operations will function

## 📍 **Where to Run SQL:**

1. Go to your Supabase dashboard
2. Click on "SQL Editor" in the left sidebar
3. Paste the SQL above
4. Click "Run" button
5. Refresh your featured page

**That's it!** The featured section will work immediately after running this SQL.
