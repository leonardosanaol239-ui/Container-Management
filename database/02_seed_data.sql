-- Seed Data for Container Management System
-- Database: ContainerManagement (LocalDB)

USE ContainerManagement;
GO

-- =============================================
-- 1. Insert Status Data
-- =============================================
INSERT INTO Status (StatusDesc) VALUES ('Laden');
INSERT INTO Status (StatusDesc) VALUES ('Empty');
GO

-- =============================================
-- 2. Insert Ports Data
-- =============================================
INSERT INTO Ports (PortDesc) VALUES ('Manila Port');
INSERT INTO Ports (PortDesc) VALUES ('Cebu Port');
INSERT INTO Ports (PortDesc) VALUES ('Davao Port');
INSERT INTO Ports (PortDesc) VALUES ('Bacolod Port');
INSERT INTO Ports (PortDesc) VALUES ('Cagayan Port');
GO

-- =============================================
-- 3. Insert Yards Data
-- Manila Port: 6 yards
-- Other Ports: 1 yard each
-- =============================================
-- Manila Port Yards (PortId = 1)
INSERT INTO Yards (YardNumber, PortId) VALUES (1, 1);
INSERT INTO Yards (YardNumber, PortId) VALUES (2, 1);
INSERT INTO Yards (YardNumber, PortId) VALUES (3, 1);
INSERT INTO Yards (YardNumber, PortId) VALUES (4, 1);
INSERT INTO Yards (YardNumber, PortId) VALUES (5, 1);
INSERT INTO Yards (YardNumber, PortId) VALUES (6, 1);

-- Cebu Port Yard (PortId = 2)
INSERT INTO Yards (YardNumber, PortId) VALUES (1, 2);

-- Davao Port Yard (PortId = 3)
INSERT INTO Yards (YardNumber, PortId) VALUES (1, 3);

-- Bacolod Port Yard (PortId = 4)
INSERT INTO Yards (YardNumber, PortId) VALUES (1, 4);

-- Cagayan Port Yard (PortId = 5)
INSERT INTO Yards (YardNumber, PortId) VALUES (1, 5);
GO

-- =============================================
-- 4. Insert Blocks Data for Manila Port Yard 1
-- YardId = 1 (Manila Port, Yard 1)
-- =============================================
INSERT INTO Blocks (BlockNumber, BlockDesc, YardId, PortId) VALUES (1, 'Block 1', 1, 1);
INSERT INTO Blocks (BlockNumber, BlockDesc, YardId, PortId) VALUES (2, 'Block 2: Food Grade', 1, 1);
INSERT INTO Blocks (BlockNumber, BlockDesc, YardId, PortId) VALUES (3, 'Block 3: None Food Grade', 1, 1);
INSERT INTO Blocks (BlockNumber, BlockDesc, YardId, PortId) VALUES (4, 'Block 4', 1, 1);
INSERT INTO Blocks (BlockNumber, BlockDesc, YardId, PortId) VALUES (5, 'Block 5', 1, 1);
GO

PRINT 'Seed data inserted successfully!';
PRINT 'Status: 2 records';
PRINT 'Ports: 5 records';
PRINT 'Yards: 10 records';
PRINT 'Blocks: 5 records (Manila Port Yard 1 only)';
