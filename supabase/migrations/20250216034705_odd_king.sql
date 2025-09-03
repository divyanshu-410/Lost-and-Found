/*
  # Fix Chat Room RLS Policies

  1. Changes
    - Drop existing chat room policies
    - Create new, more permissive policies for chat rooms
    - Add separate policies for insert and select operations
    - Ensure reporters can view all chats for their products
    - Ensure claimers can only view and create their own chats

  2. Security
    - Maintain data isolation between users
    - Allow reporters to view all chats for their products
    - Allow claimers to create and view their own chats
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view chat rooms as reporter or claimer" ON chat_rooms;
DROP POLICY IF EXISTS "Users can create chat rooms for products they don't own" ON chat_rooms;
DROP POLICY IF EXISTS "Users can view their own chat rooms" ON chat_rooms;
DROP POLICY IF EXISTS "Users can create chat rooms for products" ON chat_rooms;

-- Create new policies for chat rooms
CREATE POLICY "View chat rooms as reporter"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE lost_products.id = chat_rooms.product_id 
      AND lost_products.user_id = auth.uid()
    )
  );

CREATE POLICY "View chat rooms as claimer"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    claimer_id = auth.uid()
  );

CREATE POLICY "Create chat rooms as claimer"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    claimer_id = auth.uid() AND
    NOT EXISTS (
      SELECT 1 
      FROM lost_products 
      WHERE lost_products.id = product_id 
      AND lost_products.user_id = auth.uid()
    )
  );

-- Ensure RLS is enabled
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;