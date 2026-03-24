-- ── Fix: Move layout columns from Rows to Slots ─────────────────────────────
-- The Rows table had SizeId/OrientationId/MaxStack/IsDeleted added by mistake.
-- These belong on Slots (individual slots can differ in size/orientation/stack).

-- Step 1: Remove wrongly-added columns from Rows (if they exist)
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Rows') AND name = 'SizeId')
    ALTER TABLE Rows DROP CONSTRAINT IF EXISTS FK__Rows__SizeId__XXXXXXXX;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Rows') AND name = 'OrientationId')
    ALTER TABLE Rows DROP CONSTRAINT IF EXISTS FK__Rows__Orientatio__XXXXXXXX;
GO

-- Drop FK constraints on Rows dynamically
DECLARE @sql NVARCHAR(MAX) = '';
SELECT @sql += 'ALTER TABLE Rows DROP CONSTRAINT ' + QUOTENAME(fk.name) + '; '
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
JOIN sys.columns c ON fkc.parent_object_id = c.object_id AND fkc.parent_column_id = c.column_id
WHERE fk.parent_object_id = OBJECT_ID('Rows')
  AND c.name IN ('SizeId', 'OrientationId');
IF LEN(@sql) > 0 EXEC sp_executesql @sql;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Rows') AND name = 'SizeId')
    ALTER TABLE Rows DROP COLUMN SizeId;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Rows') AND name = 'OrientationId')
    ALTER TABLE Rows DROP COLUMN OrientationId;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Rows') AND name = 'MaxStack')
    ALTER TABLE Rows DROP COLUMN MaxStack;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Rows') AND name = 'IsDeleted')
    ALTER TABLE Rows DROP COLUMN IsDeleted;
GO

-- Step 2: Add layout columns to Slots (where they belong)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Slots') AND name = 'SizeId')
    ALTER TABLE Slots ADD SizeId INT NULL REFERENCES Sizes(SizeId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Slots') AND name = 'OrientationId')
    ALTER TABLE Slots ADD OrientationId INT NULL REFERENCES Orientations(OrientationId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Slots') AND name = 'MaxStack')
    ALTER TABLE Slots ADD MaxStack INT NOT NULL DEFAULT 5;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Slots') AND name = 'IsDeleted')
    ALTER TABLE Slots ADD IsDeleted BIT NOT NULL DEFAULT 0;
GO

-- Step 3: Add PosX/PosY to Slots for empty-space tracking (deleted slots keep position)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Slots') AND name = 'PosX')
    ALTER TABLE Slots ADD PosX FLOAT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Slots') AND name = 'PosY')
    ALTER TABLE Slots ADD PosY FLOAT NULL;
GO

-- Step 4: Ensure Blocks has BlockName column (from migration 06)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Blocks') AND name = 'BlockName')
    ALTER TABLE Blocks ADD BlockName NVARCHAR(100) NULL;
GO

-- Step 5: Verify
SELECT 'Slots columns' AS Info;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Slots'
ORDER BY ORDINAL_POSITION;

SELECT 'Rows columns' AS Info;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Rows'
ORDER BY ORDINAL_POSITION;
