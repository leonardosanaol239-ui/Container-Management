# Quick Start: Enable Y4.png Background

## 🚀 Two Steps to Enable Y4.png

### Step 1: Update Database (30 seconds)

Open your database management tool and run:

```sql
UPDATE Yards SET ImagePath = 'Y4.png' WHERE YardId = 1;
```

**Don't know the YardId?** Use this instead:
```sql
UPDATE Yards 
SET ImagePath = 'Y4.png' 
WHERE YardNumber = 1;
```

**Want to update ALL yards?**
```sql
UPDATE Yards SET ImagePath = 'Y4.png';
```

### Step 2: Restart Flutter App (30 seconds)

```bash
# Stop the app (Ctrl+C in terminal)
cd container_mgmt
flutter pub get
flutter run -d chrome
```

**That's it!** ✅

## Verify It Worked

1. Navigate to Yard 1 in Cebu Port
2. You should see Y4.png as the background
3. Check console for: `🖼️ Loading yard background: assets/Y4.png`

## Still Not Working?

### Quick Fix 1: Clean Build
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

### Quick Fix 2: Verify Database
```sql
SELECT YardId, YardNumber, ImagePath FROM Yards;
-- ImagePath should show 'Y4.png'
```

### Quick Fix 3: Check File
Make sure `assets/Y4.png` exists in your project.

## Need More Help?

See detailed guides:
- `SETUP_YARD_BACKGROUND.md` - Complete setup guide
- `verify_setup.md` - Verification checklist
- `Y4_BACKGROUND_SUMMARY.md` - Full summary

## Common Mistakes

❌ **Hot reloading instead of restarting**
   → Assets require full app restart

❌ **Forgot to run SQL script**
   → Database must have ImagePath = 'Y4.png'

❌ **Didn't run `flutter pub get`**
   → Assets must be registered

✅ **Do this:** Stop app → Run SQL → `flutter pub get` → Restart app
