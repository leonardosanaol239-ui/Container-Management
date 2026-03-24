-- Seed Bays, Rows, and Slots for Manila Port Yard 1
-- Database: ContainerManagement (LocalDB)
-- Based on Manila Yard 1 Layout

USE ContainerManagement;
GO

-- =============================================
-- BLOCK 1: 7 Bays × 2 Rows
-- BlockId = 1
-- =============================================
DECLARE @Block1Id INT = 1;
DECLARE @BayId INT;
DECLARE @RowId INT;
DECLARE @BayNum INT;
DECLARE @RowNum INT;

-- Insert Bays for Block 1 (Bay 1-7)
SET @BayNum = 1;
WHILE @BayNum <= 7
BEGIN
    INSERT INTO Bays (BayNumber, BlockId) VALUES (CAST(@BayNum AS NVARCHAR(10)), @Block1Id);
    SET @BayId = SCOPE_IDENTITY();
    
    -- Insert 2 Rows for each Bay
    SET @RowNum = 1;
    WHILE @RowNum <= 2
    BEGIN
        INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
        SET @RowId = SCOPE_IDENTITY();
        
        -- Insert 1 Slot for each Row
        INSERT INTO Slots (RowId, SlotNumber, MaxTier) VALUES (@RowId, 1, 5);
        
        SET @RowNum = @RowNum + 1;
    END
    
    SET @BayNum = @BayNum + 1;
END
GO

-- =============================================
-- BLOCK 2: Food Grade - 7 Bays × 3 Rows
-- BlockId = 2
-- =============================================
DECLARE @Block2Id INT = 2;
DECLARE @BayId INT;
DECLARE @RowId INT;
DECLARE @BayNum INT;
DECLARE @RowNum INT;

-- Insert Bays for Block 2 (Bay 1-7)
SET @BayNum = 1;
WHILE @BayNum <= 7
BEGIN
    INSERT INTO Bays (BayNumber, BlockId) VALUES (CAST(@BayNum AS NVARCHAR(10)), @Block2Id);
    SET @BayId = SCOPE_IDENTITY();
    
    -- Insert 3 Rows for each Bay
    SET @RowNum = 1;
    WHILE @RowNum <= 3
    BEGIN
        INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
        SET @RowId = SCOPE_IDENTITY();
        
        -- Insert 1 Slot for each Row
        INSERT INTO Slots (RowId, SlotNumber, MaxTier) VALUES (@RowId, 1, 5);
        
        SET @RowNum = @RowNum + 1;
    END
    
    SET @BayNum = @BayNum + 1;
END
GO

-- =============================================
-- BLOCK 3: None Food Grade - 7 Bays × 3 Rows
-- BlockId = 3
-- =============================================
DECLARE @Block3Id INT = 3;
DECLARE @BayId INT;
DECLARE @RowId INT;
DECLARE @BayNum INT;
DECLARE @RowNum INT;

-- Insert Bays for Block 3 (Bay 1-7)
SET @BayNum = 1;
WHILE @BayNum <= 7
BEGIN
    INSERT INTO Bays (BayNumber, BlockId) VALUES (CAST(@BayNum AS NVARCHAR(10)), @Block3Id);
    SET @BayId = SCOPE_IDENTITY();
    
    -- Insert 3 Rows for each Bay
    SET @RowNum = 1;
    WHILE @RowNum <= 3
    BEGIN
        INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
        SET @RowId = SCOPE_IDENTITY();
        
        -- Insert 1 Slot for each Row
        INSERT INTO Slots (RowId, SlotNumber, MaxTier) VALUES (@RowId, 1, 5);
        
        SET @RowNum = @RowNum + 1;
    END
    
    SET @BayNum = @BayNum + 1;
END
GO

-- =============================================
-- BLOCK 4: 7 Bays × 2 Rows
-- BlockId = 4
-- Bays: 1, 2, 3, 5, 6, 7, 8 (skipping 4)
-- =============================================
DECLARE @Block4Id INT = 4;
DECLARE @BayId INT;
DECLARE @RowId INT;
DECLARE @RowNum INT;

-- Bay 1
INSERT INTO Bays (BayNumber, BlockId) VALUES ('1', @Block4Id);
SET @BayId = SCOPE_IDENTITY();
SET @RowNum = 1;
WHILE @RowNum <= 2
BEGIN
    INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
    SET @RowId = SCOPE_IDENTITY();
    INSERT INTO Slots (RowId, SlotNumber, MaxTier) VALUES (@RowId, 1, 5);
    SET @RowNum = @RowNum + 1;
END

-- Bay 2
INSERT INTO Bays (BayNumber, BlockId) VALUES ('2', @Block4Id);
SET @BayId = SCOPE_IDENTITY();
SET @RowNum = 1;
WHILE @RowNum <= 2
BEGIN
    INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
    SET @RowId = SCOPE_IDENTITY();
    INSERT INTO Slots (RowId, SlotNumber, MaxTier) VALUES (@RowId, 1, 5);
    SET @RowNum = @RowNum + 1;
END

-- Bay 3
INSERT INTO Bays (BayNumber, BlockId) VALUES ('3', @Block4Id);
SET @BayId = SCOPE_IDENTITY();
SET @RowNum = 1;
WHILE @RowNum <= 2
BEGIN
    INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
    SET @RowId = SCOPE_IDENTITY();
    INSERT INTO Slots (RowId, SlotNumber, MaxTier) VALUES (@RowId, 1, 5);
    SET @RowNum = @RowNum + 1;
END

-- Bay 5
INSERT INTO Bays (BayNumber, BlockId) VALUES ('5', @Block4Id);
SET @BayId = SCOPE_IDENTITY();
SET @RowNum = 1;
WHILE @RowNum <= 2
BEGIN
    INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
    SET @RowId = SCOPE_IDENTITY();
    INSERT INTO Slots (RowId, SlotNumber, MaxTier) VALUES (@RowId, 1, 5);
    SET @RowNum = @RowNum + 1;
END

-- Bay 6
INSERT INTO Bays (BayNumber, BlockId) VALUES ('6', @Block4Id);
SET @BayId = SCOPE_IDENTITY();
SET @RowNum = 1;
WHILE @RowNum <= 2
BEGIN
    INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
    SET @RowId = SCOPE_IDENTITY();
    INSERT INTO Slots (RowId, SlotNumber, MaxTier) VALUES (@RowId, 1, 5);
    SET @RowNum = @RowNum + 1;
END

-- Bay 7
INSERT INTO Bays (BayNumber, BlockId) VALUES ('7', @Block4Id);
SET @BayId = SCOPE_IDENTITY();
SET @RowNum = 1;
WHILE @RowNum <= 2
BEGIN
    INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
    SET @RowId = SCOPE_IDENTITY();
    INSERT INTO Slots (RowId, SlotNumber, MaxTier) VALUES (@RowId, 1, 5);
    SET @RowNum = @RowNum + 1;
END

-- Bay 8
INSERT INTO Bays (BayNumber, BlockId) VALUES ('8', @Block4Id);
SET @BayId = SCOPE_IDENTITY();
SET @RowNum = 1;
WHILE @RowNum <= 2
BEGIN
    INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
    SET @RowId = SCOPE_IDENTITY();
    INSERT INTO Slots (RowId, SlotNumber, MaxTier) VALUES (@RowId, 1, 5);
    SET @RowNum = @RowNum + 1;
END
GO

-- =============================================
-- BLOCK 5: 2 Bays × 3 Rows (Vertical)
-- BlockId = 5
-- =============================================
DECLARE @Block5Id INT = 5;
DECLARE @BayId INT;
DECLARE @RowId INT;
DECLARE @BayNum INT;
DECLARE @RowNum INT;

-- Insert Bays for Block 5 (Bay 1-2)
SET @BayNum = 1;
WHILE @BayNum <= 2
BEGIN
    INSERT INTO Bays (BayNumber, BlockId) VALUES (CAST(@BayNum AS NVARCHAR(10)), @Block5Id);
    SET @BayId = SCOPE_IDENTITY();
    
    -- Insert 3 Rows for each Bay
    SET @RowNum = 1;
    WHILE @RowNum <= 3
    BEGIN
        INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
        SET @RowId = SCOPE_IDENTITY();
        
        -- Insert 1 Slot for each Row
        INSERT INTO Slots (RowId, SlotNumber, MaxTier) VALUES (@RowId, 1, 5);
        
        SET @RowNum = @RowNum + 1;
    END
    
    SET @BayNum = @BayNum + 1;
END
GO

PRINT 'Manila Yard 1 Layout Created Successfully!';
PRINT 'Block 1: 7 bays × 2 rows = 14 slots';
PRINT 'Block 2: 7 bays × 3 rows = 21 slots';
PRINT 'Block 3: 7 bays × 3 rows = 21 slots';
PRINT 'Block 4: 7 bays × 2 rows = 14 slots';
PRINT 'Block 5: 2 bays × 3 rows = 6 slots';
PRINT 'Total Slots: 76 slots';
