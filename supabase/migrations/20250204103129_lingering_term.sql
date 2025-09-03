/*
  # Create Lost Products Schema

  1. New Tables
    - `lost_products`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `product_name` (text)
      - `description` (text)
      - `contact_info` (text)
      - `photo_url` (text)
      - `status` (text) - can be 'lost' or 'found'
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on `lost_products` table
    - Add policies for:
      - Users can read all products
      - Users can only create/update their own products
*/

CREATE TABLE IF NOT EXISTS lost_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  product_name text NOT NULL,
  description text,
  contact_info text NOT NULL,
  photo_url text,
  status text NOT NULL DEFAULT 'lost' CHECK (status IN ('lost', 'found')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE lost_products ENABLE ROW LEVEL SECURITY;

-- Allow all users to read products
CREATE POLICY "Anyone can view lost products"
  ON lost_products
  FOR SELECT
  TO authenticated
  USING (true);

-- Allow users to create their own products
CREATE POLICY "Users can create their own products"
  ON lost_products
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own products
CREATE POLICY "Users can update their own products"
  ON lost_products
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);