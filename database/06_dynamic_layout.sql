-- ── Step 1: Lookup tables ─────────────────────────────────────────────────────

CREATE TABLE Sizes (
    SizeId   INT PRIMARY KEY IDENTITY(1,1),
    SizeDesc NVARCHAR(20) NOT NULL
);
INSERT INTO Sizes (SizeDesc) VALUES ('20ft'), ('40ft');

CREATE TABLE Orientations (
    OrientationId   INT PRIMARY KEY IDENTITY(1,1),
    OrientationDesc NVARCHAR(20) NOT NULL
);
INSERT INTO Orientations (OrientationDesc) VALUES ('Horizontal'), ('Vertical');

-- ── Step 2: Yard dimensions ───────────────────────────────────────────────────

ALTER TABLE Yards
    ADD YardWidth  FLOAT NULL,
        YardHeight FLOAT NULL;
GO

-- Manila Yard 1 & 2 = 300 x 170 ft
UPDATE Yards SET YardWidth = 300, YardHeight = 170
WHERE YardId IN (
    SELECT y.YardId FROM Yards y
    JOIN Ports p ON y.PortId = p.PortId
    WHERE p.PortDesc LIKE '%Manila%'
    AND y.YardNumber IN (1, 2)
);

-- ── Step 3: Blocks — add layout columns ──────────────────────────────────────

ALTER TABLE Blocks
    ADD BlockName     NVARCHAR(100) NULL,
        OrientationId INT NULL REFERENCES Orientations(OrientationId),
        SizeId        INT NULL REFERENCES Sizes(SizeId),
        PosX          FLOAT NULL DEFAULT 0,
        PosY          FLOAT NULL DEFAULT 0;

-- ── Step 4: Rows — add layout columns ────────────────────────────────────────
-- Rows represent individual slots; add size, orientation, max stack, deleted flag

ALTER TABLE Rows
    ADD SizeId        INT NULL REFERENCES Sizes(SizeId),
        OrientationId INT NULL REFERENCES Orientations(OrientationId),
        MaxStack      INT NULL DEFAULT 5,
        IsDeleted     BIT NOT NULL DEFAULT 0;

-- ── Step 5: Containers — Type becomes SizeId reference ───────────────────────
-- Type column stays as NVARCHAR for now (backward compat),
-- add SizeId as the new typed reference

ALTER TABLE Containers
    ADD ContainerSizeId INT NULL REFERENCES Sizes(SizeId);

-- ── Step 6: Verify ────────────────────────────────────────────────────────────

SELECT 'Sizes' AS [Table], COUNT(*) AS Rows FROM Sizes
UNION ALL
SELECT 'Orientations', COUNT(*) FROM Orientations
UNION ALL
SELECT 'Yards with dimensions', COUNT(*) FROM Yards WHERE YardWidth IS NOT NULL;

SELECT y.YardId, y.YardNumber, y.YardWidth, y.YardHeight, p.PortDesc
FROM Yards y
JOIN Ports p ON y.PortId = p.PortId
ORDER BY p.PortDesc, y.YardNumber;
