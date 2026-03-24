-- ── Merge Slots table into Rows ───────────────────────────────────────────────
-- Slots and Rows are 1:1, so we collapse them into a single Rows table.
-- Containers already reference RowId directly — no change needed there.

-- Step 1: Copy slot data into Rows (SizeId, OrientationId, MaxStack, IsDeleted, PosX, PosY)
-- These columns were already added to Rows by migration 07 (MaxStack, IsDeleted)
-- and to Slots by migration 07 (SizeId, OrientationId, MaxStack, IsDeleted, PosX, PosY).
-- We need to ensure Rows has all the slot columns.

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Rows') AND name = 'SizeId')
    ALTER TABLE Rows ADD SizeId INT NULL REFERENCES Sizes(SizeId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Rows') AND name = 'OrientationId')
    ALTER TABLE Rows ADD OrientationId INT NULL REFERENCES Orientations(OrientationId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Rows') AND name = 'PosX')
    ALTER TABLE Rows ADD PosX FLOAT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Rows') AND name = 'PosY')
    ALTER TABLE Rows ADD PosY FLOAT NULL;
GO
-- MaxStack and IsDeleted already exist on Rows from migration 07
-- Make sure MaxStack has a proper default
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Rows') AND name = 'MaxStack')
BEGIN
    -- Update NULL MaxStack values to 5
    UPDATE Rows SET MaxStack = 5 WHERE MaxStack IS NULL;
END
GO

-- Step 2: Copy data from Slots into Rows
UPDATE r
SET
    r.SizeId        = s.SizeId,
    r.OrientationId = s.OrientationId,
    r.MaxStack      = ISNULL(s.MaxStack, 5),
    r.IsDeleted     = s.IsDeleted,
    r.PosX          = s.PosX,
    r.PosY          = s.PosY
FROM Rows r
JOIN Slots s ON s.RowId = r.RowId;
GO

-- Step 3: Update Containers FK — already points to RowId, no change needed.

-- Step 4: Drop Slots table (remove FK from Slots first)
IF OBJECT_ID('Slots', 'U') IS NOT NULL
BEGIN
    -- Drop any FK constraints on Slots
    DECLARE @sql NVARCHAR(MAX) = '';
    SELECT @sql += 'ALTER TABLE Slots DROP CONSTRAINT ' + QUOTENAME(name) + '; '
    FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID('Slots');
    IF LEN(@sql) > 0 EXEC sp_executesql @sql;

    DROP TABLE Slots;
END
GO

-- Step 5: Verify final Rows schema
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Rows'
ORDER BY ORDINAL_POSITION;
GO

PRINT 'Slots merged into Rows successfully.';
