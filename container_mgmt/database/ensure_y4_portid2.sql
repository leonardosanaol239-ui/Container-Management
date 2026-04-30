-- ============================================================================
-- ENSURE Y4 IS IN DATABASE FOR PORTID2
-- ============================================================================
-- This script ensures that Y4.png is set as the ImagePath for all yards
-- in Port 2 (PortId = 2)
-- ============================================================================

PRINT '============================================================================';
PRINT 'ENSURING Y4.png FOR PORTID2';
PRINT '============================================================================';
PRINT '';

-- Step 1: Check current state of Port 2
PRINT 'BEFORE UPDATE - Current state of Port 2:';
SELECT 
    y.YardId,
    y.YardNumber,
    y.PortId,
    y.ImagePath,
    CASE 
        WHEN y.ImagePath = 'Y4.png' THEN '✅ Already Y4.png'
        WHEN y.ImagePath IS NULL THEN '❌ NULL - Needs Update'
        WHEN y.ImagePath = '' THEN '❌ Empty - Needs Update'
        ELSE '⚠️ Different Image: ' + y.ImagePath
    END AS Status
FROM Yards y
WHERE y.PortId = 2
ORDER BY y.YardNumber;
PRINT '';

-- Step 2: Update ALL yards in Port 2 to use Y4.png
PRINT 'UPDATING Port 2 yards to Y4.png...';
UPDATE Yards
SET ImagePath = 'Y4.png'
WHERE PortId = 2;

PRINT 'Update completed!';
PRINT '';

-- Step 3: Verify the update
PRINT 'AFTER UPDATE - Verification:';
SELECT 
    y.YardId,
    y.YardNumber,
    y.PortId,
    y.ImagePath,
    CASE 
        WHEN y.ImagePath = 'Y4.png' THEN '✅ SUCCESS'
        ELSE '❌ FAILED'
    END AS Status
FROM Yards y
WHERE y.PortId = 2
ORDER BY y.YardNumber;
PRINT '';

-- Step 4: Show Port 2 details with Port Name
PRINT 'COMPLETE PORT 2 DETAILS:';
SELECT 
    p.PortId,
    p.PortName,
    p.PortDesc,
    y.YardId,
    y.YardNumber,
    y.ImagePath,
    y.YardWidth,
    y.YardHeight
FROM Ports p
INNER JOIN Yards y ON p.PortId = y.PortId
WHERE p.PortId = 2
ORDER BY y.YardNumber;
PRINT '';

-- Step 5: Count verification
PRINT 'SUMMARY:';
SELECT 
    COUNT(*) AS TotalYardsInPort2,
    SUM(CASE WHEN ImagePath = 'Y4.png' THEN 1 ELSE 0 END) AS YardsWithY4,
    SUM(CASE WHEN ImagePath IS NULL OR ImagePath = '' THEN 1 ELSE 0 END) AS YardsWithoutImage,
    SUM(CASE WHEN ImagePath != 'Y4.png' AND ImagePath IS NOT NULL AND ImagePath != '' THEN 1 ELSE 0 END) AS YardsWithOtherImage
FROM Yards
WHERE PortId = 2;

PRINT '';
PRINT '============================================================================';
PRINT 'Y4.png SETUP FOR PORTID2 COMPLETE!';
PRINT '============================================================================';
PRINT '';
PRINT 'Next Steps:';
PRINT '1. Verify Y4.png exists in assets folder: container_mgmt/assets/Y4.png';
PRINT '2. Ensure pubspec.yaml includes: assets/Y4.png';
PRINT '3. Run: flutter pub get';
PRINT '4. Restart the Flutter app (hot reload will not work for assets)';
PRINT '============================================================================';
