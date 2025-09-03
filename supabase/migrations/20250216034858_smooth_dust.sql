/*
  # Add Chat Approval System

  1. Changes
    - Add approval_status to chat_rooms table
    - Add policies for approval management
    - Ensure proper access control for contact information

  2. Security
    - Maintain data isolation
    - Restrict contact info visibility
    - Allow reporters to manage approvals
*/

-- Add approval_status to chat_rooms if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'chat_rooms' 
    AND column_name = 'approval_status'
  ) THEN
    ALTER TABLE chat_rooms 
    ADD COLUMN approval_status text NOT NULL DEFAULT 'pending' 
    CHECK (approval_status IN ('pending', 'approved', 'rejected'));
  END IF;
END $$;

-- Update existing policies
DROP POLICY IF EXISTS "Update chat rooms" ON chat_rooms;

CREATE POLICY "Update chat rooms as reporter"
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