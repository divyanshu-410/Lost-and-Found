/*
  # Create storage bucket for product photos

  1. Storage
    - Create 'product-photos' bucket for storing lost item images
  
  2. Security
    - Enable public access for viewing photos
    - Allow authenticated users to upload photos
*/

-- Create the storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-photos', 'product-photos', true);

-- Allow public access to view photos
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'product-photos');

-- Allow authenticated users to upload photos
CREATE POLICY "Authenticated users can upload photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'product-photos'
  AND owner = auth.uid()
);