/*
  # Fix chat room policies to prevent infinite recursion

  1. Changes
    - Drop existing policies that may cause recursion
    - Create new simplified policies with direct conditions
    - Ensure proper indexing for performance
    
  2. Security
    - Maintain RLS security while preventing recursion
    - Ensure proper access control for chat rooms
*/

-- Drop existing policies
DROP POLICY IF EXISTS "allow_view_own_chats" ON chat_rooms;
DROP POLICY IF EXISTS "allow_create_chat" ON chat_rooms;
DROP POLICY IF EXISTS "allow_reporter_update" ON chat_rooms;

-- Create new simplified policies without recursion
CREATE POLICY "chat_rooms_select"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    claimer_id = auth.uid() OR
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE lost_products.id = chat_rooms.product_id 
      AND lost_products.user_id = auth.uid()
    )
  );

CREATE POLICY "chat_rooms_insert"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    claimer_id = auth.uid() AND
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE lost_products.id = product_id 
      AND lost_products.user_id != auth.uid()
    )
  );

CREATE POLICY "chat_rooms_update"
  ON chat_rooms
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE lost_products.id = chat_rooms.product_id 
      AND lost_products.user_id = auth.uid()
    )
  );

-- Ensure indexes exist for performance
CREATE INDEX IF NOT EXISTS idx_chat_rooms_product_id ON chat_rooms(product_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_claimer_id ON chat_rooms(claimer_id);

-- Ensure RLS is enabled
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;