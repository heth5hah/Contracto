-- =============================================================================
-- FIX REALTIME UPDATES FOR QUOTATIONS
-- Run this in Supabase SQL Editor.
-- =============================================================================

-- Enable real-time replication for quote_requests table so the admin portal gets notified instantly
DO $$
BEGIN
  -- Check if table is already in publication
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'quote_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.quote_requests;
  END IF;
END $$;
