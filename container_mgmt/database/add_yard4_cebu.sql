-- ============================================================================
-- ADD YARD 4 TO CEBU PORT WITH Y4.PNG
-- ============================================================================
-- This script adds Yard 4 to Cebu Port (PortId = 2) and sets Y4.png as the
-- background image, ensuring functionality, consistency, and integrity
-- ============================================================================

PRINT '============================================================================';
PRINT 'ADDING YARD 4 TO CEBU PORT WITH Y4.PNG';
PRINT '============================================================================';
PRINT '';

-- ============================================================================
-- STEP 1: Verify Cebu Port exists
-- ============================================================================
PRINT 'STEP 1: Verifying Cebu Port...';
IF NOT EXISTS (SELECT 1 FROM Ports WHERE PortId = 2)
BEGIN
    PRINT '❌ ERROR: Cebu Port (PortId = 2) does not exist!';
    PRINT 'Please run the setup script first.';
    RAISERROR('Cebu Port not found', 16, 1);
    RETURN;
END

SELECT PortId, PortDesc FROM Ports WHERE PortId = 2;
PRINT '✅ Cebu Port found';
PRINT '';

-- ============================================================================
-- STEP 2: Check if Yard 4 already exists in Cebu Port
-- ============================================================================
PRINT 'STEP 2: Checking for existing Yard 4 in Cebu Port...';
IF EXISTS (SELECT 1 FROM Yards WHERE PortId = 2 AND YardNumber = 4)
BEGIN
    PRINT '⚠️ Yard 4 already exists in Cebu Port';
    PRINT 'Current state:';
    SELECT YardId, YardNumber, PortId, ImagePath 
    FROM Yards 
    WHERE PortId = 2 AND YardNumber = 4;
    PRINT '';
    PRINT 'Updating ImagePath to Y4.png...';
    UPDATE Yards 
    SET ImagePath = 'Y4.png' 
    WHERE PortId = 2 AND YardNumber = 4;
    PRINT '✅ ImagePath updated to Y4.png';
END
ELSE
BEGIN
    PRINT '➕ Yard 4 does not exist. Creating new yard...';
    
    -- Insert Yard 4 for Cebu Port with Y4.png
    INSERT INTO Yards (YardNumber, PortId, ImagePath)
    VALUES (4, 2, 'Y4.png');
    
    PRINT '✅ Yard 4 created successfully for Cebu Port';
END
PRINT '';

-- ============================================================================
-- STEP 3: Verify the creation/update
-- ============================================================================
PRINT 'STEP 3: Verification - Yard 4 in Cebu Port:';
SELECT 
    y.YardId,
    y.YardNumber,
    y.PortId,
    p.PortDesc,
    y.ImagePath,
    y.YardWidth,
    y.YardHeight,
    CASE 
        WHEN y.ImagePath = 'Y4.png' THEN '✅ SUCCESS'
        WHEN y.ImagePath IS NULL THEN '❌ NULL'
        ELSE '⚠️ Different: ' + y.ImagePath
    END AS Status
FROM Yards y
INNER JOIN Ports p ON y.PortId = p.PortId
WHERE y.PortId = 2 AND y.YardNumber = 4;
PRINT '';

-- ============================================================================
-- STEP 4: Show all yards in Cebu Port for context
-- ============================================================================
PRINT 'STEP 4: All Yards in Cebu Port:';
SELECT 
    y.YardId,
    y.YardNumber,
    y.ImagePath,
    CASE 
        WHEN y.ImagePath = 'Y4.png' THEN '✅ Y4.png'
        WHEN y.ImagePath IS NULL THEN '⚠️ No Image'
        ELSE '📷 ' + y.ImagePath
    END AS ImageStatus
FROM Yards y
WHERE y.PortId = 2
ORDER BY y.YardNumber;
PRINT '';

-- ============================================================================
-- STEP 5: Ensure consistency - Update all Cebu yards to Y4.png (optional)
-- ============================================================================
PRINT 'STEP 5: Ensuring consistency across all Cebu Port yards...';
PRINT 'Updating all Cebu Port yards to use Y4.png for consistency...';

UPDATE Yards
SET ImagePath = 'Y4.png'
WHERE PortId = 2 AND (ImagePath IS NULL OR ImagePath != 'Y4.png');

DECLARE @UpdatedCount INT = @@ROWCOUNT;
PRINT CONCAT('✅ Updated ', @UpdatedCount, ' yard(s) to Y4.png');
PRINT '';

-- ============================================================================
-- STEP 6: Final verification
-- ============================================================================
PRINT 'STEP 6: FINAL VERIFICATION - All Cebu Port Yards:';
SELECT 
    y.YardId,
    y.YardNumber,
    p.PortDesc,
    y.ImagePath,
    y.YardWidth,
    y.YardHeight,
    CASE 
        WHEN y.ImagePath = 'Y4.png' THEN '✅ CORRECT'
        ELSE '❌ INCORRECT'
    END AS ValidationStatus
FROM Yards y
INNER JOIN Ports p ON y.PortId = p.PortId
WHERE y.PortId = 2
ORDER BY y.YardNumber;
PRINT '';

-- ============================================================================
-- STEP 7: Integrity check
-- ============================================================================
PRINT 'STEP 7: INTEGRITY CHECK';
PRINT '------------------------';

-- Check for orphaned yards (yards without valid port)
DECLARE @OrphanedYards INT;
SELECT @OrphanedYards = COUNT(*)
FROM Yards y
LEFT JOIN Ports p ON y.PortId = p.PortId
WHERE p.PortId IS NULL;

IF @OrphanedYards > 0
BEGIN
    PRINT CONCAT('❌ WARNING: ', @OrphanedYards, ' orphaned yard(s) found!');
END
ELSE
BEGIN
    PRINT '✅ No orphaned yards';
END

-- Check for duplicate yard numbers in same port
DECLARE @DuplicateYards INT;
SELECT @DuplicateYards = COUNT(*)
FROM (
    SELECT PortId, YardNumber, COUNT(*) as cnt
    FROM Yards
    GROUP BY PortId, YardNumber
    HAVING COUNT(*) > 1
) AS Duplicates;

IF @DuplicateYards > 0
BEGIN
    PRINT CONCAT('❌ WARNING: ', @DuplicateYards, ' duplicate yard number(s) found!');
    SELECT PortId, YardNumber, COUNT(*) as DuplicateCount
    FROM Yards
    GROUP BY PortId, YardNumber
    HAVING COUNT(*) > 1;
END
ELSE
BEGIN
    PRINT '✅ No duplicate yard numbers';
END

-- Check Yard 4 specifically
IF EXISTS (SELECT 1 FROM Yards WHERE PortId = 2 AND YardNumber = 4 AND ImagePath = 'Y4.png')
BEGIN
    PRINT '✅ Yard 4 in Cebu Port has Y4.png - VERIFIED';
END
ELSE
BEGIN
    PRINT '❌ ERROR: Yard 4 in Cebu Port does not have Y4.png!';
END

PRINT '';

-- ============================================================================
-- SUMMARY
-- ============================================================================
PRINT '============================================================================';
PRINT 'SUMMARY';
PRINT '============================================================================';

SELECT 
    COUNT(*) AS TotalCebuYards,
    SUM(CASE WHEN ImagePath = 'Y4.png' THEN 1 ELSE 0 END) AS YardsWithY4,
    SUM(CASE WHEN YardNumber = 4 THEN 1 ELSE 0 END) AS Yard4Count,
    SUM(CASE WHEN YardNumber = 4 AND ImagePath = 'Y4.png' THEN 1 ELSE 0 END) AS Yard4WithY4
FROM Yards
WHERE PortId = 2;

PRINT '';
PRINT '============================================================================';
PRINT '✅ YARD 4 IN CEBU PORT WITH Y4.PNG - COMPLETE!';
PRINT '============================================================================';
PRINT '';
PRINT 'Next Steps:';
PRINT '1. Verify Y4.png exists: container_mgmt/assets/Y4.png ✅';
PRINT '2. Verify pubspec.yaml includes: assets/Y4.png ✅';
PRINT '3. Run: flutter pub get';
PRINT '4. Restart Flutter app (hot reload will not work for assets)';
PRINT '5. Navigate to Cebu Port > Yard 4 to see Y4.png background';
PRINT '============================================================================';
