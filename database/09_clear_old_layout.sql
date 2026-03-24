-- ── Clear old seeded layout data ─────────────────────────────────────────────
-- Old rows from 03_seed_manila_yard1_layout.sql have SizeId=NULL / OrientationId=NULL
-- We must clear FK references before deleting.

-- Step 1: NULL out container location references (containers pointing to old rows)
UPDATE Containers
SET YardId  = NULL,
    BlockId = NULL,
    BayId   = NULL,
    RowId   = NULL,
    Tier    = NULL
WHERE RowId IS NOT NULL;
GO

-- Step 2: Delete in FK order (Rows → Bays → Blocks)
DELETE FROM Rows;
GO
DELETE FROM Bays;
GO
DELETE FROM Blocks;
GO

PRINT 'Old layout data cleared. Yards are now empty — build layout from the app.';
GO
