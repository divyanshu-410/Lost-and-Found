/*
  # Fix Chat Room Policies

  1. Changes
    - Drop existing policies
    - Create new comprehensive policies for chat rooms
    - Add proper indexes for performance
  
  2. Security
    - Enable RLS
    - Add policies for viewing, creating, and updating chat rooms
    - Ensure proper access control for both reporters and claimers
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Allow viewing own chats" ON chat_rooms;
DROP POLICY IF EXISTS "Allow creating new chats" ON chat_rooms;
DROP POLICY IF EXISTS "Allow reporters to update chats" ON chat_rooms;

-- Create new comprehensive policies
CREATE POLICY "view_chat_rooms"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    claimer_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM lost_products
      WHERE id = chat_rooms.product_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "create_chat_rooms"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    claimer_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM lost_products
      WHERE id = product_id
      AND user_id != auth.uid()
    )
  );

CREATE POLICY "update_chat_rooms"
  ON chat_rooms
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM lost_products
      WHERE id = chat_rooms.product_id
      AND user_id = auth.uid()
    )
  );

-- Ensure RLS is enabled
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance if they don't exist
CREATE INDEX IF NOT EXISTS idx_chat_rooms_product_id ON chat_rooms(product_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_claimer_id ON chat_rooms(claimer_id);