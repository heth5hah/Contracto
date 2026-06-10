-- Add columns for business credit application details (KYC) to public.users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS company_name text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS company_address text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS company_phone text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS poc_name text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS poc_phone text;

-- Add comment to describe the fields
COMMENT ON COLUMN public.users.company_name IS 'Company name provided during business credit application';
COMMENT ON COLUMN public.users.company_address IS 'Company address provided during business credit application';
COMMENT ON COLUMN public.users.company_phone IS 'Company contact number provided during business credit application';
COMMENT ON COLUMN public.users.poc_name IS 'Point of contact name (optional) for the business account';
COMMENT ON COLUMN public.users.poc_phone IS 'Point of contact number (optional) for the business account';

