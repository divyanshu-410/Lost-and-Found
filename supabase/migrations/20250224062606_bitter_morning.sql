/*
  # Fix chat message sending

  1. Changes
    - Update chat messages policies to allow sending messages in approved chats
    - Simplify policy conditions for better performance
    - Add proper authentication checks

  2. Security
    - Maintain RLS security
    - Ensure only authenticated users can send messages
    - Verify chat room approval status before allowing messages
*/

-- Drop existing policies
DROP POLICY IF EXISTS "chat_messages_select_policy" ON chat_messages;
DROP POLICY IF EXISTS "chat_messages_insert_policy" ON chat_messages;

-- Create new simplified policies
CREATE POLICY "chat_messages_select"
  ON chat_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM chat_rooms
      WHERE chat_rooms.id = chat_messages.room_id
      AND (
        chat_rooms.claimer_id = auth.uid() OR
        EXISTS (
          SELECT 1 
          FROM lost_products 
          WHERE id = chat_rooms.product_id 
          AND user_id = auth.uid()
        )
      )
    )
  );

CREATE POLICY "chat_messages_insert"
  ON chat_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 
      FROM chat_rooms
      WHERE id = room_id
      AND (
        (claimer_id = auth.uid() AND approval_status = 'approved') OR
        EXISTS (
          SELECT 1 
          FROM lost_products 
          WHERE id = chat_rooms.product_id 
          AND user_id = auth.uid()
        )
      )
    )
  );

-- Ensure RLS is enabled
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;