# Container Management API

A RESTful API built with ASP.NET Core 8.0 for managing shipping containers across multiple ports with hierarchical location tracking and FILO stacking validation.

## Features

- **Port Management**: Manage multiple shipping ports
- **Hierarchical Location Tracking**: Ports → Yards → Blocks → Bays → Rows → Slots
- **Container Operations**: Create, retrieve, search, and move containers
- **FILO Stacking**: First-In-Last-Out stacking validation (up to 5 tiers per slot)
- **Auto-Generated Container Numbers**: CON-1, CON-2, etc.
- **Location Hierarchy**: Complete path tracking from port to slot
- **CORS Support**: Ready for Flutter frontend integration

## Database Connection

- **Server**: 192.168.76.119
- **Database**: ojt_2026_01_1
- **Authentication**: SQL Server (jasper / Default@123)

## API Endpoints

### Ports
- `GET /api/ports` - Get all ports
- `GET /api/ports/{id}` - Get port by ID

### Yards
- `GET /api/yards?portId={portId}` - Get yards by port
- `GET /api/yards/{id}` - Get yard by ID

### Blocks
- `GET /api/blocks?yardId={yardId}` - Get blocks by yard
- `GET /api/blocks/{id}` - Get block by ID

### Bays
- `GET /api/bays?blockId={blockId}` - Get bays by block
- `GET /api/bays/{id}` - Get bay by ID

### Rows
- `GET /api/rows?bayId={bayId}` - Get rows by bay
- `GET /api/rows/{id}` - Get row by ID

### Slots
- `GET /api/slots?rowId={rowId}` - Get slots by row (with occupancy info)
- `GET /api/slots/{id}` - Get slot by ID (with occupancy info)

### Containers
- `POST /api/containers` - Create new container
- `GET /api/containers?portId={portId}` - Get containers by port
- `GET /api/containers/{id}` - Get container by ID
- `GET /api/containers/search?containerNumber={number}` - Search container by number
- `GET /api/containers/{id}/location-hierarchy` - Get container location hierarchy
- `PUT /api/containers/{id}/location` - Update container location

### Statuses
- `GET /api/statuses` - Get all container statuses (Laden/Empty)

## Running the API

1. Ensure SQL Server database is set up with the required tables
2. Navigate to the `con_mgmt_api` folder
3. Run: `dotnet restore`
4. Run: `dotnet run`
5. API will be available at `https://localhost:7000` (or the configured port)
6. Swagger UI available at `https://localhost:7000/swagger`

## Key Business Rules

- Container numbers are auto-generated as CON-{increment}
- Maximum 5 containers per slot (tiers 1-5)
- FILO stacking: Only top tier can be removed first
- Containers can be in "holding area" (no slot assignment) or in specific slots
- All location fields must be provided when assigning to a slot
- Lower tiers must be occupied before placing containers in higher tiers

## Error Handling

- **400 Bad Request**: Validation errors, invalid data
- **404 Not Found**: Resource not found
- **409 Conflict**: FILO stacking violations, occupied tier positions
- **500 Internal Server Error**: Unexpected server errors

All errors return JSON with descriptive messages.

## Architecture

- **Controllers**: Handle HTTP requests and responses
- **Services**: Business logic and validation
- **Models**: Entity Framework Core models
- **DTOs**: Data transfer objects for API requests/responses
- **Middleware**: Global exception handling
- **Database**: Entity Framework Core with SQL Server