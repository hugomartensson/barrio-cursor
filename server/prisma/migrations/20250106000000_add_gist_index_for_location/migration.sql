-- Add location geometry column for PostGIS
ALTER TABLE "events" ADD COLUMN IF NOT EXISTS "location" geometry(Point, 4326);

-- Populate location column from existing latitude/longitude
UPDATE "events" 
SET "location" = ST_SetSRID(ST_MakePoint("longitude", "latitude"), 4326)
WHERE "location" IS NULL;

-- Drop the old B-tree index on (latitude, longitude)
DROP INDEX IF EXISTS "events_latitude_longitude_idx";

-- Create GIST spatial index on location column for optimal PostGIS query performance
CREATE INDEX IF NOT EXISTS "events_location_idx" ON "events" USING GIST ("location");

-- Add trigger to keep location in sync with latitude/longitude changes
CREATE OR REPLACE FUNCTION update_event_location()
RETURNS TRIGGER AS $$
BEGIN
  NEW."location" = ST_SetSRID(ST_MakePoint(NEW."longitude", NEW."latitude"), 4326);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS events_location_trigger ON "events";
CREATE TRIGGER events_location_trigger
  BEFORE INSERT OR UPDATE OF "latitude", "longitude" ON "events"
  FOR EACH ROW
  EXECUTE FUNCTION update_event_location();
