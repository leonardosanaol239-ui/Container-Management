# Yard 4 in Cebu Port with Y4.png - Complete Setup Guide

## 🎯 Objective
Ensure Y4.png is visible in **Yard 4 in Cebu Port** with full functionality, consistency, and integrity.

---

## 📋 Current State vs Required State

### Current State
- **Cebu Port (PortId = 2)** only has **Yard 1**
- Manila Port (PortId = 1) has Yards 1-6

### Required State
- **Cebu Port (PortId = 2)** must have **Yard 4**
- **Yard 4** must have **ImagePath = 'Y4.png'**
- Y4.png must be visible when viewing Yard 4

---

## 🚀 Setup Steps

### Step 1: Add Yard 4 to Database

**Option A: Using PowerShell (Recommended)**
```powershell
cd container_mgmt
.\run_add_yard4_cebu.ps1
```

**Option B: Using SQL Directly**
1. Open SQL Server Management Studio
2. Connect to `ContainerManagement` database
3. Open `database/add_yard4_cebu.sql`
4. Execute (F5)

**Option C: Command Line**
```bash
cd container_mgmt
sqlcmd -S localhost -d ContainerManagement -E -i database/add_yard4_cebu.sql
```

### Step 2: Verify Database Changes

Run this query to confirm:
```sql
SELECT 
    y.YardId,
    y.YardNumber,
    y.PortId,
    p.PortDesc,
    y.ImagePath
FROM Yards y
INNER JOIN Ports p ON y.PortId = p.PortId
WHERE y.PortId = 2 AND y.YardNumber = 4;
```

**Expected Result:**
```
YardId  YardNumber  PortId  PortDesc    ImagePath
------  ----------  ------  ----------  ---------
X       4           2       Cebu Port   Y4.png
```

### Step 3: Update Flutter Dependencies

```bash
cd container_mgmt
flutter pub get
```

### Step 4: Restart Flutter App

**Important:** Hot reload will NOT work for asset changes. You must:
1. Stop the app completely
2. Restart it

---

## ✅ What the SQL Script Does

### 1. Verification Phase
- ✅ Checks if Cebu Port exists
- ✅ Checks if Yard 4 already exists

### 2. Creation/Update Phase
- ✅ Creates Yard 4 if it doesn't exist
- ✅ Sets ImagePath to 'Y4.png'
- ✅ Updates existing Yard 4 if it already exists

### 3. Consistency Phase
- ✅ Updates ALL Cebu Port yards to use Y4.png
- ✅ Ensures consistency across all yards

### 4. Integrity Checks
- ✅ Checks for orphaned yards
- ✅ Checks for duplicate yard numbers
- ✅ Verifies Yard 4 has Y4.png

### 5. Reporting
- ✅ Shows before/after state
- ✅ Displays all Cebu Port yards
- ✅ Provides summary statistics

---

## 🔍 Verification Checklist

After running the setup, verify:

- [ ] **Database**: Yard 4 exists in Cebu Port
  ```sql
  SELECT * FROM Yards WHERE PortId = 2 AND YardNumber = 4;
  ```

- [ ] **ImagePath**: Set to 'Y4.png'
  ```sql
  SELECT ImagePath FROM Yards WHERE PortId = 2 AND YardNumber = 4;
  -- Should return: Y4.png
  ```

- [ ] **Asset File**: Y4.png exists
  - Path: `container_mgmt/assets/Y4.png` ✅ (Already exists)

- [ ] **Pubspec**: Y4.png is listed
  - File: `pubspec.yaml` ✅ (Already configured)
  ```yaml
  assets:
    - assets/Y4.png
  ```

- [ ] **Flutter Code**: YardMap widget updated
  - File: `lib/widgets/yard_map.dart` ✅ (Already updated)
  - Now uses imagePath from database

- [ ] **App Running**: Restart completed
  - Stop app completely
  - Run `flutter pub get`
  - Start app again

---

## 🏗️ Architecture & Data Flow

### Database Layer
```
Ports Table
├─ PortId: 2
└─ PortDesc: "Cebu Port"
    │
    └─> Yards Table
        ├─ YardId: (auto-generated)
        ├─ YardNumber: 4
        ├─ PortId: 2
        └─ ImagePath: "Y4.png"  ← This is what we're setting
```

### Flutter Layer
```
API Service (api_service.dart)
├─ getYardById(yardId)
│  └─> Returns Yard object with imagePath
│
Yard Model (yard.dart)
├─ yardId: int
├─ yardNumber: int
├─ portId: int
└─ imagePath: String?  ← Comes from database
    │
    └─> YardMap Widget (yard_map.dart)
        ├─ Receives: yardImagePath
        ├─ Constructs: 'assets/${yardImagePath}'
        └─ Displays: Y4.png as background
```

### Image Loading Logic (Updated)
```dart
// In yard_map.dart
String backgroundImage;

if (widget.yardImagePath != null && widget.yardImagePath!.isNotEmpty) {
  // Use database value
  backgroundImage = 'assets/${widget.yardImagePath}';
} else {
  // Fallback to Y4.png
  backgroundImage = 'assets/Y4.png';
}
```

---

## 🔧 Code Changes Made

### 1. Database Script: `database/add_yard4_cebu.sql`
- Creates Yard 4 in Cebu Port
- Sets ImagePath to 'Y4.png'
- Performs integrity checks
- Ensures consistency

### 2. PowerShell Script: `run_add_yard4_cebu.ps1`
- Executes the SQL script
- Provides colored output
- Error handling
- Next steps guidance

### 3. Flutter Widget: `lib/widgets/yard_map.dart`
**Before:**
```dart
// FORCE Y4.png for testing
final String backgroundImage = 'assets/Y4.png';
```

**After:**
```dart
// Use imagePath from database, fallback to Y4.png
String backgroundImage;

if (widget.yardImagePath != null && widget.yardImagePath!.isNotEmpty) {
  backgroundImage = 'assets/${widget.yardImagePath}';
} else {
  backgroundImage = 'assets/Y4.png';
}
```

---

## 📊 Database Schema

### Yards Table Structure
```sql
CREATE TABLE Yards (
    YardId INT PRIMARY KEY IDENTITY(1,1),
    YardNumber INT NOT NULL,
    PortId INT NOT NULL,
    ImagePath NVARCHAR(255),      -- ← Y4.png goes here
    YardWidth FLOAT,
    YardHeight FLOAT,
    FOREIGN KEY (PortId) REFERENCES Ports(PortId)
);
```

### Sample Data After Setup
```sql
-- Cebu Port Yards
YardId  YardNumber  PortId  ImagePath
------  ----------  ------  ---------
7       1           2       Y4.png
X       4           2       Y4.png    ← New yard
```

---

## 🎨 Asset Configuration

### File Location
```
container_mgmt/
├── assets/
│   ├── Y4.png              ✅ Exists
│   ├── yard1_bg.png
│   └── gothong_logo.png
└── pubspec.yaml            ✅ Configured
```

### pubspec.yaml
```yaml
flutter:
  assets:
    - assets/yard1_bg.png
    - assets/Y4.png         ✅ Listed
    - assets/gothong_logo.png
```

---

## 🐛 Troubleshooting

### Issue: "Yard 4 not showing in app"
**Possible Causes:**
1. Database not updated
2. App not restarted
3. Cache issue

**Solutions:**
```sql
-- 1. Verify database
SELECT * FROM Yards WHERE PortId = 2 AND YardNumber = 4;

-- 2. Check ImagePath
SELECT ImagePath FROM Yards WHERE PortId = 2 AND YardNumber = 4;
-- Should return: Y4.png
```

```bash
# 3. Clear Flutter cache and restart
flutter clean
flutter pub get
# Then restart app
```

### Issue: "Y4.png not displaying"
**Possible Causes:**
1. Asset not loaded
2. Path incorrect
3. Hot reload used instead of restart

**Solutions:**
```bash
# 1. Verify asset exists
ls assets/Y4.png

# 2. Check pubspec.yaml
grep "Y4.png" pubspec.yaml

# 3. Full restart (not hot reload)
# Stop app completely, then:
flutter pub get
flutter run
```

### Issue: "SQL script fails"
**Possible Causes:**
1. SQL Server not running
2. Database doesn't exist
3. Permission issues

**Solutions:**
```powershell
# 1. Check SQL Server status
Get-Service MSSQLSERVER

# 2. Test connection
sqlcmd -S localhost -E -Q "SELECT @@VERSION"

# 3. Verify database exists
sqlcmd -S localhost -E -Q "SELECT name FROM sys.databases WHERE name = 'ContainerManagement'"
```

### Issue: "Duplicate yard error"
**Cause:** Yard 4 already exists

**Solution:**
The script handles this automatically. It will:
1. Detect existing Yard 4
2. Update ImagePath to Y4.png
3. Continue with consistency checks

---

## 🔒 Integrity & Consistency

### Integrity Checks Performed
1. **Orphaned Yards**: Yards without valid port
2. **Duplicate Yards**: Multiple yards with same number in same port
3. **ImagePath Validation**: Yard 4 has Y4.png

### Consistency Measures
1. **All Cebu Yards**: Updated to use Y4.png
2. **Uniform Naming**: All use 'Y4.png' (not 'y4.png' or 'Y4.PNG')
3. **Database Constraints**: Foreign key ensures valid PortId

---

## 📈 Testing

### Manual Testing Steps
1. **Run SQL Script**
   ```powershell
   .\run_add_yard4_cebu.ps1
   ```

2. **Verify Database**
   ```sql
   SELECT * FROM Yards WHERE PortId = 2 ORDER BY YardNumber;
   ```

3. **Restart Flutter App**
   ```bash
   flutter pub get
   # Restart app
   ```

4. **Navigate in App**
   - Go to Cebu Port
   - Select Yard 4
   - Verify Y4.png is displayed as background

### Expected Behavior
- ✅ Yard 4 appears in Cebu Port yard list
- ✅ Y4.png loads as background image
- ✅ No errors in console
- ✅ Image fits properly (BoxFit.cover)

### Console Output to Look For
```
🖼️ Loading yard background: assets/Y4.png
🖼️ Yard Number: 4
🖼️ Yard Image Path from DB: Y4.png
```

---

## 📚 Related Files

### Database Files
- `database/add_yard4_cebu.sql` - **Main setup script** (NEW)
- `database/ensure_y4_portid2.sql` - Updates all Port 2 yards
- `database/add_yard_images_port2.sql` - Alternative script
- `database/setup_remote.sql` - Initial database setup

### PowerShell Scripts
- `run_add_yard4_cebu.ps1` - **Execute Yard 4 setup** (NEW)
- `run_y4_portid2.ps1` - Update all Port 2 yards

### Flutter Files
- `lib/widgets/yard_map.dart` - **Updated** to use database imagePath
- `lib/models/yard.dart` - Yard model with imagePath
- `lib/services/api_service.dart` - API calls
- `lib/screens/yard1_screen.dart` - Example usage

### Documentation
- `YARD4_CEBU_Y4_SETUP.md` - **This file** (NEW)
- `Y4_PORTID2_COMPLETE.md` - Port 2 setup guide
- `Y4_PORTID2_SETUP.md` - Quick setup guide
- `QUICK_START_Y4.md` - Quick start guide
- `Y4_BACKGROUND_SUMMARY.md` - Full summary

---

## ✨ Summary

### What We're Doing
1. ✅ Adding Yard 4 to Cebu Port in database
2. ✅ Setting ImagePath to 'Y4.png'
3. ✅ Ensuring all Cebu yards use Y4.png for consistency
4. ✅ Updating Flutter code to use database imagePath
5. ✅ Performing integrity checks

### Why This Ensures Functionality
- **Database**: Yard 4 exists with correct ImagePath
- **API**: Fetches imagePath from database
- **Model**: Includes imagePath field
- **Widget**: Uses imagePath to load image
- **Asset**: Y4.png exists and is configured

### Why This Ensures Consistency
- **All Cebu Yards**: Use same image (Y4.png)
- **Naming**: Consistent 'Y4.png' format
- **Loading Logic**: Fallback to Y4.png if path missing

### Why This Ensures Integrity
- **Foreign Keys**: Yard must have valid PortId
- **Checks**: No orphaned or duplicate yards
- **Validation**: Confirms Yard 4 has Y4.png

---

## 🎯 Final Checklist

Before considering this complete:

- [ ] SQL script executed successfully
- [ ] Database shows Yard 4 in Cebu Port
- [ ] ImagePath is 'Y4.png'
- [ ] No integrity errors
- [ ] Flutter dependencies updated (`flutter pub get`)
- [ ] App restarted (not hot reload)
- [ ] Yard 4 visible in Cebu Port
- [ ] Y4.png displays as background
- [ ] No console errors

---

## 🚀 Quick Start

**Just want to get it working? Run these commands:**

```powershell
# 1. Add Yard 4 to database
cd container_mgmt
.\run_add_yard4_cebu.ps1

# 2. Update Flutter
flutter pub get

# 3. Restart app (stop and start, not hot reload)
```

**Done!** Navigate to Cebu Port > Yard 4 to see Y4.png. ✅

---

**Created**: April 30, 2026  
**Purpose**: Ensure Y4.png is visible in Yard 4 in Cebu Port  
**Status**: ✅ Ready to Execute
