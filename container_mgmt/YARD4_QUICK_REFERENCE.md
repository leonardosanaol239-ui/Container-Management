# Yard 4 Cebu Port - Quick Reference Card

## 🎯 Goal
Y4.png visible in Yard 4 in Cebu Port

## ⚡ Quick Setup (3 Commands)

```powershell
# 1. Add Yard 4 to database
.\run_add_yard4_cebu.ps1

# 2. Update Flutter
flutter pub get

# 3. Restart app (not hot reload!)
```

## ✅ Verify

```powershell
.\verify_yard4_cebu.ps1
```

## 🔍 Quick Check (SQL)

```sql
SELECT YardNumber, ImagePath 
FROM Yards 
WHERE PortId = 2 AND YardNumber = 4;
-- Should return: 4, Y4.png
```

## 📁 Key Files

| File | Purpose |
|------|---------|
| `database/add_yard4_cebu.sql` | SQL script |
| `run_add_yard4_cebu.ps1` | Execute SQL |
| `verify_yard4_cebu.ps1` | Verify setup |
| `YARD4_CEBU_COMPLETE.md` | Full docs |

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Yard 4 missing | Run `.\run_add_yard4_cebu.ps1` |
| Image not showing | `flutter clean && flutter pub get` then restart |
| SQL error | Check SQL Server is running |
| Asset error | Verify `assets/Y4.png` exists |

## 📊 What Changed

### Database
- ✅ Added Yard 4 to Cebu Port (PortId = 2)
- ✅ Set ImagePath = 'Y4.png'

### Flutter
- ✅ Updated `yard_map.dart` to use database imagePath
- ✅ Removed invalid `Y$.png` from pubspec.yaml

## 🎯 Expected Result

**Database:**
```
YardNumber: 4
PortId: 2
ImagePath: Y4.png
```

**App:**
- Navigate to Cebu Port
- Select Yard 4
- See Y4.png as background

**Console:**
```
🖼️ Loading yard background: assets/Y4.png
🖼️ Yard Number: 4
🖼️ Yard Image Path from DB: Y4.png
```

## ✨ Status: ✅ Ready to Execute
