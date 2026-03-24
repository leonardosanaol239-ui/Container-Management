-- Add SlotId column to Containers table
-- This column will reference the specific slot where the container is placed

USE ContainerManagement;
GO

-- Add SlotId column to Containers table
ALTER TABLE Containers 
ADD SlotId INT NULL;
GO

-- Add foreign key constraint
ALTER TABLE Containers
ADD CONSTRAINT FK_Containers_Slots
FOREIGN KEY (SlotId) REFERENCES Slots(SlotId);
GO

PRINT 'SlotId column added to Containers table successfully!';