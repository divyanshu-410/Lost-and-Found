/*
  # Fix Chat Room RLS Policies

  1. Changes
    - Drop existing chat room policies
    - Create new policies for chat rooms that properly handle both reporters and claimers
    - Ensure proper access control for chat room creation and viewing

  2. Security
    - Enable RLS on chat_rooms table
    - Add policies for viewing and creating chat rooms
    - Ensure users can only access their own chats or chats for items they reported
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own chat rooms" ON chat_rooms;
DROP POLICY IF EXISTS "Users can create chat rooms for products" ON chat_rooms;

-- Create new policies for chat rooms
CREATE POLICY "Users can view chat rooms as reporter or claimer"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    claimer_id = auth.uid() OR 
    product_id IN (
      SELECT id 
      FROM lost_products 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create chat rooms for products they don't own"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    claimer_id = auth.uid() AND
    product_id NOT IN (
      SELECT id 
      FROM lost_products 
      WHERE user_id = auth.uid()
    )
  );