/*
  # Chat System Implementation

  1. New Tables
    - `chat_rooms`: Manages chat sessions between users for lost/found items
      - `id` (uuid, primary key)
      - `product_id` (uuid, references lost_products)
      - `claimer_id` (uuid, references auth.users)
      - `status` (text: pending/approved/rejected)
      - `created_at`, `updated_at` (timestamps)
    
    - `chat_messages`: Stores individual chat messages
      - `id` (uuid, primary key)
      - `room_id` (uuid, references chat_rooms)
      - `sender_id` (uuid, references auth.users)
      - `message` (text)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on both tables
    - Add policies for viewing and creating chat rooms
    - Add policies for viewing and sending messages
*/

-- Create chat_rooms table with proper error handling
DO $$ 
BEGIN
  CREATE TABLE IF NOT EXISTS chat_rooms (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id uuid NOT NULL,
    claimer_id uuid NOT NULL,
    status text NOT NULL DEFAULT 'pending',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT chat_rooms_product_id_fkey FOREIGN KEY (product_id) REFERENCES lost_products(id),
    CONSTRAINT chat_rooms_claimer_id_fkey FOREIGN KEY (claimer_id) REFERENCES auth.users(id),
    CONSTRAINT chat_rooms_status_check CHECK (status IN ('pending', 'approved', 'rejected'))
  );
EXCEPTION
  WHEN duplicate_table THEN
    NULL;
END $$;

-- Create chat_messages table with proper error handling
DO $$ 
BEGIN
  CREATE TABLE IF NOT EXISTS chat_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    message text NOT NULL,
    created_at timestamptz DEFAULT now(),
    CONSTRAINT chat_messages_room_id_fkey FOREIGN KEY (room_id) REFERENCES chat_rooms(id),
    CONSTRAINT chat_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id)
  );
EXCEPTION
  WHEN duplicate_table THEN
    NULL;
END $$;

-- Enable RLS with error handling
DO $$ 
BEGIN
  ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
  ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
EXCEPTION
  WHEN others THEN
    NULL;
END $$;

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can view their own chat rooms" ON chat_rooms;
  DROP POLICY IF EXISTS "Users can create chat rooms for products" ON chat_rooms;
  DROP POLICY IF EXISTS "Users can view messages in their chat rooms" ON chat_messages;
  DROP POLICY IF EXISTS "Users can send messages in their chat rooms" ON chat_messages;
EXCEPTION
  WHEN others THEN
    NULL;
END $$;

-- Create policies for chat_rooms
DO $$ 
BEGIN
  CREATE POLICY "Users can view their own chat rooms"
    ON chat_rooms
    FOR SELECT
    TO authenticated
    USING (
      auth.uid() = claimer_id OR 
      EXISTS (
        SELECT 1 FROM lost_products 
        WHERE id = chat_rooms.product_id 
        AND user_id = auth.uid()
      )
    );

  CREATE POLICY "Users can create chat rooms for products"
    ON chat_rooms
    FOR INSERT
    TO authenticated
    WITH CHECK (
      auth.uid() = claimer_id AND
      NOT EXISTS (
        SELECT 1 FROM lost_products 
        WHERE id = product_id 
        AND user_id = auth.uid()
      )
    );
EXCEPTION
  WHEN others THEN
    NULL;
END $$;

-- Create policies for chat_messages
DO $$ 
BEGIN
  CREATE POLICY "Users can view messages in their chat rooms"
    ON chat_messages
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM chat_rooms
        WHERE id = chat_messages.room_id
        AND (
          claimer_id = auth.uid() OR
          product_id IN (
            SELECT id FROM lost_products 
            WHERE user_id = auth.uid()
          )
        )
      )
    );

  CREATE POLICY "Users can send messages in their chat rooms"
    ON chat_messages
    FOR INSERT
    TO authenticated
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM chat_rooms
        WHERE id = room_id
        AND (
          claimer_id = auth.uid() OR
          product_id IN (
            SELECT id FROM lost_products 
            WHERE user_id = auth.uid()
          )
        )
      )
    );
EXCEPTION
  WHEN others THEN
    NULL;
END $$;