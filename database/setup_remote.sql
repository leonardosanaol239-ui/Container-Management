-- Setup script for REMOTE database (192.168.76.119)
-- Database: ojt_2026_01_1

USE ojt_2026_01_1;
GO

-- Drop existing tables if they exist (for clean setup)
IF OBJECT_ID('Containers', 'U') IS NOT NULL DROP TABLE Containers;
IF OBJECT_ID('Slots', 'U') IS NOT NULL DROP TABLE Slots;
IF OBJECT_ID('Rows', 'U') IS NOT NULL DROP TABLE Rows;
IF OBJECT_ID('Bays', 'U') IS NOT NULL DROP TABLE Bays;
IF OBJECT_ID('Blocks', 'U') IS NOT NULL DROP TABLE Blocks;
IF OBJECT_ID('Yards', 'U') IS NOT NULL DROP TABLE Yards;
IF OBJECT_ID('Ports', 'U') IS NOT NULL DROP TABLE Ports;
IF OBJECT_ID('Status', 'U') IS NOT NULL DROP TABLE Status;
GO

-- =============================================
-- 1. Status Table (Laden/Empty)
-- =============================================
CREATE TABLE Status (
    StatusId INT PRIMARY KEY IDENTITY(1,1),
    StatusDesc NVARCHAR(50) NOT NULL
);
GO

-- =============================================
-- 2. Ports Table
-- =============================================
CREATE TABLE Ports (
    PortId INT PRIMARY KEY IDENTITY(1,1),
    PortDesc NVARCHAR(100) NOT NULL
);
GO

-- =============================================
-- 3. Yards Table
-- =============================================
CREATE TABLE Yards (
    YardId INT PRIMARY KEY IDENTITY(1,1),
    YardNumber INT NOT NULL,
    PortId INT NOT NULL,
    FOREIGN KEY (PortId) REFERENCES Ports(PortId)
);
GO

-- =============================================
-- 4. Blocks Table
-- =============================================
CREATE TABLE Blocks (
    BlockId INT PRIMARY KEY IDENTITY(1,1),
    BlockNumber INT NOT NULL,
    BlockDesc NVARCHAR(100),
    YardId INT NOT NULL,
    PortId INT NOT NULL,
    FOREIGN KEY (YardId) REFERENCES Yards(YardId),
    FOREIGN KEY (PortId) REFERENCES Ports(PortId)
);
GO

-- =============================================
-- 5. Bays Table
-- =============================================
CREATE TABLE Bays (
    BayId INT PRIMARY KEY IDENTITY(1,1),
    BayNumber NVARCHAR(10) NOT NULL,
    BlockId INT NOT NULL,
    FOREIGN KEY (BlockId) REFERENCES Blocks(BlockId)
);
GO

-- =============================================
-- 6. Rows Table
-- =============================================
CREATE TABLE Rows (
    RowId INT PRIMARY KEY IDENTITY(1,1),
    RowNumber INT NOT NULL,
    BayId INT NOT NULL,
    FOREIGN KEY (BayId) REFERENCES Bays(BayId)
);
GO

-- =============================================
-- 7. Slots Table
-- =============================================
CREATE TABLE Slots (
    SlotId INT PRIMARY KEY IDENTITY(1,1),
    RowId INT NOT NULL,
    SlotNumber INT NOT NULL,
    MaxTier INT DEFAULT 5,
    FOREIGN KEY (RowId) REFERENCES Rows(RowId)
);
GO

-- =============================================
-- 8. Containers Table
-- =============================================
CREATE TABLE Containers (
    ContainerId INT PRIMARY KEY IDENTITY(1,1),
    ContainerNumber NVARCHAR(50) NOT NULL UNIQUE,
    StatusId INT NOT NULL,
    Type NVARCHAR(100),
    ContainerDesc NVARCHAR(MAX),
    CurrentPortId INT NOT NULL,
    YardId INT NULL,
    BlockId INT NULL,
    BayId INT NULL,
    RowId INT NULL,
    SlotId INT NULL,
    Tier INT NULL CHECK (Tier >= 1 AND Tier <= 5),
    CreatedDate DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (StatusId) REFERENCES Status(StatusId),
    FOREIGN KEY (CurrentPortId) REFERENCES Ports(PortId),
    FOREIGN KEY (YardId) REFERENCES Yards(YardId),
    FOREIGN KEY (BlockId) REFERENCES Blocks(BlockId),
    FOREIGN KEY (BayId) REFERENCES Bays(BayId),
    FOREIGN KEY (RowId) REFERENCES Rows(RowId),
    FOREIGN KEY (SlotId) REFERENCES Slots(SlotId)
);
GO

PRINT 'All tables created successfully on REMOTE server!';

-- =============================================
-- INSERT SEED DATA
-- =============================================

-- Insert Status Data
INSERT INTO Status (StatusDesc) VALUES ('Laden');
INSERT INTO Status (StatusDesc) VALUES ('Empty');
PRINT 'Status data inserted: 2 records';

-- Insert Ports Data
INSERT INTO Ports (PortDesc) VALUES ('Manila Port');
INSERT INTO Ports (PortDesc) VALUES ('Cebu Port');
INSERT INTO Ports (PortDesc) VALUES ('Davao Port');
INSERT INTO Ports (PortDesc) VALUES ('Bacolod Port');
INSERT INTO Ports (PortDesc) VALUES ('Cagayan Port');
PRINT 'Ports data inserted: 5 records';

-- Insert Yards Data (Manila Port gets 6 yards, others get 1 each)
-- Manila Port Yards (PortId = 1)
INSERT INTO Yards (YardNumber, PortId) VALUES (1, 1);
INSERT INTO Yards (YardNumber, PortId) VALUES (2, 1);
INSERT INTO Yards (YardNumber, PortId) VALUES (3, 1);
INSERT INTO Yards (YardNumber, PortId) VALUES (4, 1);
INSERT INTO Yards (YardNumber, PortId) VALUES (5, 1);
INSERT INTO Yards (YardNumber, PortId) VALUES (6, 1);

-- Other Ports Yards
INSERT INTO Yards (YardNumber, PortId) VALUES (1, 2); -- Cebu
INSERT INTO Yards (YardNumber, PortId) VALUES (1, 3); -- Davao
INSERT INTO Yards (YardNumber, PortId) VALUES (1, 4); -- Bacolod
INSERT INTO Yards (YardNumber, PortId) VALUES (1, 5); -- Cagayan
PRINT 'Yards data inserted: 10 records';

-- Insert Blocks for Manila Port Yard 1 only (YardId = 1)
INSERT INTO Blocks (BlockNumber, BlockDesc, YardId, PortId) VALUES (1, 'Block 1', 1, 1);
INSERT INTO Blocks (BlockNumber, BlockDesc, YardId, PortId) VALUES (2, 'Block 2', 1, 1);
INSERT INTO Blocks (BlockNumber, BlockDesc, YardId, PortId) VALUES (3, 'Block 3', 1, 1);
INSERT INTO Blocks (BlockNumber, BlockDesc, YardId, PortId) VALUES (4, 'Block 4', 1, 1);
INSERT INTO Blocks (BlockNumber, BlockDesc, YardId, PortId) VALUES (5, 'Block 5', 1, 1);
PRINT 'Blocks data inserted: 5 records (Manila Port Yard 1 only)';

-- =============================================
-- MANILA YARD 1 LAYOUT SETUP
-- =============================================

-- BLOCK 1: 7 Bays × 2 Rows (BlockId = 1)
DECLARE @BlockId INT = 1;
DECLARE @BayLetter CHAR(1);
DECLARE @BayId INT;
DECLARE @RowNum INT;
DECLARE @RowId INT;

-- Block 1: Bays A-G, 2 rows each
SET @BayLetter = 'A';
WHILE @BayLetter <= 'G'
BEGIN
    INSERT INTO Bays (BayNumber, BlockId) VALUES (@BayLetter, @BlockId);
    SET @BayId = SCOPE_IDENTITY();
    
    SET @RowNum = 1;
    WHILE @RowNum <= 2
    BEGIN
        INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
        SET @RowId = SCOPE_IDENTITY();
        INSERT INTO Slots (RowId, SlotNumber) VALUES (@RowId, 1);
        SET @RowNum = @RowNum + 1;
    END
    
    SET @BayLetter = CHAR(ASCII(@BayLetter) + 1);
END

-- BLOCK 2: 7 Bays × 3 Rows (BlockId = 2)
SET @BlockId = 2;
SET @BayLetter = 'A';
WHILE @BayLetter <= 'G'
BEGIN
    INSERT INTO Bays (BayNumber, BlockId) VALUES (@BayLetter, @BlockId);
    SET @BayId = SCOPE_IDENTITY();
    
    SET @RowNum = 1;
    WHILE @RowNum <= 3
    BEGIN
        INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
        SET @RowId = SCOPE_IDENTITY();
        INSERT INTO Slots (RowId, SlotNumber) VALUES (@RowId, 1);
        SET @RowNum = @RowNum + 1;
    END
    
    SET @BayLetter = CHAR(ASCII(@BayLetter) + 1);
END

-- BLOCK 3: 7 Bays × 3 Rows (BlockId = 3)
SET @BlockId = 3;
SET @BayLetter = 'A';
WHILE @BayLetter <= 'G'
BEGIN
    INSERT INTO Bays (BayNumber, BlockId) VALUES (@BayLetter, @BlockId);
    SET @BayId = SCOPE_IDENTITY();
    
    SET @RowNum = 1;
    WHILE @RowNum <= 3
    BEGIN
        INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
        SET @RowId = SCOPE_IDENTITY();
        INSERT INTO Slots (RowId, SlotNumber) VALUES (@RowId, 1);
        SET @RowNum = @RowNum + 1;
    END
    
    SET @BayLetter = CHAR(ASCII(@BayLetter) + 1);
END

-- BLOCK 4: 7 Bays × 2 Rows (BlockId = 4)
SET @BlockId = 4;
SET @BayLetter = 'A';
WHILE @BayLetter <= 'G'
BEGIN
    INSERT INTO Bays (BayNumber, BlockId) VALUES (@BayLetter, @BlockId);
    SET @BayId = SCOPE_IDENTITY();
    
    SET @RowNum = 1;
    WHILE @RowNum <= 2
    BEGIN
        INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
        SET @RowId = SCOPE_IDENTITY();
        INSERT INTO Slots (RowId, SlotNumber) VALUES (@RowId, 1);
        SET @RowNum = @RowNum + 1;
    END
    
    SET @BayLetter = CHAR(ASCII(@BayLetter) + 1);
END

-- BLOCK 5: 2 Bays × 3 Rows (BlockId = 5)
SET @BlockId = 5;
SET @BayLetter = 'A';
WHILE @BayLetter <= 'B'
BEGIN
    INSERT INTO Bays (BayNumber, BlockId) VALUES (@BayLetter, @BlockId);
    SET @BayId = SCOPE_IDENTITY();
    
    SET @RowNum = 1;
    WHILE @RowNum <= 3
    BEGIN
        INSERT INTO Rows (RowNumber, BayId) VALUES (@RowNum, @BayId);
        SET @RowId = SCOPE_IDENTITY();
        INSERT INTO Slots (RowId, SlotNumber) VALUES (@RowId, 1);
        SET @RowNum = @RowNum + 1;
    END
    
    SET @BayLetter = CHAR(ASCII(@BayLetter) + 1);
END

PRINT 'Manila Yard 1 Layout Created Successfully on REMOTE server!';
PRINT 'Block 1: 7 bays × 2 rows = 14 slots';
PRINT 'Block 2: 7 bays × 3 rows = 21 slots';
PRINT 'Block 3: 7 bays × 3 rows = 21 slots';
PRINT 'Block 4: 7 bays × 2 rows = 14 slots';
PRINT 'Block 5: 2 bays × 3 rows = 6 slots';
PRINT 'Total Slots: 76 slots';

PRINT 'REMOTE database setup completed successfully!';