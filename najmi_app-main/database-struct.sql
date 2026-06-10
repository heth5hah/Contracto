-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.addresses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  address text NOT NULL,
  label text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT addresses_pkey PRIMARY KEY (id),
  CONSTRAINT addresses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.brands (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  logo_url text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  catalog_pdf_url text,
  CONSTRAINT brands_pkey PRIMARY KEY (id)
);
CREATE TABLE public.categories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  image_url text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT categories_pkey PRIMARY KEY (id)
);
CREATE TABLE public.credit (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  credit_limit numeric NOT NULL,
  overdue boolean DEFAULT false,
  history jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT credit_pkey PRIMARY KEY (id),
  CONSTRAINT credit_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.featured_brands (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  brand_id uuid NOT NULL,
  sort_order integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT featured_brands_pkey PRIMARY KEY (id),
  CONSTRAINT featured_brands_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(id)
);
CREATE TABLE public.featured_products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  sort_order integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT featured_products_pkey PRIMARY KEY (id),
  CONSTRAINT featured_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id)
);
CREATE TABLE public.image_slides (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text,
  description text,
  image_url text NOT NULL,
  link_url text,
  sort_order integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  brand_id uuid,
  CONSTRAINT image_slides_pkey PRIMARY KEY (id),
  CONSTRAINT image_slides_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(id)
);
CREATE TABLE public.invoices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  quotation_id uuid,
  user_id uuid,
  company_name text NOT NULL,
  bank_details text NOT NULL,
  status text NOT NULL CHECK (status = ANY (ARRAY['pending'::text, 'paid'::text, 'overdue'::text])),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT invoices_pkey PRIMARY KEY (id),
  CONSTRAINT invoices_quotation_id_fkey FOREIGN KEY (quotation_id) REFERENCES public.quotations(id),
  CONSTRAINT invoices_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  type text NOT NULL CHECK (type = ANY (ARRAY['order_update'::text, 'payment_due'::text, 'stock_arrival'::text, 'quote_received'::text, 'admin_message'::text, 'invoice_sent'::text, 'other'::text])),
  message text NOT NULL,
  status text DEFAULT 'unread'::text,
  created_at timestamp with time zone DEFAULT now(),
  sender_id uuid,
  sent_by_admin boolean DEFAULT false,
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.order_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL,
  product_id uuid NOT NULL,
  product_name text NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price numeric NOT NULL,
  total_price numeric NOT NULL,
  quality_option_id text,
  quality_option_name text,
  unit text DEFAULT 'units'::text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT order_items_pkey PRIMARY KEY (id),
  CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id),
  CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id)
);
CREATE TABLE public.orders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  customer_name text NOT NULL,
  customer_email text NOT NULL,
  customer_phone text NOT NULL,
  delivery_address text NOT NULL,
  payment_method text NOT NULL,
  payment_status text DEFAULT 'pending'::text,
  order_status text DEFAULT 'pending'::text,
  notes text,
  gst_number text,
  total_amount numeric DEFAULT 0,
  subtotal numeric DEFAULT 0,
  gst_amount numeric DEFAULT 0,
  delivery_charge numeric DEFAULT 50,
  invoice_required boolean DEFAULT false,
  items jsonb DEFAULT '[]'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT orders_pkey PRIMARY KEY (id),
  CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id text NOT NULL UNIQUE,
  brand_id uuid,
  category text,
  subcategory text,
  product_name text NOT NULL,
  description text,
  mrp numeric,
  hsn_number text,
  gst_percent numeric,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  discount_percent numeric,
  final_price numeric,
  photos ARRAY DEFAULT '{}'::text[],
  unit text,
  quality_options jsonb DEFAULT '[]'::jsonb,
  stock_status character varying DEFAULT 'in_stock'::character varying CHECK (stock_status::text = ANY (ARRAY['in_stock'::character varying, 'out_of_stock'::character varying]::text[])),
  pricing_type character varying DEFAULT 'fixed_price'::character varying CHECK (pricing_type::text = ANY (ARRAY['fixed_price'::character varying, 'whatsapp_request'::character varying, 'quote_request'::character varying]::text[])),
  whatsapp_message text,
  quote_instructions text,
  brand_ids jsonb DEFAULT '[]'::jsonb,
  CONSTRAINT products_pkey PRIMARY KEY (id),
  CONSTRAINT products_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(id)
);
CREATE TABLE public.quotations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  product_id uuid,
  notes text,
  status text NOT NULL CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])),
  price numeric,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT quotations_pkey PRIMARY KEY (id),
  CONSTRAINT quotations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.quote_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  quote_id uuid,
  quality_option_id text,
  quality_option_name text NOT NULL,
  quantity integer NOT NULL,
  unit text NOT NULL,
  unit_price numeric NOT NULL,
  total_price numeric NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT quote_items_pkey PRIMARY KEY (id),
  CONSTRAINT quote_items_quote_id_fkey FOREIGN KEY (quote_id) REFERENCES public.quotes(id)
);
CREATE TABLE public.quote_request_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  quote_request_id uuid,
  quality_option_id text,
  quality_option_name text NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  unit text DEFAULT 'units'::text,
  created_at timestamp with time zone DEFAULT now(),
  product_id uuid,
  product_name text,
  category text,
  brand_id uuid,
  CONSTRAINT quote_request_items_pkey PRIMARY KEY (id),
  CONSTRAINT quote_request_items_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(id),
  CONSTRAINT quote_request_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT quote_request_items_quote_request_id_fkey FOREIGN KEY (quote_request_id) REFERENCES public.quote_requests(id)
);
CREATE TABLE public.quote_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  product_name text NOT NULL,
  category text,
  brand_id uuid,
  status text DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'quoted'::text, 'accepted'::text, 'rejected'::text, 'expired'::text])),
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  request_type text DEFAULT 'single'::text CHECK (request_type = ANY (ARRAY['single'::text, 'multiple'::text])),
  consolidated_name text,
  product_id uuid,
  CONSTRAINT quote_requests_pkey PRIMARY KEY (id),
  CONSTRAINT quote_requests_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(id),
  CONSTRAINT quote_requests_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT quote_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.quotes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  quote_request_id uuid,
  admin_user_id uuid,
  status text DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'accepted'::text, 'rejected'::text, 'expired'::text])),
  subtotal numeric NOT NULL,
  tax_amount numeric NOT NULL,
  total_amount numeric NOT NULL,
  validity_days integer DEFAULT 7,
  payment_terms text,
  additional_notes text,
  bank_name text,
  account_number text,
  ifsc_code text,
  upi_id text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  order_status character varying DEFAULT 'pending'::character varying CHECK (order_status::text = ANY (ARRAY['pending'::character varying, 'in_transport'::character varying, 'delivered'::character varying, 'returned'::character varying]::text[])),
  status_notes text,
  CONSTRAINT quotes_pkey PRIMARY KEY (id),
  CONSTRAINT quotes_admin_user_id_fkey FOREIGN KEY (admin_user_id) REFERENCES public.users(id),
  CONSTRAINT quotes_quote_request_id_fkey FOREIGN KEY (quote_request_id) REFERENCES public.quote_requests(id)
);
CREATE TABLE public.schema_migrations (
  version text NOT NULL,
  applied_at timestamp with time zone DEFAULT now(),
  CONSTRAINT schema_migrations_pkey PRIMARY KEY (version)
);
CREATE TABLE public.users (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  mobile character varying NOT NULL UNIQUE,
  email text UNIQUE,
  pan character varying UNIQUE,
  password_hash text,
  role text NOT NULL CHECK (role = ANY (ARRAY['customer'::text, 'admin'::text])),
  credit_limit numeric DEFAULT 0,
  status text DEFAULT 'active'::text,
  created_at timestamp with time zone DEFAULT now(),
  gst_number character varying UNIQUE,
  user_type text DEFAULT 'individual'::text CHECK (user_type = ANY (ARRAY['individual'::text, 'company'::text])),
  company_name text,
  is_gst_registered boolean DEFAULT false,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);