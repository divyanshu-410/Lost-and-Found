/*
  # Fix chat rooms RLS policies

  1. Changes
    - Drop existing policies
    - Create new policies with proper authentication checks
    - Add explicit conditions for each operation
    
  2. Security
    - Ensure proper RLS enforcement
    - Add explicit authentication checks
    - Prevent unauthorized access
*/

-- Drop existing policies
DROP POLICY IF EXISTS "chat_rooms_select" ON chat_rooms;
DROP POLICY IF EXISTS "chat_rooms_insert" ON chat_rooms;
DROP POLICY IF EXISTS "chat_rooms_update" ON chat_rooms;

-- Create new policies with proper authentication checks
CREATE POLICY "chat_rooms_select_policy"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() IS NOT NULL AND (
      claimer_id = auth.uid() OR
      EXISTS (
        SELECT 1 
        FROM lost_products 
        WHERE lost_products.id = chat_rooms.product_id 
        AND lost_products.user_id = auth.uid()
      )
    )
  );

CREATE POLICY "chat_rooms_insert_policy"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    claimer_id = auth.uid() AND
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE lost_products.id = product_id 
      AND lost_products.user_id != auth.uid()
    ) AND
    NOT EXISTS (
      SELECT 1 
      FROM chat_rooms existing_chat
      WHERE existing_chat.product_id = product_id 
      AND existing_chat.claimer_id = auth.uid()
    )
  );

CREATE POLICY "chat_rooms_update_policy"
  ON chat_rooms
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE lost_products.id = chat_rooms.product_id 
      AND lost_products.user_id = auth.uid()
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE lost_products.id = product_id 
      AND lost_products.user_id = auth.uid()
    )
  );

-- Ensure indexes exist for performance
CREATE INDEX IF NOT EXISTS idx_chat_rooms_product_id ON chat_rooms(product_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_claimer_id ON chat_rooms(claimer_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_product_claimer ON chat_rooms(product_id, claimer_id);

-- Ensure RLS is enabled
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;