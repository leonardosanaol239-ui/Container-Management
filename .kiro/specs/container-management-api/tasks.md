# Implementation Plan: Container Management API

## Overview

This plan implements a C# ASP.NET Core RESTful API for managing shipping containers across multiple ports. The API connects to an existing SQL Server database and provides endpoints for container operations including creation, location tracking, movement, and hierarchical location retrieval. The implementation follows a layered architecture with controllers, services, and Entity Framework Core for data access.

## Tasks

- [x] 1. Set up ASP.NET Core project structure and database connection
  - Create new ASP.NET Core Web API project in con_mgmt_api folder
  - Configure Entity Framework Core with SQL Server provider
  - Set up connection string for database at 192.168.76.119
  - Configure TrustServerCertificate and SQL authentication
  - Test database connectivity on startup
  - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7_

- [x] 2. Create Entity Framework Core models for database tables
  - [x] 2.1 Create entity models for location hierarchy
    - Create Port, Yard, Block, Bay, Row, Slot entity classes
    - Configure primary keys and relationships
    - Map to existing database tables
    - _Requirements: 1.3, 2.3, 3.3, 4.3, 5.3, 6.3_
  
  - [x] 2.2 Create Container and Status entity models
    - Create Container entity class with all fields
    - Create Status entity class
    - Configure relationships and foreign keys
    - Set up auto-increment for ContainerNumber
    - _Requirements: 7.2, 7.3, 8.4, 11.2_
  
  - [x] 2.3 Create DbContext and configure entity relationships
    - Create ApplicationDbContext class
    - Configure entity relationships using Fluent API
    - Set up navigation properties
    - _Requirements: 13.5_

- [x] 3. Implement location hierarchy retrieval endpoints
  - [x] 3.1 Create Port controller and service
    - Implement GET /api/ports endpoint
    - Implement GET /api/ports/{id} endpoint
    - Return 404 for non-existent ports
    - _Requirements: 1.1, 1.2, 1.3, 1.4_
  
  - [x] 3.2 Create Yard controller and service
    - Implement GET /api/yards?portId={portId} endpoint
    - Implement GET /api/yards/{id} endpoint
    - Return empty collection for ports with no yards
    - Return 404 for non-existent yards
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
  
  - [x] 3.3 Create Block controller and service
    - Implement GET /api/blocks?yardId={yardId} endpoint
    - Implement GET /api/blocks/{id} endpoint
    - Return empty collection for yards with no blocks
    - Return 404 for non-existent blocks
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  
  - [x] 3.4 Create Bay controller and service
    - Implement GET /api/bays?blockId={blockId} endpoint
    - Implement GET /api/bays/{id} endpoint
    - Return empty collection for blocks with no bays
    - Return 404 for non-existent bays
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  
  - [x] 3.5 Create Row controller and service
    - Implement GET /api/rows?bayId={bayId} endpoint
    - Implement GET /api/rows/{id} endpoint
    - Return empty collection for bays with no rows
    - Return 404 for non-existent rows
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  
  - [x] 3.6 Create Slot controller and service
    - Implement GET /api/slots?rowId={rowId} endpoint
    - Implement GET /api/slots/{id} endpoint
    - Include container count and tier occupancy in response
    - Return empty collection for rows with no slots
    - Return 404 for non-existent slots
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

- [ ] 4. Checkpoint - Ensure location hierarchy endpoints work
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement Status retrieval endpoint
  - Create Status controller and service
  - Implement GET /api/statuses endpoint
  - Return all status records (Laden and Empty)
  - _Requirements: 11.1, 11.2, 11.3_

- [x] 6. Implement Container creation endpoint
  - [x] 6.1 Create Container controller and service for creation
    - Implement POST /api/containers endpoint
    - Auto-generate ContainerNumber in CON-X format
    - Validate required fields (StatusId, Type, CurrentPortId)
    - Set location fields to null (Holding Area state)
    - Set CreatedDate to current timestamp
    - Return 201 with created container data
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_
  
  - [x] 6.2 Add validation for Container creation
    - Validate CurrentPortId exists in database
    - Validate StatusId exists in database
    - Return 400 for missing required fields
    - Return 400 for invalid foreign keys
    - _Requirements: 7.8, 7.9, 7.10, 14.6, 14.7_

- [x] 7. Implement Container retrieval endpoints
  - [x] 7.1 Add Container retrieval methods to service
    - Implement GET /api/containers?portId={portId} endpoint
    - Implement GET /api/containers/{id} endpoint
    - Implement GET /api/containers/search?containerNumber={number} endpoint
    - Return all container fields in response
    - Return 404 for non-existent containers
    - Return empty collection for ports with no containers
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

- [x] 8. Implement Container location hierarchy retrieval
  - Create endpoint GET /api/containers/{id}/location-hierarchy
  - Query and join Port, Yard, Block, Bay, Row, Slot tables
  - Return full hierarchy for containers in slots
  - Return only Port info for containers in Holding Area
  - Return 404 for non-existent containers
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [x] 9. Implement Container location update endpoint
  - [x] 9.1 Create location update service method
    - Implement PUT /api/containers/{id}/location endpoint
    - Accept YardId, BlockId, BayId, RowId, Tier in request body
    - Support null values for Holding Area moves
    - Return 200 with updated container data
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.9_
  
  - [x] 9.2 Add FILO stacking validation
    - Validate Tier is between 1 and 5
    - Validate target slot exists
    - Validate target tier position is not occupied
    - Validate lower tiers (1 through Tier-1) are occupied
    - Return 400 for FILO violations
    - Return 409 for occupied tier positions
    - Return 400 for invalid tier values
    - Return 400 for non-existent location fields
    - _Requirements: 10.5, 10.6, 10.7, 10.8, 10.10, 10.11, 10.12, 10.13, 14.8_

- [ ] 10. Checkpoint - Ensure container operations work correctly
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Configure CORS for Flutter client
  - Add CORS middleware to Program.cs
  - Configure allowed origins for Flutter client
  - Allow GET, POST, PUT, DELETE methods
  - Allow standard headers
  - _Requirements: 12.1, 12.2, 12.3, 12.4_

- [x] 12. Implement global error handling and validation
  - [x] 12.1 Create global exception handler middleware
    - Return 400 for validation errors with details
    - Return 404 for not found errors with message
    - Return 409 for conflict errors with message
    - Return 500 for unexpected errors with generic message
    - Log full error details for debugging
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_
  
  - [x] 12.2 Add model validation attributes
    - Add Required attributes to entity properties
    - Add Range attributes for Tier validation
    - Add validation for foreign key references
    - _Requirements: 14.6, 14.7_

- [x] 13. Configure RESTful conventions and JSON serialization
  - Configure JSON serialization options
  - Set up camelCase property naming
  - Configure HTTP status code responses
  - Ensure plural nouns for collection endpoints
  - Ensure resource IDs in URL paths
  - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7, 15.8, 15.9_

- [ ] 14. Final checkpoint - Test all endpoints and error scenarios
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- All endpoints follow RESTful conventions with appropriate HTTP methods and status codes
- Entity Framework Core handles database operations with proper relationship mapping
- FILO stacking validation ensures containers can only be placed/removed according to tier rules
- Global error handling provides consistent error responses across all endpoints
- CORS configuration enables Flutter client communication
- Connection string uses TrustServerCertificate for SQL Server authentication
