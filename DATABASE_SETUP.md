# Container Management Database Setup

This project supports both **Local** and **Remote** database configurations for flexible development and deployment.

## 🔄 Quick Switch Commands

### Switch to Local Database (Development)
```bash
.\switch_to_local.ps1
cd con_mgmt_api
dotnet run
```

### Switch to Remote Database (Production)
```bash
.\switch_to_remote.ps1
cd con_mgmt_api
dotnet run
```

## 📊 Database Configurations

### Local Database (LocalDB)
- **Server**: `(localdb)\MSSQLLocalDB`
- **Database**: `ContainerManagement`
- **Authentication**: Windows Integrated
- **Use Case**: Development, Testing, Offline work

### Remote Database (Production Server)
- **Server**: `192.168.76.119`
- **Database**: `ojt_2026_01_1`
- **Authentication**: SQL Server (jasper/Default@123)
- **Use Case**: Production, Team collaboration

## 🚀 Initial Setup

### 1. Local Database Setup
```bash
# Start LocalDB
sqllocaldb start MSSQLLocalDB

# Create database and tables
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -i database/00_setup_localdb.sql
```

### 2. Remote Database Setup (When Server is Online)
```bash
# Create database and tables on remote server
sqlcmd -S 192.168.76.119 -U jasper -P Default@123 -i database/setup_remote.sql
```

## 📋 Database Schema

Both databases contain identical schema:
- **8 Tables**: Status, Ports, Yards, Blocks, Bays, Rows, Slots, Containers
- **5 Ports**: Manila, Cebu, Davao, Bacolod, Cagayan
- **Manila Yard 1**: 5 blocks with 76 total slots
- **FILO Stacking**: Max 5 tiers per slot

## 🔧 Configuration Files

- `appsettings.json` - Main configuration
- `appsettings.Production.json` - Production overrides
- Connection strings and database settings are managed automatically

## 📝 Migration Between Databases

### Export Data from Local
```bash
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -Q "SELECT * FROM ContainerManagement.dbo.Containers" -o containers_backup.csv
```

### Import Data to Remote
```bash
# Use the backup file to recreate containers on remote server
```

## 🎯 Current Status

- ✅ Local database fully configured and working
- ⏳ Remote database ready for setup when server is online
- ✅ Easy switching between environments
- ✅ All API endpoints tested and functional

## 🔍 Troubleshooting

### LocalDB Issues
```bash
# Check LocalDB instances
sqllocaldb info

# Start LocalDB if stopped
sqllocaldb start MSSQLLocalDB
```

### Remote Server Issues
- Check if 192.168.76.119 is accessible
- Verify SQL Server service is running
- Confirm firewall allows connections on port 1433