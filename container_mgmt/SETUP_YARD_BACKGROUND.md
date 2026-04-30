# Setup Y4.png Background for Yard 1 - Complete Guide

## Problem
The Y4.png background image is not showing in Yard 1 of Cebu Port.

## Solution Steps

### Step 1: Verify Y4.png Exists ✅
The file `assets/Y4.png` already exists in the project.

### Step 2: Update Database (REQUIRED)

Run this SQL script on your backend database:

```sql
-- Update Yard 1 in Cebu Port to use Y4.png
UPDATE Yards
SET ImagePath = 'Y4.png'
WHERE YardNumber = 1 
  AND PortId = (SELECT PortId FROM Ports WHERE PortName LIKE '%Cebu%');

-- Verify the update
SELECT 
    y.YardId,
    y.YardNumber,
    p.PortName,
    y.ImagePath
FROM Yards y
INNER JOIN Ports p ON y.PortId = p.PortId
WHERE p.PortName LIKE '%Cebu%'
ORDER BY y.YardNumber;
```

**Alternative (if you know the exact YardId):**
```sql
UPDATE Yards SET ImagePath = 'Y4.png' WHERE YardId = 1;
```

**To update ALL yards in Cebu Port:**
```sql
UPDATE Yards
SET ImagePath = 'Y4.png'
WHERE PortId = (SELECT PortId FROM Ports WHERE PortName LIKE '%Cebu%');
```

### Step 3: Restart Flutter App (REQUIRED)

Assets are loaded at app startup, so you MUST restart:

```bash
# Stop the current app (Ctrl+C in terminal)

# Make sure assets are registered
flutter pub get

# Restart the app
flutter run -d chrome
# OR
flutter run -d windows
```

**⚠️ Important:** Hot reload (R key) will NOT work for asset changes!

### Step 4: Verify in Console

After restarting, check the Flutter console for these messages:

```
🖼️ Loading yard background: assets/Y4.png
```

If you see error messages like:
```
❌ Error loading asset assets/Y4.png: ...
```

Then the asset is not properly registered.

## Troubleshooting

### Issue 1: Image Still Not Showing

**Check 1: Verify pubspec.yaml**
Open `pubspec.yaml` and ensure Y4.png is listed:

```yaml
flutter:
  assets:
    - assets/yard1_bg.png
    - assets/Y4.png          # ← Must be here
    - assets/gothong_logo.png
```

**Check 2: Verify File Exists**
Navigate to `container_mgmt/assets/` and confirm `Y4.png` exists.

**Check 3: File Name Case Sensitivity**
Ensure the filename is exactly `Y4.png` (not `y4.png` or `Y4.PNG`).

**Check 4: Run Flutter Clean**
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

### Issue 2: Database Not Updated

**Check if ImagePath column exists:**
```sql
SELECT COLUMN_NAME, DATA_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Yards' AND COLUMN_NAME = 'ImagePath';
```

**If column doesn't exist, create it:**
```sql
ALTER TABLE Yards 
ADD ImagePath NVARCHAR(255) NULL;
```

**Then update the data:**
```sql
UPDATE Yards SET ImagePath = 'Y4.png' WHERE YardNumber = 1;
```

### Issue 3: Backend Not Returning ImagePath

**Check API Response:**
Open browser DevTools (F12) → Network tab → Look for the Yards API call.

The response should include:
```json
{
  "yardId": 1,
  "yardNumber": 1,
  "portId": 1,
  "imagePath": "Y4.png",  // ← Should be here
  ...
}
```

**If imagePath is null or missing:**
1. Verify database was updated (Step 2)
2. Check if backend is returning the ImagePath field
3. Restart backend server

## How It Works

### Priority Order:
1. **Database ImagePath** (if available) - Highest priority
2. **Hardcoded by YardNumber** - Fallback
3. **Default yard1_bg.png** - Last resort

### Code Flow:
```dart
YardMap(
  yardNumber: 1,
  yardImagePath: 'Y4.png',  // From database or hardcoded
  ...
)
```

The widget checks:
1. Is `yardImagePath` provided? → Use it
2. No? → Check `yardNumber` and use Y4.png for yard 1
3. Still no? → Use yard1_bg.png as fallback

## Quick Test

To test if Y4.png is accessible, create a simple test widget:

```dart
// Add this temporarily to test
Container(
  width: 200,
  height: 200,
  child: Image.asset('assets/Y4.png'),
)
```

If this shows the image, then Y4.png is properly loaded.

## Database Schema

Your Yards table should have:

```sql
CREATE TABLE Yards (
    YardId INT PRIMARY KEY,
    YardNumber INT NOT NULL,
    PortId INT NOT NULL,
    YardWidth FLOAT NULL,
    YardHeight FLOAT NULL,
    ImagePath NVARCHAR(255) NULL,  -- ← This column
    FOREIGN KEY (PortId) REFERENCES Ports(PortId)
);
```

## Files Modified

✅ `pubspec.yaml` - Added Y4.png to assets
✅ `lib/widgets/yard_map.dart` - Added yardImagePath parameter
✅ `lib/screens/yard1_screen.dart` - Passing Y4.png explicitly
✅ `database/update_yard_images.sql` - SQL script to update database

## Next Steps

1. ✅ Run the SQL script on your database
2. ✅ Restart your Flutter app (not hot reload!)
3. ✅ Check console for "🖼️ Loading yard background: assets/Y4.png"
4. ✅ Verify Y4.png is visible in Yard 1

## Support

If still not working:
1. Check Flutter console for error messages
2. Verify database was updated successfully
3. Ensure backend is returning ImagePath in API response
4. Try `flutter clean` and rebuild
5. Check browser DevTools console for errors
