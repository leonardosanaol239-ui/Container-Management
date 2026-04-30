# Quick Verification Checklist

## ✅ Checklist for Y4.png Background

### 1. File System
- [ ] `assets/Y4.png` exists
- [ ] File size is reasonable (< 5MB)
- [ ] File name is exactly `Y4.png` (case-sensitive)

### 2. Flutter Configuration
- [ ] `pubspec.yaml` includes `- assets/Y4.png`
- [ ] Ran `flutter pub get`
- [ ] App was **restarted** (not just hot reloaded)

### 3. Database
- [ ] Yards table has `ImagePath` column
- [ ] Ran SQL update script
- [ ] Verified with SELECT query that ImagePath = 'Y4.png'

### 4. Backend API
- [ ] Backend is running
- [ ] API returns ImagePath field in Yards response
- [ ] Backend was restarted after database update

### 5. Flutter App
- [ ] App shows console message: "🖼️ Loading yard background: assets/Y4.png"
- [ ] No error messages in console
- [ ] Y4.png is visible in Yard 1 view

## Quick Commands

```bash
# 1. Update assets
cd container_mgmt
flutter pub get

# 2. Clean build (if needed)
flutter clean
flutter pub get

# 3. Restart app
flutter run -d chrome
# OR
flutter run -d windows
```

## SQL Quick Check

```sql
-- Check if ImagePath column exists
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Yards' AND COLUMN_NAME = 'ImagePath';

-- Check current values
SELECT YardId, YardNumber, ImagePath FROM Yards;

-- Update Yard 1
UPDATE Yards SET ImagePath = 'Y4.png' WHERE YardId = 1;
```

## Expected Console Output

When app loads Yard 1, you should see:
```
🖼️ Loading yard background: assets/Y4.png
```

If you see errors:
```
❌ Error loading asset assets/Y4.png: ...
```

Then:
1. Check if Y4.png exists in assets folder
2. Check if pubspec.yaml includes it
3. Run `flutter pub get`
4. **Restart** the app (hot reload won't work)

## Still Not Working?

Run these checks in order:

### Check 1: Asset Registration
```bash
flutter pub get
flutter clean
flutter pub get
```

### Check 2: File Exists
```bash
ls -la assets/Y4.png
# OR on Windows
dir assets\Y4.png
```

### Check 3: Database
```sql
SELECT * FROM Yards WHERE YardNumber = 1;
-- Should show ImagePath = 'Y4.png'
```

### Check 4: API Response
Open browser DevTools (F12) → Network → Find Yards API call
Response should include: `"imagePath": "Y4.png"`

### Check 5: Console Logs
Look for these messages in Flutter console:
- "🖼️ Loading yard background: ..."
- Any "❌ Error loading ..." messages

## Success Indicators

✅ Console shows: "🖼️ Loading yard background: assets/Y4.png"
✅ No error messages in console
✅ Y4.png is visible as background in Yard 1
✅ Background covers the entire yard area
✅ Blocks and containers are visible on top of background
