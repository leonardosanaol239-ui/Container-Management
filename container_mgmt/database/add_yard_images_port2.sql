-- ============================================================================
-- Add Yard Background Images for Port 2
-- ============================================================================
-- This script adds Y4.png as the background image for yards in Port 2
-- ============================================================================

-- Update ALL yards in Port 2 to use Y4.png
UPDATE Yards
SET ImagePath = 'Y4.png'
WHERE PortId = 2;

-- Verify the update
SELECT 
    y.YardId,
    y.YardNumber,
    y.PortId,
    p.PortName,
    y.ImagePath,
    y.YardWidth,
    y.YardHeight
FROM Yards y
INNER JOIN Ports p ON y.PortId = p.PortId
WHERE y.PortId = 2
ORDER BY y.YardNumber;

-- ============================================================================
-- Complete Setup for All Ports (using Y4.png for consistency)
-- ============================================================================

-- Port 1 (Cebu) - Use Y4.png
UPDATE Yards SET ImagePath = 'Y4.png' WHERE PortId = 1;

-- Port 2 - Use Y4.png
UPDATE Yards SET ImagePath = 'Y4.png' WHERE PortId = 2;

-- Optional: Update all other ports to use Y4.png
-- UPDATE Yards SET ImagePath = 'Y4.png' WHERE PortId = 3;
-- UPDATE Yards SET ImagePath = 'Y4.png' WHERE PortId = 4;

-- Or update ALL yards at once to use Y4.png
-- UPDATE Yards SET ImagePath = 'Y4.png';

-- ============================================================================
-- View All Yard Images Across All Ports
-- ============================================================================

SELECT 
    p.PortId,
    p.PortName,
    y.YardId,
    y.YardNumber,
    y.ImagePath,
    CASE 
        WHEN y.ImagePath IS NULL THEN '❌ No Image'
        WHEN y.ImagePath = '' THEN '❌ Empty'
        ELSE '✅ ' + y.ImagePath
    END AS Status
FROM Ports p
LEFT JOIN Yards y ON p.PortId = y.PortId
ORDER BY p.PortId, y.YardNumber;

-- ============================================================================
-- Quick Command: Update Port 2 to Y4.png
-- ============================================================================

UPDATE Yards SET ImagePath = 'Y4.png' WHERE PortId = 2;

-- ============================================================================
