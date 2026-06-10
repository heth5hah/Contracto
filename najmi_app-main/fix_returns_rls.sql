-- Drop existing policies if needed
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON "public"."returns";
DROP POLICY IF EXISTS "Users can insert their own returns" ON "public"."returns";
DROP POLICY IF EXISTS "Enable read access for all users" ON "public"."returns";
DROP POLICY IF EXISTS "Enable update access for all users" ON "public"."returns";

-- Create a blanket insert policy for authenticated users (since app handles logic)
CREATE POLICY "Enable insert for authenticated users only" 
ON "public"."returns" 
FOR INSERT 
TO authenticated 
WITH CHECK (true);

-- Enable select for authenticated users
CREATE POLICY "Enable read access for all users" 
ON "public"."returns" 
FOR SELECT 
TO authenticated 
USING (true);

-- Enable update for authenticated users
CREATE POLICY "Enable update access for all users" 
ON "public"."returns" 
FOR UPDATE 
TO authenticated 
USING (true);

-- Ensure RLS is enabled
ALTER TABLE "public"."returns" ENABLE ROW LEVEL SECURITY;


-- Do the same for return_items
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON "public"."return_items";
DROP POLICY IF EXISTS "Users can insert their own return items" ON "public"."return_items";
DROP POLICY IF EXISTS "Enable read access for all users" ON "public"."return_items";
DROP POLICY IF EXISTS "Enable update access for all users" ON "public"."return_items";

CREATE POLICY "Enable insert for authenticated users only" 
ON "public"."return_items" 
FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "Enable read access for all users" 
ON "public"."return_items" 
FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Enable update access for all users" 
ON "public"."return_items" 
FOR UPDATE 
TO authenticated 
USING (true);

ALTER TABLE "public"."return_items" ENABLE ROW LEVEL SECURITY;
