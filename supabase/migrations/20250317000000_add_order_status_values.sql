-- Add new order status values for existing databases.
-- Run this only if your order_status enum was created with the original 4 values.
-- New installs should use supabase_schema.sql which already includes all values.

ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'Preparing';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'Awaiting Shipping';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'Delivered';
