/*
  # Add full name field to lost products

  1. Changes
    - Add full_name column to lost_products table
    - Update RLS policies to allow public viewing of products
*/

DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'lost_products' 
    AND column_name = 'full_name'
  ) THEN 
    ALTER TABLE lost_products 
    ADD COLUMN full_name text NOT NULL DEFAULT '';
  END IF;
END $$;

-- Update the select policy to allow public viewing
DROP POLICY IF EXISTS "Anyone can view lost products" ON lost_products;
CREATE POLICY "Anyone can view lost products"
  ON lost_products
  FOR SELECT
  USING (true);