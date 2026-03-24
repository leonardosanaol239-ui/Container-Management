-- Container Management System Database Schema
-- Database: ContainerManagement (LocalDB)
-- Server: (localdb)\MSSQLLocalDB

-- Create database if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'ContainerManagement')
BEGIN
    CREATE DATABASE ContainerManagement;
END
GO

USE ContainerManagement;
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
    Tier INT NULL CHECK (Tier >= 1 AND Tier <= 5),
    CreatedDate DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (StatusId) REFERENCES Status(StatusId),
    FOREIGN KEY (CurrentPortId) REFERENCES Ports(PortId),
    FOREIGN KEY (YardId) REFERENCES Yards(YardId),
    FOREIGN KEY (BlockId) REFERENCES Blocks(BlockId),
    FOREIGN KEY (BayId) REFERENCES Bays(BayId),
    FOREIGN KEY (RowId) REFERENCES Rows(RowId)
);
GO

PRINT 'All tables created successfully!';
