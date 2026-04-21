-- Add optional spot_id FK to events so events can be anchored to a Barrio spot.
-- ON DELETE SET NULL: if the spot is deleted, the event keeps its address/coords but loses the link.

ALTER TABLE "events" ADD COLUMN "spot_id" TEXT;

ALTER TABLE "events"
  ADD CONSTRAINT "events_spot_id_fkey"
  FOREIGN KEY ("spot_id")
  REFERENCES "spots"("id")
  ON DELETE SET NULL
  ON UPDATE CASCADE;

CREATE INDEX "events_spot_id_idx" ON "events"("spot_id");
