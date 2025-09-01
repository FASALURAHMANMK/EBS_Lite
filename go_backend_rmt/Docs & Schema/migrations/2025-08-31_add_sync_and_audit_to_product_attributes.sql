-- Migration: Add sync/audit columns to product_attributes
-- Safe to run multiple times

ALTER TABLE product_attributes
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS sync_status VARCHAR(20) DEFAULT 'synced',
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;

-- Backfill existing rows (in case columns were added without defaults applied)
UPDATE product_attributes
SET
  is_active   = COALESCE(is_active, TRUE),
  sync_status = COALESCE(sync_status, 'synced'),
  created_at  = COALESCE(created_at, CURRENT_TIMESTAMP),
  updated_at  = COALESCE(updated_at, CURRENT_TIMESTAMP),
  is_deleted  = COALESCE(is_deleted, FALSE);

