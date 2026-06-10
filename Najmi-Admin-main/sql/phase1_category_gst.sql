-- ============================================================
-- Phase 1 SQL Migration
-- Admin Panel — Category GST Percent Column
-- Run in Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- Add gst_percent column to categories table
-- This stores the default GST % for all products in this category.
-- Individual products can override this with their own gst_percent.
ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS gst_percent NUMERIC(5,2);

-- Optional: set defaults for well-known GST slabs
-- You can manually update specific categories after running this.
-- Example:
--   UPDATE categories SET gst_percent = 18 WHERE name ILIKE '%electrical%';
--   UPDATE categories SET gst_percent = 5  WHERE name ILIKE '%pipe%';
--   UPDATE categories SET gst_percent = 12 WHERE name ILIKE '%fitting%';

-- Verify the column was added:
SELECT id, name, gst_percent FROM categories LIMIT 10;
