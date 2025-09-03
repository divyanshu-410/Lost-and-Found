/*
  # Final Fix for Chat Room RLS Policies

  1. Changes
    - Drop all existing chat room policies
    - Create comprehensive policies for all operations
    - Add explicit policies for UPDATE operations
    - Ensure proper access control for all user roles

  2. Security
    - Maintain strict data isolation
    - Allow reporters to manage chats for their products
    - Allow claimers to participate in their own chats
    - Prevent unauthorized access and modifications
*/

-- Drop all existing policies
DROP POLICY IF EXISTS "View chat rooms as reporter" ON chat_rooms;
DROP POLICY IF EXISTS "View chat rooms as claimer" ON chat_rooms;
DROP POLICY IF EXISTS "Create chat rooms as claimer" ON chat_rooms;

-- Create comprehensive policies for chat rooms
CREATE POLICY "View chat rooms"
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

CREATE POLICY "Create chat rooms"
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

CREATE POLICY "Update chat rooms"
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
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE lost_products.id = product_id 
      AND lost_products.user_id = auth.uid()
    )
  );

-- Ensure RLS is enabled
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;