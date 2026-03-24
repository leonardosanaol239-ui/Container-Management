-- Verification Script for Container Management System
-- Database: ojt_2026_01_1

USE ojt_2026_01_1;
GO

PRINT '========================================';
PRINT 'DATABASE VERIFICATION REPORT';
PRINT '========================================';
PRINT '';

-- Check Status Table
PRINT '1. STATUS TABLE:';
SELECT StatusId, StatusDesc FROM Status;
PRINT '';

-- Check Ports Table
PRINT '2. PORTS TABLE:';
SELECT PortId, PortDesc FROM Ports;
PRINT '';

-- Check Yards Table
PRINT '3. YARDS TABLE:';
SELECT YardId, YardNumber, PortId FROM Yards ORDER BY PortId, YardNumber;
PRINT '';

-- Check Blocks Table
PRINT '4. BLOCKS TABLE (Manila Yard 1):';
SELECT BlockId, BlockNumber, BlockDesc, YardId, PortId FROM Blocks WHERE YardId = 1;
PRINT '';

-- Check Bays Count per Block
PRINT '5. BAYS COUNT PER BLOCK:';
SELECT 
    b.BlockId,
    b.BlockDesc,
    COUNT(bay.BayId) AS TotalBays
FROM Blocks b
LEFT JOIN Bays bay ON b.BlockId = bay.BlockId
WHERE b.YardId = 1
GROUP BY b.BlockId, b.BlockDesc
ORDER BY b.BlockId;
PRINT '';

-- Check Rows Count per Block
PRINT '6. ROWS COUNT PER BLOCK:';
SELECT 
    b.BlockId,
    b.BlockDesc,
    COUNT(r.RowId) AS TotalRows
FROM Blocks b
LEFT JOIN Bays bay ON b.BlockId = bay.BlockId
LEFT JOIN Rows r ON bay.BayId = r.BayId
WHERE b.YardId = 1
GROUP BY b.BlockId, b.BlockDesc
ORDER BY b.BlockId;
PRINT '';

-- Check Slots Count per Block
PRINT '7. SLOTS COUNT PER BLOCK:';
SELECT 
    b.BlockId,
    b.BlockDesc,
    COUNT(s.SlotId) AS TotalSlots
FROM Blocks b
LEFT JOIN Bays bay ON b.BlockId = bay.BlockId
LEFT JOIN Rows r ON bay.BayId = r.BayId
LEFT JOIN Slots s ON r.RowId = s.RowId
WHERE b.YardId = 1
GROUP BY b.BlockId, b.BlockDesc
ORDER BY b.BlockId;
PRINT '';

-- Total Summary
PRINT '8. TOTAL SUMMARY:';
SELECT 
    (SELECT COUNT(*) FROM Status) AS TotalStatuses,
    (SELECT COUNT(*) FROM Ports) AS TotalPorts,
    (SELECT COUNT(*) FROM Yards) AS TotalYards,
    (SELECT COUNT(*) FROM Blocks WHERE YardId = 1) AS TotalBlocks_ManilaYard1,
    (SELECT COUNT(*) FROM Bays WHERE BlockId IN (SELECT BlockId FROM Blocks WHERE YardId = 1)) AS TotalBays_ManilaYard1,
    (SELECT COUNT(*) FROM Rows WHERE BayId IN (SELECT BayId FROM Bays WHERE BlockId IN (SELECT BlockId FROM Blocks WHERE YardId = 1))) AS TotalRows_ManilaYard1,
    (SELECT COUNT(*) FROM Slots WHERE RowId IN (SELECT RowId FROM Rows WHERE BayId IN (SELECT BayId FROM Bays WHERE BlockId IN (SELECT BlockId FROM Blocks WHERE YardId = 1)))) AS TotalSlots_ManilaYard1,
    (SELECT COUNT(*) FROM Containers) AS TotalContainers;
PRINT '';

PRINT '========================================';
PRINT 'VERIFICATION COMPLETE!';
PRINT '========================================';
