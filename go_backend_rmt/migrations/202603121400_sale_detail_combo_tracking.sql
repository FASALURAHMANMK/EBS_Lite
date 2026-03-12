-- +goose Up
ALTER TABLE sale_details
  ADD COLUMN IF NOT EXISTS combo_component_tracking JSONB;

-- +goose Down
ALTER TABLE sale_details
  DROP COLUMN IF EXISTS combo_component_tracking;
