-- Populate Brands Database - Construction Materials
-- Run this in Supabase SQL Editor to add all construction material brands

-- Clear existing brands (optional - remove if you want to keep existing data)
-- DELETE FROM public.brands;

-- ============================================================================
-- CONSTRUCTION CHEMICAL BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Sunanda', 'Construction Chemical - Waterproofing, adhesives, sealants and construction chemicals', true),
('Sika', 'Construction Chemical - Concrete admixtures, waterproofing, flooring and sealing solutions', true),
('Fosroc', 'Construction Chemical - Concrete repair, waterproofing, flooring and joint sealing', true),
('Dr Dixit', 'Construction Chemical - Specialized construction chemicals and waterproofing solutions', true),
('Asian Paints', 'Construction Chemical & Paints - Paints, construction chemicals, waterproofing', true);

-- ============================================================================
-- TMT BAR BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Guardian TMT', 'TMT Bar - High-grade TMT steel bars for construction', true),
('MITC', 'TMT Bar - Premium quality TMT bars and steel products', true),
('Bhagwati TMT', 'TMT Bar - Superior strength TMT bars for construction', true),
('Tata Steel', 'TMT Bar - Leading manufacturer of TMT bars and steel products', true),
('JSW Steel', 'TMT Bar - High-quality TMT bars and steel construction materials', true),
('Gajkesari', 'TMT Bar - Premium TMT bars for residential and commercial construction', true),
('Polaad', 'TMT Bar - Quality TMT steel bars for construction projects', true),
('Metarol', 'TMT Bar - Reliable TMT bars and steel reinforcement products', true);

-- ============================================================================
-- ACC BLOCK BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Kaneria', 'ACC Block & Block Jointing Mortar - AAC blocks and construction materials', true),
('Birla', 'ACC Block, Block Jointing Mortar, Tile Fixing Chemical, Gypsum, Putty, White Cement, Level Plast - Complete building materials solution', true),
('Ascolite', 'ACC Block & Block Jointing Mortar - Lightweight concrete blocks', true),
('Ecolite', 'ACC Block & Block Jointing Mortar - Eco-friendly building blocks', true),
('NXT', 'ACC Block & Block Jointing Mortar - Modern building block solutions', true);

-- ============================================================================
-- BLOCK JOINTING MORTAR ADDITIONAL BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Mcon', 'Block Jointing Mortar - Ready-mix mortar for block construction', true);

-- ============================================================================
-- ELECTRICAL & CABLE BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Polycab', 'Electric Cable - Wires, cables and electrical accessories', true);

-- ============================================================================
-- FIBER BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('KDM', 'Recron Fiber - Synthetic fibers for concrete reinforcement', true),
('Reliance', 'Recron Fiber - High-quality synthetic fibers for construction', true);

-- ============================================================================
-- PUMP BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('CRI', 'Monobloc Pump & Dewatering Pump - Water pumps and pumping solutions', true),
('Crompton', 'Monobloc Pump, Dewatering Pump & Vibrator - Pumps, motors and construction equipment', true),
('Kirloskar', 'Monobloc Pump & Dewatering Pump - Industrial and domestic pumps', true),
('Koel', 'Monobloc Pump & Dewatering Pump - Water pumping solutions', true),
('Btali', 'Dewatering Pump - Specialized dewatering and drainage pumps', true);

-- ============================================================================
-- PIPE BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Laxmo', 'Suction Pipe - High-quality suction pipes for pumping systems', true),
('Duplon', 'Suction Pipe, Hose Pipe & Curing Pipe - Flexible pipes and hoses', true),
('Kisan', 'Canvas Pipe & HDPE Pipe - Agricultural and construction pipes', true),
('Samruddhi', 'Hose Pipe & Curing Pipe - Specialized pipes for construction', true),
('Mahavir', 'HDPE Pipe - High-density polyethylene pipes', true);

-- ============================================================================
-- SAFETY & NET BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Agro', 'Green Net - Agricultural and construction safety nets', true),
('Tuffrope', 'Safety Net - Safety nets and ropes for construction', true);

-- ============================================================================
-- MS PIPE BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Hitech', 'MS Pipe - Mild steel pipes for construction', true),
('Apollo', 'MS Pipe - Steel pipes and fittings', true),
('Rama', 'MS Pipe - Quality steel pipes for industrial use', true);

-- ============================================================================
-- REBARING CHEMICAL BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Hilti', 'Rebaring Chemical - Anchoring systems and construction chemicals', true),
('DeWalt', 'Rebaring Chemical & Cutting Machine - Power tools and construction equipment', true);

-- ============================================================================
-- VIBRATOR BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('KPT', 'Vibrator & Tools - Construction vibrators and power tools', true),
('Ferm', 'Vibrator, Cutting Machine & Tools - Power tools and construction equipment', true);

-- ============================================================================
-- CI/DI PIPE & FITTING BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Neco', 'CI Cover, DI Cover, CI Fitting, CI Pipe - Cast iron and ductile iron products', true);

-- ============================================================================
-- CUTTING & GRINDING WHEEL BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Yuri', 'Cutting Wheel & Grinding Wheel - Abrasive wheels for cutting and grinding', true),
('Bosch', 'Cutting Wheel, Grinding Wheel, Cutting Machine & Tools - Power tools and accessories', true);

-- ============================================================================
-- MACHINE BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Inder', 'Bending Machine & Spanner Tools - Construction machinery and tools', true),
('Blueline', 'Bending Machine - Steel bending and cutting machinery', true),
('Verx', 'Cutting Machine & Tools - Power tools for construction', true),
('Kress', 'Cutting Machine - High-performance cutting tools', true);

-- ============================================================================
-- TILE FIXING CHEMICAL BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Roff', 'Tile Fixing Chemical - Tile adhesives and waterproofing', true),
('MYK', 'Tile Fixing Chemical - Construction chemicals and tile solutions', true);

-- ============================================================================
-- GYPSUM BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Gyproc', 'Gypsum - Gypsum boards and drywall systems', true);

-- ============================================================================
-- PLUMBING BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Astral', 'Plumbing - Pipes, fittings and plumbing solutions', true),
('Prince', 'Plumbing - PVC pipes and plumbing accessories', true);

-- ============================================================================
-- TOOLS & HARDWARE BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Taparia', 'Spanner, Pipe Pana, Chain Pana - Hand tools and hardware', true);

-- ============================================================================
-- DUSTBIN BRANDS
-- ============================================================================
INSERT INTO public.brands (name, description, is_active) VALUES
('Prima', 'Dustbin - Waste management and storage solutions', true),
('Cello', 'Dustbin - Household and industrial storage products', true);

-- ============================================================================
-- VERIFICATION QUERY
-- ============================================================================
-- Run this to verify all brands were inserted correctly
-- SELECT name, description, is_active, created_at FROM public.brands ORDER BY name;

-- Total brands inserted: ~50+ construction material brands
-- Categories covered: Construction chemicals, TMT bars, blocks, pumps, pipes, 
-- tools, machinery, chemicals, plumbing, and more 