-- ============================================================================
-- Fix Cebu Port Yard Dimensions to match Manila for consistent block sizing
-- ============================================================================
-- Manila Port (PortId = 1) yards use 300ft x 170ft as the standard.
-- Cebu Port (PortId = 2) yards should use the same dimensions so that
-- the fitScale is consistent and block/cell sizes appear the same size.
-- ============================================================================

PRINT 'Current Cebu yard dimensions:';
SELECT y.YardId, y.YardNumber, y.YardWidth, y.YardHeight, y.ImagePath
FROM Yards y
WHERE y.PortId = 2
ORDER BY y.YardNumber;

-- Update Cebu yards to standard dimensions (300 x 170 ft)
UPDATE Yards
SET YardWidth  = 300,
    YardHeight = 170
WHERE PortId = 2
  AND (YardWidth IS NULL OR YardHeight IS NULL OR YardWidth < 200);

PRINT 'After update:';
SELECT y.YardId, y.YardNumber, y.YardWidth, y.YardHeight
FROM Yards y
WHERE y.PortId = 2
ORDER BY y.YardNumber;
