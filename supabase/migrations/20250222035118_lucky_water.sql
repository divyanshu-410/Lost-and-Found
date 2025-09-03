/*
  # Fix Chat Room RLS Policies

  1. Changes
    - Simplify and fix RLS policies for chat_rooms table
    - Ensure proper access control for viewing and creating chat rooms
    - Fix policy conditions to properly handle authenticated users
    - Add better indexes for performance

  2. Security
    - Maintain strict access control
    - Ensure users can only access their own chats
    - Prevent duplicate chat rooms
*/

-- Drop existing policies
DROP POLICY IF EXISTS "view_chat_rooms" ON chat_rooms;
DROP POLICY IF EXISTS "create_chat_rooms" ON chat_rooms;
DROP POLICY IF EXISTS "update_chat_rooms" ON chat_rooms;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_chat_rooms_product_id_claimer_id ON chat_rooms(product_id, claimer_id);

-- Create simplified and fixed policies
CREATE POLICY "allow_view_own_chats"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = claimer_id OR
    product_id IN (
      SELECT id FROM lost_products WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "allow_create_chat"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = claimer_id AND
    product_id IN (
      SELECT id FROM lost_products WHERE user_id != auth.uid()
    ) AND
    NOT EXISTS (
      SELECT 1 FROM chat_rooms existing
      WHERE existing.product_id = product_id
      AND existing.claimer_id = claimer_id
    )
  );

CREATE POLICY "allow_reporter_update"
  ON chat_rooms
  FOR UPDATE
  TO authenticated
  USING (
    product_id IN (
      SELECT id FROM lost_products WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    product_id IN (
      SELECT id FROM lost_products WHERE user_id = auth.uid()
    )
  );

-- Ensure RLS is enabled
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;

-- Add unique constraint if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_constraint 
    WHERE conname = 'unique_product_claimer'
  ) THEN
    ALTER TABLE chat_rooms ADD CONSTRAINT unique_product_claimer UNIQUE (product_id, claimer_id);
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;