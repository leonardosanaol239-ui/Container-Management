# Requirements Document

## Introduction

The Container Management System API is a RESTful backend service built with C# ASP.NET Core that manages shipping container locations across multiple ports. The system tracks containers through a hierarchical structure (Ports → Yards → Blocks → Bays → Rows → Slots) with support for 5-tier stacking (FILO) in each slot. The API connects to an existing SQL Server database and provides endpoints for a Flutter frontend application to manage container operations, including creation, location tracking, movement, and search functionality.

## Glossary

- **API**: The Container Management System RESTful Web API backend
- **Database**: SQL Server database (ojt_2026_01_1) at 192.168.76.119
- **Container**: A shipping container tracked in the system with a unique identifier (CON-X format)
- **Port**: A shipping port facility that contains one or more yards
- **Yard**: A storage area within a port that contains blocks
- **Block**: A section within a yard that contains bays
- **Bay**: A subdivision of a block that contains rows
- **Row**: A line of slots within a bay
- **Slot**: A physical storage location that can hold up to 5 containers in tiers
- **Tier**: A vertical stacking position within a slot (1-5, where 1 is bottom and 5 is top)
- **Holding_Area**: A temporary storage state where containers are at a port but not assigned to a slot
- **FILO**: First-In-Last-Out stacking rule where only the top tier container can be removed
- **Status**: Container load status (Laden or Empty)
- **Location_Hierarchy**: The complete path from Port to Slot for a container's location
- **Flutter_Client**: The frontend application that consumes the API

## Requirements

### Requirement 1: Port Information Retrieval

**User Story:** As a system user, I want to retrieve port information, so that I can view available ports and their details.

#### Acceptance Criteria

1. THE API SHALL provide an endpoint to retrieve all ports from the Database
2. THE API SHALL provide an endpoint to retrieve a single port by PortId
3. WHEN a port retrieval request is made, THE API SHALL return port data including PortId and PortDesc
4. IF a requested PortId does not exist, THEN THE API SHALL return an HTTP 404 status code with an error message

### Requirement 2: Yard Information Retrieval

**User Story:** As a system user, I want to retrieve yard information, so that I can view yards associated with specific ports.

#### Acceptance Criteria

1. THE API SHALL provide an endpoint to retrieve all yards for a given PortId
2. THE API SHALL provide an endpoint to retrieve a single yard by YardId
3. WHEN a yard retrieval request is made, THE API SHALL return yard data including YardId, YardNumber, and PortId
4. IF a requested YardId does not exist, THEN THE API SHALL return an HTTP 404 status code with an error message
5. IF a requested PortId has no yards, THEN THE API SHALL return an empty collection

### Requirement 3: Block Information Retrieval

**User Story:** As a system user, I want to retrieve block information, so that I can view blocks within specific yards.

#### Acceptance Criteria

1. THE API SHALL provide an endpoint to retrieve all blocks for a given YardId
2. THE API SHALL provide an endpoint to retrieve a single block by BlockId
3. WHEN a block retrieval request is made, THE API SHALL return block data including BlockId, BlockNumber, BlockDesc, YardId, and PortId
4. IF a requested BlockId does not exist, THEN THE API SHALL return an HTTP 404 status code with an error message
5. IF a requested YardId has no blocks, THEN THE API SHALL return an empty collection

### Requirement 4: Bay Information Retrieval

**User Story:** As a system user, I want to retrieve bay information, so that I can view bays within specific blocks.

#### Acceptance Criteria

1. THE API SHALL provide an endpoint to retrieve all bays for a given BlockId
2. THE API SHALL provide an endpoint to retrieve a single bay by BayId
3. WHEN a bay retrieval request is made, THE API SHALL return bay data including BayId, BayNumber, and BlockId
4. IF a requested BayId does not exist, THEN THE API SHALL return an HTTP 404 status code with an error message
5. IF a requested BlockId has no bays, THEN THE API SHALL return an empty collection

### Requirement 5: Row Information Retrieval

**User Story:** As a system user, I want to retrieve row information, so that I can view rows within specific bays.

#### Acceptance Criteria

1. THE API SHALL provide an endpoint to retrieve all rows for a given BayId
2. THE API SHALL provide an endpoint to retrieve a single row by RowId
3. WHEN a row retrieval request is made, THE API SHALL return row data including RowId, RowNumber, and BayId
4. IF a requested RowId does not exist, THEN THE API SHALL return an HTTP 404 status code with an error message
5. IF a requested BayId has no rows, THEN THE API SHALL return an empty collection

### Requirement 6: Slot Information Retrieval

**User Story:** As a system user, I want to retrieve slot information with tier occupancy details, so that I can view available storage locations and their current capacity.

#### Acceptance Criteria

1. THE API SHALL provide an endpoint to retrieve all slots for a given RowId
2. THE API SHALL provide an endpoint to retrieve a single slot by SlotId
3. WHEN a slot retrieval request is made, THE API SHALL return slot data including SlotId, RowId, SlotNumber, and MaxTier
4. WHEN a slot retrieval request is made, THE API SHALL include the count of containers currently in the slot
5. WHEN a slot retrieval request is made, THE API SHALL include which tier positions are occupied
6. IF a requested SlotId does not exist, THEN THE API SHALL return an HTTP 404 status code with an error message
7. IF a requested RowId has no slots, THEN THE API SHALL return an empty collection

### Requirement 7: Container Creation

**User Story:** As a system user, I want to create new containers, so that I can register containers arriving at a port.

#### Acceptance Criteria

1. THE API SHALL provide an endpoint to create a new Container
2. WHEN a container creation request is received, THE API SHALL auto-generate a ContainerNumber in the format CON-X where X is an incrementing integer
3. WHEN a container creation request is received, THE API SHALL require StatusId, Type, and CurrentPortId
4. WHEN a container creation request is received, THE API SHALL accept optional ContainerDesc
5. WHEN a container is created, THE API SHALL set YardId, BlockId, BayId, RowId, and Tier to null (Holding_Area state)
6. WHEN a container is created, THE API SHALL set CreatedDate to the current timestamp
7. WHEN a container is created successfully, THE API SHALL return HTTP 201 status code with the created container data
8. IF required fields are missing in a creation request, THEN THE API SHALL return HTTP 400 status code with validation error details
9. IF the CurrentPortId does not exist in the Database, THEN THE API SHALL return HTTP 400 status code with an error message
10. IF the StatusId does not exist in the Database, THEN THE API SHALL return HTTP 400 status code with an error message

### Requirement 8: Container Retrieval

**User Story:** As a system user, I want to retrieve container information, so that I can view container details and locations.

#### Acceptance Criteria

1. THE API SHALL provide an endpoint to retrieve all containers for a given CurrentPortId
2. THE API SHALL provide an endpoint to retrieve a single container by ContainerId
3. THE API SHALL provide an endpoint to search for a container by ContainerNumber
4. WHEN a container retrieval request is made, THE API SHALL return all container fields including ContainerId, ContainerNumber, StatusId, Type, ContainerDesc, CurrentPortId, YardId, BlockId, BayId, RowId, Tier, and CreatedDate
5. IF a requested ContainerId does not exist, THEN THE API SHALL return an HTTP 404 status code with an error message
6. IF a requested ContainerNumber does not exist, THEN THE API SHALL return an HTTP 404 status code with an error message
7. IF a requested CurrentPortId has no containers, THEN THE API SHALL return an empty collection

### Requirement 9: Container Location Hierarchy Retrieval

**User Story:** As a system user, I want to retrieve the complete location hierarchy for a container, so that I can display the full path from port to slot.

#### Acceptance Criteria

1. THE API SHALL provide an endpoint to retrieve the Location_Hierarchy for a given ContainerId
2. WHEN a location hierarchy request is made for a container in a slot, THE API SHALL return Port, Yard, Block, Bay, Row, Slot, and Tier information
3. WHEN a location hierarchy request is made for a container in the Holding_Area, THE API SHALL return only Port information
4. IF a requested ContainerId does not exist, THEN THE API SHALL return an HTTP 404 status code with an error message

### Requirement 10: Container Location Update

**User Story:** As a system user, I want to move containers to different slots with tier assignments, so that I can manage container placement in the yard.

#### Acceptance Criteria

1. THE API SHALL provide an endpoint to update a Container location
2. WHEN a location update request is received, THE API SHALL accept YardId, BlockId, BayId, RowId, and Tier
3. WHEN a location update request assigns a container to a slot, THE API SHALL require all location fields (YardId, BlockId, BayId, RowId, Tier) to be provided
4. WHEN a location update request moves a container to the Holding_Area, THE API SHALL accept null values for YardId, BlockId, BayId, RowId, and Tier
5. WHEN a location update request is received, THE API SHALL validate that the Tier value is between 1 and 5
6. WHEN a location update request is received, THE API SHALL validate that the target slot exists in the Database
7. WHEN a location update request is received, THE API SHALL validate that the target tier position in the slot is not already occupied
8. WHEN a location update request is received, THE API SHALL validate that lower tier positions (1 through Tier-1) are occupied (FILO rule)
9. WHEN a location update is successful, THE API SHALL return HTTP 200 status code with the updated container data
10. IF a location update request violates the FILO stacking rule, THEN THE API SHALL return HTTP 400 status code with an error message
11. IF a location update request specifies a tier position that is already occupied, THEN THE API SHALL return HTTP 409 status code with an error message
12. IF a location update request specifies an invalid Tier value, THEN THE API SHALL return HTTP 400 status code with an error message
13. IF a location update request specifies location fields that do not exist in the Database, THEN THE API SHALL return HTTP 400 status code with an error message

### Requirement 11: Status Information Retrieval

**User Story:** As a system user, I want to retrieve available container statuses, so that I can select valid status values when creating or updating containers.

#### Acceptance Criteria

1. THE API SHALL provide an endpoint to retrieve all statuses from the Database
2. WHEN a status retrieval request is made, THE API SHALL return status data including StatusId and StatusDesc
3. THE API SHALL return statuses for both Laden and Empty container states

### Requirement 12: CORS Configuration

**User Story:** As a Flutter frontend developer, I want the API to support cross-origin requests, so that the Flutter_Client can communicate with the API.

#### Acceptance Criteria

1. THE API SHALL enable CORS (Cross-Origin Resource Sharing) for all endpoints
2. THE API SHALL accept requests from the Flutter_Client origin
3. THE API SHALL support HTTP methods GET, POST, PUT, and DELETE for CORS requests
4. THE API SHALL allow standard HTTP headers in CORS requests

### Requirement 13: Database Connection

**User Story:** As a system administrator, I want the API to connect to the existing SQL Server database, so that container data is persisted and retrieved correctly.

#### Acceptance Criteria

1. THE API SHALL connect to the Database at server address 192.168.76.119
2. THE API SHALL use database name ojt_2026_01_1
3. THE API SHALL authenticate using SQL Server authentication with User Id jasper and Password Default@123
4. THE API SHALL enable TrustServerCertificate in the connection string
5. THE API SHALL use Entity Framework Core for database access
6. WHEN the API starts, THE API SHALL verify database connectivity
7. IF database connection fails at startup, THEN THE API SHALL log the error and fail to start

### Requirement 14: Error Handling and Validation

**User Story:** As a system user, I want clear error messages when requests fail, so that I can understand and correct issues.

#### Acceptance Criteria

1. WHEN an API request fails validation, THE API SHALL return an HTTP 400 status code with detailed validation error messages
2. WHEN an API request references a non-existent resource, THE API SHALL return an HTTP 404 status code with a descriptive error message
3. WHEN an API request creates a resource conflict, THE API SHALL return an HTTP 409 status code with a descriptive error message
4. WHEN an API encounters an unexpected error, THE API SHALL return an HTTP 500 status code with a generic error message
5. WHEN an API encounters an unexpected error, THE API SHALL log the full error details for debugging
6. THE API SHALL validate all required fields before processing requests
7. THE API SHALL validate all foreign key references before processing requests
8. THE API SHALL validate all business rules before processing requests

### Requirement 15: RESTful API Design

**User Story:** As a frontend developer, I want the API to follow REST conventions, so that endpoints are predictable and easy to use.

#### Acceptance Criteria

1. THE API SHALL use HTTP GET method for data retrieval operations
2. THE API SHALL use HTTP POST method for resource creation operations
3. THE API SHALL use HTTP PUT method for resource update operations
4. THE API SHALL return appropriate HTTP status codes for all responses
5. THE API SHALL use JSON format for request and response bodies
6. THE API SHALL use plural nouns for collection endpoints
7. THE API SHALL use resource identifiers in URL paths for single resource endpoints
8. THE API SHALL return created resource data in POST responses
9. THE API SHALL return updated resource data in PUT responses

