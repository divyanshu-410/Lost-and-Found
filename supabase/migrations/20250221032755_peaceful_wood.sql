/*
  # Fix Chat Room Policies

  1. Changes
    - Remove recursive policies that were causing infinite recursion
    - Simplify chat room access policies
    - Add proper indexing for performance

  2. Security
    - Maintain proper access control for chat rooms
    - Ensure users can only access their own chats
*/

-- Drop existing policies
DROP POLICY IF EXISTS "View chats" ON chat_rooms;
DROP POLICY IF EXISTS "Create chats" ON chat_rooms;
DROP POLICY IF EXISTS "Update chats" ON chat_rooms;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_chat_rooms_product_id ON chat_rooms(product_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_claimer_id ON chat_rooms(claimer_id);

-- Create new simplified policies
CREATE POLICY "Allow viewing own chats"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    claimer_id = auth.uid() OR
    product_id IN (
      SELECT id FROM lost_products WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Allow creating new chats"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    claimer_id = auth.uid() AND
    product_id IN (
      SELECT id FROM lost_products WHERE user_id != auth.uid()
    )
  );

CREATE POLICY "Allow reporters to update chats"
  ON chat_rooms
  FOR UPDATE
  TO authenticated
  USING (
    product_id IN (
      SELECT id FROM lost_products WHERE user_id = auth.uid()
    )
  );