-- ============================================================================
-- Update Yard Background Images
-- ============================================================================
-- This script updates the ImagePath column in the Yards table to set
-- background images for each yard in Cebu Port
-- ============================================================================

-- Update Yard 1 in Cebu Port to use Y4.png
UPDATE Yards
SET ImagePath = 'Y4.png'
WHERE YardNumber = 1 
  AND PortId = (SELECT PortId FROM Ports WHERE PortName LIKE '%Cebu%' OR PortName LIKE '%CEBU%');

-- Optional: Update all yards in Cebu Port to use Y4.png for consistency
UPDATE Yards
SET ImagePath = 'Y4.png'
WHERE PortId = (SELECT PortId FROM Ports WHERE PortName LIKE '%Cebu%' OR PortName LIKE '%CEBU%');

-- Verify the update
SELECT 
    y.YardId,
    y.YardNumber,
    p.PortName,
    y.ImagePath,
    y.YardWidth,
    y.YardHeight
FROM Yards y
INNER JOIN Ports p ON y.PortId = p.PortId
WHERE p.PortName LIKE '%Cebu%' OR p.PortName LIKE '%CEBU%'
ORDER BY y.YardNumber;

-- ============================================================================
-- Alternative: If you know the exact PortId and YardId
-- ============================================================================

-- Example: Update specific yard by ID
-- UPDATE Yards SET ImagePath = 'Y4.png' WHERE YardId = 1;

-- Example: Update all yards to use Y4.png
-- UPDATE Yards SET ImagePath = 'Y4.png';

-- ============================================================================
-- Rollback (if needed)
-- ============================================================================

-- To remove image paths:
-- UPDATE Yards SET ImagePath = NULL WHERE PortId = (SELECT PortId FROM Ports WHERE PortName LIKE '%Cebu%');

-- ============================================================================
-- Notes:
-- ============================================================================
-- 1. The ImagePath should be just the filename (e.g., 'Y4.png')
-- 2. The Flutter app will automatically prepend 'assets/' to the path
-- 3. Make sure Y4.png exists in the assets folder
-- 4. Run 'flutter pub get' after adding new assets
-- 5. Restart the Flutter app (hot reload won't work for assets)
-- ============================================================================
