/*
  # Fix chat message policies

  1. Changes
    - Drop existing chat message policies
    - Create new simplified policies for chat messages
    - Add proper authentication checks
    - Ensure proper indexes exist

  2. Security
    - Enable RLS
    - Add policies for viewing and sending messages
    - Ensure proper authentication checks
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Allow viewing messages in own chats" ON chat_messages;
DROP POLICY IF EXISTS "Allow sending messages in own chats" ON chat_messages;

-- Create new policies with proper authentication checks
CREATE POLICY "chat_messages_select_policy"
  ON chat_messages
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 
      FROM chat_rooms
      WHERE chat_rooms.id = chat_messages.room_id
      AND (
        chat_rooms.claimer_id = auth.uid() OR
        chat_rooms.product_id IN (
          SELECT id 
          FROM lost_products 
          WHERE user_id = auth.uid()
        )
      )
    )
  );

CREATE POLICY "chat_messages_insert_policy"
  ON chat_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 
      FROM chat_rooms
      WHERE chat_rooms.id = room_id
      AND chat_rooms.approval_status = 'approved'
      AND (
        chat_rooms.claimer_id = auth.uid() OR
        chat_rooms.product_id IN (
          SELECT id 
          FROM lost_products 
          WHERE user_id = auth.uid()
        )
      )
    )
  );

-- Ensure indexes exist for performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id ON chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at);

-- Ensure RLS is enabled
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;