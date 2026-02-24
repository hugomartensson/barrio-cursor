-- Drop triggers that referenced the removed location column (dropped in portal_categories_and_spot_save)
DROP TRIGGER IF EXISTS update_events_location ON "events";
DROP TRIGGER IF EXISTS update_spots_location ON "spots";
DROP FUNCTION IF EXISTS update_location_from_coordinates();
