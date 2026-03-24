# Container Management System - Database Setup

## Database Information
- **Server**: 192.168.76.119
- **Database Name**: ojt_2026_01_1
- **Authentication**: SQL Server Authentication
- **Login**: jasper
- **Password**: Default@123

## Setup Instructions

### Step 1: Execute Scripts in Order

Open SQL Server Management Studio (SSMS) and connect to the server, then execute the following scripts in order:

1. **01_create_tables.sql**
   - Creates all 8 database tables
   - Tables: Status, Ports, Yards, Blocks, Bays, Rows, Slots, Containers

2. **02_seed_data.sql**
   - Inserts initial data for Status, Ports, Yards, and Blocks
   - Creates 5 ports with their yards
   - Sets up 5 blocks for Manila Port Yard 1

3. **03_seed_manila_yard1_layout.sql**
   - Creates the complete layout for Manila Port Yard 1
   - Inserts all Bays, Rows, and Slots based on the yard map
   - Total: 76 slots across 5 blocks

4. **04_verify_setup.sql** (Optional)
   - Verification script to check if everything is set up correctly
   - Shows counts and summaries of all data

### Step 2: Verify Setup

After running all scripts, execute `04_verify_setup.sql` to verify:
- ✓ 2 Statuses (Laden, Empty)
- ✓ 5 Ports
- ✓ 10 Yards (6 for Manila, 1 each for others)
- ✓ 5 Blocks (Manila Yard 1)
- ✓ 76 Slots total

## Database Schema

### Tables Overview

```
Status
├── StatusId (PK)
└── StatusDesc

Ports
├── PortId (PK)
└── PortDesc

Yards
├── YardId (PK)
├── YardNumber
└── PortId (FK → Ports)

Blocks
├── BlockId (PK)
├── BlockNumber
├── BlockDesc
├── YardId (FK → Yards)
└── PortId (FK → Ports)

Bays
├── BayId (PK)
├── BayNumber
└── BlockId (FK → Blocks)

Rows
├── RowId (PK)
├── RowNumber
└── BayId (FK → Bays)

Slots
├── SlotId (PK)
├── RowId (FK → Rows)
├── SlotNumber
└── MaxTier (default: 5)

Containers
├── ContainerId (PK)
├── ContainerNumber (unique, auto: CON-X)
├── StatusId (FK → Status)
├── Type
├── ContainerDesc
├── CurrentPortId (FK → Ports)
├── YardId (FK → Yards, nullable)
├── BlockId (FK → Blocks, nullable)
├── BayId (FK → Bays, nullable)
├── RowId (FK → Rows, nullable)
├── Tier (1-5, nullable)
└── CreatedDate
```

## Manila Port Yard 1 Layout

- **Block 1**: 7 bays × 2 rows = 14 slots
- **Block 2 (Food Grade)**: 7 bays × 3 rows = 21 slots
- **Block 3 (None Food Grade)**: 7 bays × 3 rows = 21 slots
- **Block 4**: 7 bays × 2 rows = 14 slots (bays: 1,2,3,5,6,7,8)
- **Block 5**: 2 bays × 3 rows = 6 slots

**Total**: 76 slots

## Next Steps

After database setup is complete:
1. ✓ Database tables created
2. ✓ Initial data seeded
3. ✓ Manila Yard 1 layout configured
4. → Create C# ASP.NET API backend
5. → Create Flutter frontend application
