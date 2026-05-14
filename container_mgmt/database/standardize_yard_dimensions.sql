-- ============================================================================
-- Standardize ALL yard dimensions to 550 x 238 ft (Manila Yard 1 standard)
-- This ensures consistent cell/block sizes across all ports and yards.
-- ============================================================================

UPDATE Yards
SET YardWidth  = 550,
    YardHeight = 238;

-- Verify
SELECT YardId, YardNumber, PortId, YardWidth, YardHeight, ImagePath
FROM Yards
ORDER BY PortId, YardNumber;
