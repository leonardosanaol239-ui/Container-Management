-- ── LocationStatus table ─────────────────────────────────────────────────────
CREATE TABLE LocationStatus (
    LocationStatusId INT PRIMARY KEY IDENTITY(1,1),
    LocationStatusDesc NVARCHAR(50) NOT NULL
);

INSERT INTO LocationStatus (LocationStatusDesc) VALUES ('In Yard'), ('Moved Out');

-- ── Trucks table ─────────────────────────────────────────────────────────────
CREATE TABLE Trucks (
    TruckId INT PRIMARY KEY IDENTITY(1,1),
    TruckName NVARCHAR(50) NOT NULL
);

INSERT INTO Trucks (TruckName) VALUES ('Truck 1'), ('Truck 2'), ('Truck 3');

-- ── Add new columns to Containers ────────────────────────────────────────────
ALTER TABLE Containers ADD LocationStatusId INT NULL;
ALTER TABLE Containers ADD TruckId INT NULL;
ALTER TABLE Containers ADD BoundTo NVARCHAR(255) NULL;

-- Set all existing containers to LocationStatusId = 1 (In Yard) where they have a yard
UPDATE Containers SET LocationStatusId = 1 WHERE YardId IS NOT NULL;

-- FK constraints
ALTER TABLE Containers ADD CONSTRAINT FK_Containers_LocationStatus
    FOREIGN KEY (LocationStatusId) REFERENCES LocationStatus(LocationStatusId);

ALTER TABLE Containers ADD CONSTRAINT FK_Containers_Trucks
    FOREIGN KEY (TruckId) REFERENCES Trucks(TruckId);
