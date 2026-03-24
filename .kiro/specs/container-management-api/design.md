# Design Document: Container Management API

## Overview

The Container Management API is a RESTful web service built with ASP.NET Core 8.0 that provides backend functionality for managing shipping containers across multiple port facilities. The API implements a clean architecture pattern with clear separation between presentation (controllers), business logic (services), and data access (repositories) layers.

The system manages a hierarchical location structure (Ports → Yards → Blocks → Bays → Rows → Slots) where containers can be stored in slots with up to 5 vertical tiers following FILO (First-In-Last-Out) stacking rules. Containers can also exist in a "holding area" state where they are at a port but not yet assigned to a specific slot.

The API connects to an existing SQL Server database and exposes JSON-based REST endpoints for a Flutter frontend client. All endpoints follow REST conventions with appropriate HTTP verbs, status codes, and resource-oriented URL structures.

## Architecture

### Architectural Pattern

The API follows a layered clean architecture approach:

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│  (Controllers, DTOs, Middleware)        │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         Business Logic Layer            │
│     (Services, Validation Logic)        │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         Data Access Layer               │
│  (Repositories, EF Core, DbContext)     │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         SQL Server Database             │
│         (ojt_2026_01_1)                 │
└─────────────────────────────────────────┘
```

### Technology Stack

- **Framework**: ASP.NET Core 8.0 Web API
- **ORM**: Entity Framework Core 8.0
- **Database**: SQL Server (192.168.76.119)
- **Serialization**: System.Text.Json
- **Dependency Injection**: Built-in ASP.NET Core DI container
- **Logging**: ILogger with console provider

### Project Structure

```
ContainerManagementApi/
├── Controllers/          # API endpoints
├── Services/            # Business logic
├── Repositories/        # Data access
├── Models/              # Entity models
├── DTOs/                # Data transfer objects
├── Middleware/          # Error handling middleware
├── Data/                # DbContext
├── Validators/          # Business rule validators
└── Program.cs           # Application entry point
```

## Components and Interfaces

### Controllers

Controllers handle HTTP requests, delegate to services, and return appropriate responses. All controllers inherit from `ControllerBase` and use attribute routing.

#### PortsController
- **Route**: `/api/ports`
- **Endpoints**:
  - `GET /api/ports` - Get all ports
  - `GET /api/ports/{id}` - Get port by ID
- **Dependencies**: `IPortService`

#### YardsController
- **Route**: `/api/yards`
- **Endpoints**:
  - `GET /api/yards/port/{portId}` - Get all yards for a port
  - `GET /api/yards/{id}` - Get yard by ID
- **Dependencies**: `IYardService`

#### BlocksController
- **Route**: `/api/blocks`
- **Endpoints**:
  - `GET /api/blocks/yard/{yardId}` - Get all blocks for a yard
  - `GET /api/blocks/{id}` - Get block by ID
- **Dependencies**: `IBlockService`

#### BaysController
- **Route**: `/api/bays`
- **Endpoints**:
  - `GET /api/bays/block/{blockId}` - Get all bays for a block
  - `GET /api/bays/{id}` - Get bay by ID
- **Dependencies**: `IBayService`

#### RowsController
- **Route**: `/api/rows`
- **Endpoints**:
  - `GET /api/rows/bay/{bayId}` - Get all rows for a bay
  - `GET /api/rows/{id}` - Get row by ID
- **Dependencies**: `IRowService`

#### SlotsController
- **Route**: `/api/slots`
- **Endpoints**:
  - `GET /api/slots/row/{rowId}` - Get all slots for a row
  - `GET /api/slots/{id}` - Get slot by ID with occupancy details
- **Dependencies**: `ISlotService`

#### ContainersController
- **Route**: `/api/containers`
- **Endpoints**:
  - `POST /api/containers` - Create new container
  - `GET /api/containers/port/{portId}` - Get all containers at a port
  - `GET /api/containers/{id}` - Get container by ID
  - `GET /api/containers/number/{containerNumber}` - Search by container number
  - `GET /api/containers/{id}/location` - Get location hierarchy
  - `PUT /api/containers/{id}/location` - Update container location
- **Dependencies**: `IContainerService`

#### StatusController
- **Route**: `/api/status`
- **Endpoints**:
  - `GET /api/status` - Get all statuses
- **Dependencies**: `IStatusService`

### Service Layer

Services contain business logic, validation, and orchestrate repository calls. All services are registered as scoped dependencies.

#### IPortService / PortService
```csharp
Task<IEnumerable<PortDto>> GetAllPortsAsync();
Task<PortDto?> GetPortByIdAsync(int portId);
```

#### IYardService / YardService
```csharp
Task<IEnumerable<YardDto>> GetYardsByPortIdAsync(int portId);
Task<YardDto?> GetYardByIdAsync(int yardId);
```

#### IBlockService / BlockService
```csharp
Task<IEnumerable<BlockDto>> GetBlocksByYardIdAsync(int yardId);
Task<BlockDto?> GetBlockByIdAsync(int blockId);
```

#### IBayService / BayService
```csharp
Task<IEnumerable<BayDto>> GetBaysByBlockIdAsync(int blockId);
Task<BayDto?> GetBayByIdAsync(int bayId);
```

#### IRowService / RowService
```csharp
Task<IEnumerable<RowDto>> GetRowsByBayIdAsync(int bayId);
Task<RowDto?> GetRowByIdAsync(int rowId);
```

#### ISlotService / SlotService
```csharp
Task<IEnumerable<SlotDto>> GetSlotsByRowIdAsync(int rowId);
Task<SlotDto?> GetSlotByIdAsync(int slotId);
```

#### IContainerService / ContainerService
```csharp
Task<ContainerDto> CreateContainerAsync(CreateContainerDto dto);
Task<IEnumerable<ContainerDto>> GetContainersByPortIdAsync(int portId);
Task<ContainerDto?> GetContainerByIdAsync(int containerId);
Task<ContainerDto?> GetContainerByNumberAsync(string containerNumber);
Task<LocationHierarchyDto?> GetContainerLocationAsync(int containerId);
Task<ContainerDto> UpdateContainerLocationAsync(int containerId, UpdateLocationDto dto);
```

#### IStatusService / StatusService
```csharp
Task<IEnumerable<StatusDto>> GetAllStatusesAsync();
```

### Repository Layer

Repositories handle data access using Entity Framework Core. All repositories are registered as scoped dependencies.

#### IPortRepository / PortRepository
```csharp
Task<IEnumerable<Port>> GetAllAsync();
Task<Port?> GetByIdAsync(int portId);
Task<bool> ExistsAsync(int portId);
```

#### IYardRepository / YardRepository
```csharp
Task<IEnumerable<Yard>> GetByPortIdAsync(int portId);
Task<Yard?> GetByIdAsync(int yardId);
Task<bool> ExistsAsync(int yardId);
```

#### IBlockRepository / BlockRepository
```csharp
Task<IEnumerable<Block>> GetByYardIdAsync(int yardId);
Task<Block?> GetByIdAsync(int blockId);
Task<bool> ExistsAsync(int blockId);
```

#### IBayRepository / BayRepository
```csharp
Task<IEnumerable<Bay>> GetByBlockIdAsync(int blockId);
Task<Bay?> GetByIdAsync(int bayId);
Task<bool> ExistsAsync(int bayId);
```

#### IRowRepository / RowRepository
```csharp
Task<IEnumerable<Row>> GetByBayIdAsync(int bayId);
Task<Row?> GetByIdAsync(int rowId);
Task<bool> ExistsAsync(int rowId);
```

#### ISlotRepository / SlotRepository
```csharp
Task<IEnumerable<Slot>> GetByRowIdAsync(int rowId);
Task<Slot?> GetByIdAsync(int slotId);
Task<bool> ExistsAsync(int rowId, int? tier);
Task<int> GetContainerCountAsync(int slotId);
Task<List<int>> GetOccupiedTiersAsync(int slotId);
```

#### IContainerRepository / ContainerRepository
```csharp
Task<Container> CreateAsync(Container container);
Task<IEnumerable<Container>> GetByPortIdAsync(int portId);
Task<Container?> GetByIdAsync(int containerId);
Task<Container?> GetByNumberAsync(string containerNumber);
Task<string> GenerateNextContainerNumberAsync();
Task<Container> UpdateAsync(Container container);
Task<bool> IsTierOccupiedAsync(int rowId, int tier);
Task<List<int>> GetOccupiedTiersInSlotAsync(int rowId);
```

#### IStatusRepository / StatusRepository
```csharp
Task<IEnumerable<Status>> GetAllAsync();
Task<bool> ExistsAsync(int statusId);
```

### Validators

Validators contain business rule validation logic.

#### LocationValidator
```csharp
Task<ValidationResult> ValidateLocationUpdateAsync(UpdateLocationDto dto);
```

Validation rules:
- If assigning to slot: all location fields (YardId, BlockId, BayId, RowId, Tier) must be provided
- If moving to holding area: all location fields must be null
- Tier must be between 1 and 5
- Target slot must exist
- Target tier must not be occupied
- Lower tiers (1 through Tier-1) must be occupied (FILO rule)

## Data Models

### Entity Models

Entity models map directly to database tables using Entity Framework Core conventions.

#### Port
```csharp
public class Port
{
    public int PortId { get; set; }
    public string PortDesc { get; set; } = string.Empty;
    
    // Navigation properties
    public ICollection<Yard> Yards { get; set; } = new List<Yard>();
    public ICollection<Container> Containers { get; set; } = new List<Container>();
}
```

#### Yard
```csharp
public class Yard
{
    public int YardId { get; set; }
    public int YardNumber { get; set; }
    public int PortId { get; set; }
    
    // Navigation properties
    public Port Port { get; set; } = null!;
    public ICollection<Block> Blocks { get; set; } = new List<Block>();
}
```

#### Block
```csharp
public class Block
{
    public int BlockId { get; set; }
    public int BlockNumber { get; set; }
    public string? BlockDesc { get; set; }
    public int YardId { get; set; }
    public int PortId { get; set; }
    
    // Navigation properties
    public Yard Yard { get; set; } = null!;
    public Port Port { get; set; } = null!;
    public ICollection<Bay> Bays { get; set; } = new List<Bay>();
}
```

#### Bay
```csharp
public class Bay
{
    public int BayId { get; set; }
    public string BayNumber { get; set; } = string.Empty;
    public int BlockId { get; set; }
    
    // Navigation properties
    public Block Block { get; set; } = null!;
    public ICollection<Row> Rows { get; set; } = new List<Row>();
}
```

#### Row
```csharp
public class Row
{
    public int RowId { get; set; }
    public int RowNumber { get; set; }
    public int BayId { get; set; }
    
    // Navigation properties
    public Bay Bay { get; set; } = null!;
    public ICollection<Slot> Slots { get; set; } = new List<Slot>();
}
```

#### Slot
```csharp
public class Slot
{
    public int SlotId { get; set; }
    public int RowId { get; set; }
    public int SlotNumber { get; set; }
    public int MaxTier { get; set; } = 5;
    
    // Navigation properties
    public Row Row { get; set; } = null!;
}
```

#### Container
```csharp
public class Container
{
    public int ContainerId { get; set; }
    public string ContainerNumber { get; set; } = string.Empty;
    public int StatusId { get; set; }
    public string Type { get; set; } = string.Empty;
    public string? ContainerDesc { get; set; }
    public int CurrentPortId { get; set; }
    public int? YardId { get; set; }
    public int? BlockId { get; set; }
    public int? BayId { get; set; }
    public int? RowId { get; set; }
    public int? Tier { get; set; }
    public DateTime CreatedDate { get; set; }
    
    // Navigation properties
    public Status Status { get; set; } = null!;
    public Port CurrentPort { get; set; } = null!;
    public Yard? Yard { get; set; }
    public Block? Block { get; set; }
    public Bay? Bay { get; set; }
    public Row? Row { get; set; }
}
```

#### Status
```csharp
public class Status
{
    public int StatusId { get; set; }
    public string StatusDesc { get; set; } = string.Empty;
    
    // Navigation properties
    public ICollection<Container> Containers { get; set; } = new List<Container>();
}
```

### DTOs (Data Transfer Objects)

DTOs define the shape of request and response data.

#### PortDto
```csharp
public class PortDto
{
    public int PortId { get; set; }
    public string PortDesc { get; set; } = string.Empty;
}
```

#### YardDto
```csharp
public class YardDto
{
    public int YardId { get; set; }
    public int YardNumber { get; set; }
    public int PortId { get; set; }
}
```

#### BlockDto
```csharp
public class BlockDto
{
    public int BlockId { get; set; }
    public int BlockNumber { get; set; }
    public string? BlockDesc { get; set; }
    public int YardId { get; set; }
    public int PortId { get; set; }
}
```

#### BayDto
```csharp
public class BayDto
{
    public int BayId { get; set; }
    public string BayNumber { get; set; } = string.Empty;
    public int BlockId { get; set; }
}
```

#### RowDto
```csharp
public class RowDto
{
    public int RowId { get; set; }
    public int RowNumber { get; set; }
    public int BayId { get; set; }
}
```

#### SlotDto
```csharp
public class SlotDto
{
    public int SlotId { get; set; }
    public int RowId { get; set; }
    public int SlotNumber { get; set; }
    public int MaxTier { get; set; }
    public int ContainerCount { get; set; }
    public List<int> OccupiedTiers { get; set; } = new();
}
```

#### ContainerDto
```csharp
public class ContainerDto
{
    public int ContainerId { get; set; }
    public string ContainerNumber { get; set; } = string.Empty;
    public int StatusId { get; set; }
    public string Type { get; set; } = string.Empty;
    public string? ContainerDesc { get; set; }
    public int CurrentPortId { get; set; }
    public int? YardId { get; set; }
    public int? BlockId { get; set; }
    public int? BayId { get; set; }
    public int? RowId { get; set; }
    public int? Tier { get; set; }
    public DateTime CreatedDate { get; set; }
}
```

#### CreateContainerDto
```csharp
public class CreateContainerDto
{
    [Required]
    public int StatusId { get; set; }
    
    [Required]
    public string Type { get; set; } = string.Empty;
    
    public string? ContainerDesc { get; set; }
    
    [Required]
    public int CurrentPortId { get; set; }
}
```

#### UpdateLocationDto
```csharp
public class UpdateLocationDto
{
    public int? YardId { get; set; }
    public int? BlockId { get; set; }
    public int? BayId { get; set; }
    public int? RowId { get; set; }
    public int? Tier { get; set; }
}
```

#### LocationHierarchyDto
```csharp
public class LocationHierarchyDto
{
    public int ContainerId { get; set; }
    public string ContainerNumber { get; set; } = string.Empty;
    public PortDto Port { get; set; } = null!;
    public YardDto? Yard { get; set; }
    public BlockDto? Block { get; set; }
    public BayDto? Bay { get; set; }
    public RowDto? Row { get; set; }
    public SlotDto? Slot { get; set; }
    public int? Tier { get; set; }
    public bool IsInHoldingArea { get; set; }
}
```

#### StatusDto
```csharp
public class StatusDto
{
    public int StatusId { get; set; }
    public string StatusDesc { get; set; } = string.Empty;
}
```

### Database Context

#### ContainerManagementDbContext
```csharp
public class ContainerManagementDbContext : DbContext
{
    public DbSet<Port> Ports { get; set; }
    public DbSet<Yard> Yards { get; set; }
    public DbSet<Block> Blocks { get; set; }
    public DbSet<Bay> Bays { get; set; }
    public DbSet<Row> Rows { get; set; }
    public DbSet<Slot> Slots { get; set; }
    public DbSet<Container> Containers { get; set; }
    public DbSet<Status> Status { get; set; }
    
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Configure entity relationships and constraints
        // Primary keys are configured by convention (Id suffix)
        // Foreign keys are configured by convention (navigation properties)
        
        // Container unique constraint on ContainerNumber
        modelBuilder.Entity<Container>()
            .HasIndex(c => c.ContainerNumber)
            .IsUnique();
            
        // Container tier check constraint (1-5)
        modelBuilder.Entity<Container>()
            .HasCheckConstraint("CK_Container_Tier", "Tier >= 1 AND Tier <= 5");
    }
}
```

Connection string configuration in `appsettings.json`:
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=192.168.76.119;Database=ojt_2026_01_1;User Id=jasper;Password=Default@123;TrustServerCertificate=True;"
  }
}
```



## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property Reflection

After analyzing all acceptance criteria, I identified several areas of redundancy:

1. **Resource retrieval response shape**: Properties 1.3, 2.3, 3.3, 4.3, 5.3, 6.3, 8.4, 11.2 all test that responses contain required fields. These can be consolidated into a single property about DTO completeness.

2. **404 error handling**: Properties 1.4, 2.4, 3.4, 4.4, 5.4, 6.6, 8.5, 8.6, 9.4 all test 404 responses for non-existent resources. These can be consolidated into a single property about not-found error handling.

3. **Container creation validation**: Properties 7.8, 7.9, 7.10 all test validation errors returning 400 status codes. These can be consolidated into a single property about creation validation.

4. **Location update validation**: Properties 10.5, 10.6, 10.7, 10.8, 10.10, 10.12, 10.13 all test various validation rules. The FILO rule (10.8) is the most critical and comprehensive, while others are specific validation cases.

5. **HTTP method conventions**: Properties 15.1, 15.2, 15.3 test REST conventions for HTTP methods. These can be verified through endpoint definitions rather than separate properties.

6. **Response content**: Properties 7.7, 10.9, 15.8, 15.9 all test that operations return the created/updated resource. These can be consolidated.

After reflection, I'll focus on unique, high-value properties that provide distinct validation coverage.

### Property 1: Container Number Generation Format

*For any* container creation request, the generated ContainerNumber should match the format "CON-X" where X is a positive integer, and each generated number should be unique across all containers in the system.

**Validates: Requirements 7.2**

### Property 2: Holding Area Initial State

*For any* newly created container, the location fields (YardId, BlockId, BayId, RowId, Tier) should all be null, indicating the container is in the holding area state.

**Validates: Requirements 7.5**

### Property 3: Created Date Timestamp

*For any* newly created container, the CreatedDate should be set to a timestamp within a reasonable time window (e.g., 5 seconds) of the creation request.

**Validates: Requirements 7.6**

### Property 4: FILO Stacking Rule Enforcement

*For any* location update request that assigns a container to tier N (where N > 1), all lower tier positions (1 through N-1) in the same slot must be occupied, and the API should reject the request with HTTP 400 if this rule is violated.

**Validates: Requirements 10.8, 10.10**

### Property 5: Tier Occupancy Conflict Prevention

*For any* location update request, if the target tier position in the specified slot is already occupied by another container, the API should return HTTP 409 status code.

**Validates: Requirements 10.7, 10.11**

### Property 6: Tier Value Range Validation

*For any* location update request with a Tier value, the value must be between 1 and 5 (inclusive), and the API should return HTTP 400 for values outside this range.

**Validates: Requirements 10.5, 10.12**

### Property 7: Complete Location or Null Location

*For any* location update request, either all location fields (YardId, BlockId, BayId, RowId, Tier) must be provided together (assigning to slot), or all must be null (moving to holding area). Partial location updates should be rejected with HTTP 400.

**Validates: Requirements 10.3, 10.4**

### Property 8: Slot Occupancy Accuracy

*For any* slot retrieval request, the returned ContainerCount should equal the actual number of containers assigned to that slot, and the OccupiedTiers list should contain exactly the tier numbers that have containers.

**Validates: Requirements 6.4, 6.5**

### Property 9: Location Hierarchy Completeness for Slotted Containers

*For any* container that has a non-null RowId (is in a slot), the location hierarchy endpoint should return complete information for Port, Yard, Block, Bay, Row, Slot, and Tier.

**Validates: Requirements 9.2**

### Property 10: Location Hierarchy for Holding Area Containers

*For any* container that has null location fields (is in holding area), the location hierarchy endpoint should return only Port information and set IsInHoldingArea to true.

**Validates: Requirements 9.3**

### Property 11: Foreign Key Validation on Creation

*For any* container creation request with an invalid CurrentPortId or StatusId (not existing in the database), the API should return HTTP 400 status code with a validation error message.

**Validates: Requirements 7.9, 7.10**

### Property 12: Foreign Key Validation on Location Update

*For any* location update request with location field values (YardId, BlockId, BayId, RowId) that do not exist in the database, the API should return HTTP 400 status code with a validation error message.

**Validates: Requirements 10.6, 10.13**

### Property 13: Required Fields Validation

*For any* container creation request missing required fields (StatusId, Type, or CurrentPortId), the API should return HTTP 400 status code with detailed validation error messages.

**Validates: Requirements 7.3, 7.8**

### Property 14: Optional Field Acceptance

*For any* container creation request, the ContainerDesc field should be optional - containers should be created successfully both with and without this field provided.

**Validates: Requirements 7.4**

### Property 15: Resource Not Found Error Handling

*For any* GET request to retrieve a specific resource by ID (Port, Yard, Block, Bay, Row, Slot, Container) where the ID does not exist, the API should return HTTP 404 status code with a descriptive error message.

**Validates: Requirements 1.4, 2.4, 3.4, 4.4, 5.4, 6.6, 8.5, 8.6, 9.4**

### Property 16: Validation Error Response Format

*For any* request that fails validation, the API should return HTTP 400 status code with a response body containing detailed validation error messages.

**Validates: Requirements 14.1**

### Property 17: Conflict Error Response Format

*For any* request that creates a resource conflict (such as tier occupancy), the API should return HTTP 409 status code with a descriptive error message.

**Validates: Requirements 14.3**

### Property 18: Unexpected Error Handling

*For any* request that triggers an unexpected server error, the API should return HTTP 500 status code with a generic error message (not exposing internal details) and log the full error details.

**Validates: Requirements 14.4, 14.5**

### Property 19: JSON Content Type

*For any* API request and response, the content type should be application/json, ensuring consistent JSON serialization for all data exchange.

**Validates: Requirements 15.5**

### Property 20: Created Resource in Response

*For any* successful POST request (container creation), the API should return HTTP 201 status code with the complete created resource data in the response body.

**Validates: Requirements 7.7, 15.8**

### Property 21: Updated Resource in Response

*For any* successful PUT request (location update), the API should return HTTP 200 status code with the complete updated resource data in the response body.

**Validates: Requirements 10.9, 15.9**

## Error Handling

### Error Handling Middleware

The API implements a global exception handling middleware that catches all unhandled exceptions and returns appropriate HTTP responses:

```csharp
public class GlobalExceptionHandlerMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionHandlerMiddleware> _logger;
    
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (ValidationException ex)
        {
            await HandleValidationExceptionAsync(context, ex);
        }
        catch (NotFoundException ex)
        {
            await HandleNotFoundExceptionAsync(context, ex);
        }
        catch (ConflictException ex)
        {
            await HandleConflictExceptionAsync(context, ex);
        }
        catch (Exception ex)
        {
            await HandleUnexpectedExceptionAsync(context, ex);
        }
    }
}
```

### Error Response Format

All error responses follow a consistent format:

```json
{
  "statusCode": 400,
  "message": "Validation failed",
  "errors": [
    "StatusId is required",
    "Type is required"
  ],
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### HTTP Status Code Usage

- **200 OK**: Successful GET or PUT request
- **201 Created**: Successful POST request (container creation)
- **400 Bad Request**: Validation errors, business rule violations
- **404 Not Found**: Requested resource does not exist
- **409 Conflict**: Resource conflict (e.g., tier already occupied)
- **500 Internal Server Error**: Unexpected server errors

### Validation Strategy

Validation occurs at multiple levels:

1. **DTO Validation**: Data annotations on DTOs validate basic requirements (Required, Range, etc.)
2. **Service Layer Validation**: Business rules validated before database operations
3. **Database Constraints**: Foreign keys and check constraints provide final safety net

### CORS Configuration

CORS is configured in Program.cs to allow Flutter client requests:

```csharp
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});
```

## Testing Strategy

### Dual Testing Approach

The Container Management API requires both unit testing and property-based testing for comprehensive coverage:

- **Unit Tests**: Verify specific examples, edge cases, and integration points
- **Property Tests**: Verify universal properties across all inputs

### Unit Testing Focus

Unit tests should cover:

1. **Endpoint Examples**: Verify each endpoint exists and returns expected responses for specific test data
2. **Edge Cases**: Empty collections, holding area containers, maximum tier (5) scenarios
3. **Integration Points**: Database connectivity, EF Core query generation, middleware pipeline
4. **Specific Error Scenarios**: Particular validation failures, specific conflict cases

Example unit tests:
- GET /api/ports returns list of ports
- GET /api/ports/999 returns 404 for non-existent port
- POST /api/containers with valid data creates container with CON-X format
- GET /api/slots/{id} for empty slot returns ContainerCount = 0
- PUT /api/containers/{id}/location with all nulls moves to holding area

### Property-Based Testing

Property-based testing will use **fast-check** (if using TypeScript/JavaScript) or **FsCheck** (if using C#/.NET) to verify universal properties.

Each property test should:
- Run minimum 100 iterations with randomized inputs
- Reference the design document property number
- Use tag format: **Feature: container-management-api, Property {number}: {property_text}**

Example property test structure (C# with FsCheck):

```csharp
[Property]
[Tag("Feature: container-management-api, Property 1: Container Number Generation Format")]
public Property ContainerNumberFollowsFormat()
{
    return Prop.ForAll(
        Arb.Generate<CreateContainerDto>(),
        async (dto) =>
        {
            var result = await _containerService.CreateContainerAsync(dto);
            return result.ContainerNumber.StartsWith("CON-") &&
                   int.TryParse(result.ContainerNumber.Substring(4), out var num) &&
                   num > 0;
        });
}
```

### Property Test Configuration

- **Library**: FsCheck for C#/.NET
- **Iterations**: Minimum 100 per property test
- **Generators**: Custom generators for valid DTOs, existing IDs, slot configurations
- **Shrinking**: Enable to find minimal failing cases

### Test Coverage Goals

- Unit test coverage: 80%+ of service and controller code
- Property tests: One test per correctness property (21 properties)
- Integration tests: Database operations, full request/response cycles
- Edge case coverage: All identified edge cases from prework analysis

### Testing Tools

- **xUnit**: Test framework
- **FsCheck**: Property-based testing library
- **Moq**: Mocking framework for unit tests
- **FluentAssertions**: Assertion library
- **Microsoft.AspNetCore.Mvc.Testing**: Integration testing for API endpoints
- **Testcontainers**: Docker-based SQL Server for integration tests

### Continuous Testing

- All tests run on every commit
- Property tests run with full iteration count in CI/CD
- Integration tests use isolated test database
- Performance benchmarks for critical paths (FILO validation, hierarchy queries)
