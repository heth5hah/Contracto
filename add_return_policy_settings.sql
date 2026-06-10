-- Add Return Policy Settings to settings table
-- Run this migration on Supabase SQL Editor

-- 1. Create settings table if not exists (stores key-value configurations)
CREATE TABLE IF NOT EXISTS public.settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text UNIQUE NOT NULL,
  value jsonb NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 2. Enable RLS on settings table
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- 3. Create RLS policies for settings (admin-only write, public read for app)
DO $$
BEGIN
    -- Allow anyone to read settings
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'settings' AND policyname = 'Anyone can read settings') THEN
        CREATE POLICY "Anyone can read settings" ON public.settings
            FOR SELECT USING (true);
    END IF;

    -- Only authenticated users can update settings (admin check can be added)
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'settings' AND policyname = 'Authenticated users can update settings') THEN
        CREATE POLICY "Authenticated users can update settings" ON public.settings
            FOR UPDATE USING (auth.uid() IS NOT NULL);
    END IF;

    -- Only authenticated users can insert settings
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'settings' AND policyname = 'Authenticated users can insert settings') THEN
        CREATE POLICY "Authenticated users can insert settings" ON public.settings
            FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
    END IF;
END $$;

-- 4. Insert default return policy settings
INSERT INTO public.settings (key, value, description)
VALUES (
  'return_policy',
  '{"returns_enabled": true, "return_window_days": 7}'::jsonb,
  'Return policy configuration: enable/disable returns and set return window in days'
)
ON CONFLICT (key) DO NOTHING;

-- 5. Create function to update settings updated_at timestamp
CREATE OR REPLACE FUNCTION update_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Create trigger for updated_at
DROP TRIGGER IF EXISTS settings_updated_at_trigger ON public.settings;
CREATE TRIGGER settings_updated_at_trigger
    BEFORE UPDATE ON public.settings
    FOR EACH ROW
    EXECUTE FUNCTION update_settings_updated_at();

-- Verification query
-- SELECT * FROM public.settings WHERE key = 'return_policy';
