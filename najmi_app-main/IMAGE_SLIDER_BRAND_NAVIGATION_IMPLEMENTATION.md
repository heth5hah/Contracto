# Image Slider Brand Navigation Implementation

## Overview
This implementation adds the ability to link image slider banners to specific brands, allowing users to tap on a banner and navigate directly to the brand's profile/products page.

## Changes Made

### 1. Database Schema Update
- **File**: `add_brand_to_image_slides.sql`
- Added `brand_id` column to the `image_slides` table
- Added foreign key constraint linking to the `brands` table
- Added index for better query performance

### 2. Flutter App Changes

#### ImageSlide Model Update
- **File**: `lib/features/home/data/services/image_slides_service.dart`
- Added `brandId` field to the `ImageSlide` class
- Updated `fromJson()` and `toJson()` methods to handle brand association
- Added `getBrandForSlide()` method to fetch brand information

#### Home Screen Navigation
- **File**: `lib/features/auth/presentation/screens/blinkit_style_home.dart`
- Wrapped image slider items with `GestureDetector` for tap handling
- Added `_onImageSlideTap()` method that:
  - Checks if the slide has an associated brand
  - Fetches the brand information
  - Navigates to `BrandProductsScreen` with the brand data
  - Shows error handling with SnackBar if navigation fails

### 3. Admin Panel Updates

#### HTML Form Enhancement
- **File**: `admin/image_slides.html`
- Added brand selection dropdown to the slide creation/editing form
- Dropdown is populated dynamically with active brands

#### JavaScript Functionality
- **File**: `admin/js/image_slides.js`
- Added `loadBrands()` method to populate brand dropdown
- Updated `handleSubmit()` to include `brand_id` in form data
- Modified `loadSlides()` to fetch brand information with slides
- Updated `openModal()` to populate brand field when editing
- Enhanced `displaySlides()` to show associated brand name

## How It Works

### For Users:
1. When viewing the home screen, image slider banners are displayed
2. If a banner is linked to a brand, tapping it will navigate to that brand's products page
3. If no brand is linked, the tap is handled gracefully (logged but no navigation)

### For Admins:
1. When creating/editing image slides in the admin panel:
   - Select a brand from the dropdown (optional)
   - The brand association is saved to the database
2. The slides list shows which brand (if any) is associated with each slide

## Database Migration Required

Before using this feature, run the SQL migration:

```sql
-- Run this in your Supabase SQL editor
ALTER TABLE public.image_slides 
ADD COLUMN brand_id UUID REFERENCES public.brands(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_image_slides_brand ON public.image_slides(brand_id);
```

## Usage Instructions

### For Admins:
1. Go to the admin panel → Image Slides
2. Create a new slide or edit an existing one
3. Select a brand from the "Associated Brand" dropdown
4. Save the slide

### For App Users:
1. Open the app and view the home screen
2. Tap on any image slider banner
3. If the banner is linked to a brand, you'll be taken to that brand's products page

## Error Handling
- If a brand is deleted but still referenced by a slide, the foreign key constraint uses `ON DELETE SET NULL`
- If there's an error fetching brand data, a user-friendly error message is shown
- The app gracefully handles slides without brand associations

## Benefits
- Improved user experience with direct navigation to brand pages
- Better engagement with brand content
- Flexible system that allows slides with or without brand associations
- Admin-friendly interface for managing brand-slide relationships
