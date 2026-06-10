# Brand File Upload Setup Instructions

## Overview
The brand management feature now supports uploading logo images and catalog PDFs directly from your device.

## Database Setup Required

### 1. Create Storage Bucket in Supabase

#### Option A: Using Supabase Dashboard (Recommended - No Permission Issues)

1. **Go to Supabase Dashboard** → **Storage** section
2. **Click "Create a new bucket"**
3. **Bucket name:** `brand-assets`
4. **Make it public:** ✅ Check "Public bucket"
5. **Click "Create bucket"**

6. **Set up policies:**
   - Click on the `brand-assets` bucket
   - Go to **"Policies"** tab
   - Click **"New Policy"**
   - Choose **"For full customization"**
   - Create 4 policies with these settings:

   **Policy 1 - Upload:**
   - Name: `Anyone can upload brand assets`
   - Allowed operation: `INSERT`
   - Policy definition: `true`

   **Policy 2 - View:**
   - Name: `Anyone can view brand assets`
   - Allowed operation: `SELECT`
   - Policy definition: `true`

   **Policy 3 - Update:**
   - Name: `Anyone can update brand assets`
   - Allowed operation: `UPDATE`
   - Policy definition: `true`

   **Policy 4 - Delete:**
   - Name: `Anyone can delete brand assets`
   - Allowed operation: `DELETE`
   - Policy definition: `true`

#### Option B: Using SQL (May require elevated permissions)

If you have owner permissions, run this in your Supabase SQL Editor:

```sql
-- Create the brand-assets storage bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('brand-assets', 'brand-assets', true)
ON CONFLICT (id) DO NOTHING;
```

Then set up policies using the Dashboard UI as described in Option A above.

**Note:** If you get a "must be owner of table objects" error, use Option A (Dashboard UI) instead.

### 2. Verify Bucket Creation

1. Go to your Supabase Dashboard
2. Navigate to **Storage** section
3. You should see the `brand-assets` bucket listed
4. Make sure it's set to **Public** (for easy access to logos and catalogs)

## Features

### Logo Upload
- **Supported formats:** PNG, JPG, JPEG, GIF
- **Upload location:** `brands/logos/` folder in the `brand-assets` bucket
- **Preview:** Shows a thumbnail of the uploaded/existing logo
- **Options:** 
  - Upload from device
  - Enter URL manually
  - Remove selected file

### Catalog PDF Upload
- **Supported format:** PDF only
- **Upload location:** `brands/catalogs/` folder in the `brand-assets` bucket
- **Preview:** Shows filename of selected PDF
- **Options:**
  - Upload from device
  - Enter URL manually
  - Remove selected file

## Usage

1. Open the **Brands** section in the admin panel
2. Click **Add Brand** or edit an existing brand
3. In the dialog:
   - **For Logo:** Click the blue "Upload" button next to the Logo URL field
   - **For Catalog:** Click the red "Upload" button next to the Catalog PDF URL field
4. Select the file from your device
5. The file will be uploaded automatically when you save the brand
6. The URL fields will be disabled when a file is selected (to prevent conflicts)

## File Naming Convention

Uploaded files are automatically renamed with a timestamp to prevent conflicts:
- Format: `{timestamp}_{original_filename}`
- Example: `1704067200000_company_logo.png`

## Troubleshooting

### Upload Fails
1. **Check bucket exists:** Verify the `brand-assets` bucket is created in Supabase Storage
2. **Check policies:** Ensure RLS policies are correctly set up (run the SQL commands above)
3. **Check file size:** Large files may take longer to upload
4. **Check internet connection:** Ensure stable connection during upload

### Files Not Displaying
1. **Check bucket is public:** The bucket must be set to public for URLs to work
2. **Check URL:** Verify the generated URL is accessible in a browser
3. **Clear cache:** Try refreshing the page

## Security Considerations

The current setup allows **anyone** to upload files to the `brand-assets` bucket. For production:

1. Consider restricting uploads to authenticated users only
2. Add file size limits
3. Add virus scanning for uploaded files
4. Implement file type validation on the server side

To restrict to authenticated users, uncomment and run this SQL:
```sql
-- Drop the public policy
DROP POLICY "Anyone can upload brand assets" ON storage.objects;

-- Create authenticated-only policy
CREATE POLICY "Authenticated users can upload brand assets" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'brand-assets' AND auth.role() = 'authenticated');
```
