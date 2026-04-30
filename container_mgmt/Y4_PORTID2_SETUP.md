# Y4 in Database for PORTID2 - Setup Guide

## 🎯 Objective
Ensure that **Y4.png** is set as the ImagePath for all yards in **Port 2 (PortId = 2)** in the database.

---

## 🚀 Quick Setup (2 Methods)

### Method 1: Using PowerShell Script (Recommended)

1. **Open PowerShell** in the `container_mgmt` directory
2. **Run the script:**
   ```powershell
   .\run_y4_portid2.ps1
   ```
3. **Done!** The script will:
   - Show current state of Port 2
   - Update all yards to Y4.png
   - Verify the changes
   - Display summary

### Method 2: Using SQL Directly

1. **Open SQL Server Management Studio (SSMS)** or any SQL client
2. **Connect to your database:** `ContainerManagement`
3. **Open and execute:** `database/ensure_y4_portid2.sql`
4. **Review the output** to confirm Y4.png is set

---

## 📋 What Gets Updated

The script updates the `Yards` table:

```sql
UPDATE Yards
SET ImagePath = 'Y4.png'
WHERE PortId = 2;
```

This ensures **ALL yards in Port 2** have `ImagePath = 'Y4.png'`

---

## ✅ Verification

After running the script, you should see output like:

```
AFTER UPDATE - Verification:
YardId  YardNumber  PortId  ImagePath  Status
------  ----------  ------  ---------  --------
7       1           2       Y4.png     ✅ SUCCESS
```

---

## 🔍 Manual Verification Query

To manually check if Y4 is set for Port 2:

```sql
SELECT 
    y.YardId,
    y.YardNumber,
    y.PortId,
    y.ImagePath,
    CASE 
        WHEN y.ImagePath = 'Y4.png' THEN '✅ SUCCESS'
        ELSE '❌ NOT SET'
    END AS Status
FROM Yards y
WHERE y.PortId = 2
ORDER BY y.YardNumber;
```

---

## 📁 Files Created

1. **`database/ensure_y4_portid2.sql`** - SQL script to update and verify
2. **`run_y4_portid2.ps1`** - PowerShell script to execute the SQL
3. **`Y4_PORTID2_SETUP.md`** - This documentation file

---

## 🛠️ Troubleshooting

### Issue: "SQL file not found"
**Solution:** Make sure you're running the PowerShell script from the `container_mgmt` directory.

### Issue: "Cannot connect to database"
**Solution:** 
- Verify SQL Server is running
- Check database name is `ContainerManagement`
- Ensure Windows Authentication is enabled

### Issue: "sqlcmd not found"
**Solution:** Install SQL Server Command Line Tools or use SSMS to run the SQL file directly.

### Issue: Y4.png not showing in app
**Solution:** After database update:
1. Verify `assets/Y4.png` exists
2. Check `pubspec.yaml` includes the asset
3. Run `flutter pub get`
4. **Restart the app** (hot reload won't work for assets)

---

## 📊 Database Schema Reference

### Ports Table
| Column | Type | Description |
|--------|------|-------------|
| PortId | INT | Primary Key (2 = Port 2) |
| PortName | NVARCHAR | Port name |
| PortDesc | NVARCHAR | Port description |

### Yards Table
| Column | Type | Description |
|--------|------|-------------|
| YardId | INT | Primary Key |
| YardNumber | INT | Yard number within port |
| PortId | INT | Foreign Key to Ports |
| ImagePath | NVARCHAR | Background image filename |
| YardWidth | INT | Yard width |
| YardHeight | INT | Yard height |

---

## 🎯 Expected Result

After running the setup:
- ✅ All yards in Port 2 have `ImagePath = 'Y4.png'`
- ✅ Database is ready for the Flutter app
- ✅ Y4.png will display as background when viewing Port 2 yards

---

## 📚 Related Documentation

- `QUICK_START_Y4.md` - Quick start guide for Y4 setup
- `SETUP_YARD_BACKGROUND.md` - Complete background setup guide
- `Y4_BACKGROUND_SUMMARY.md` - Full Y4 implementation summary
- `database/add_yard_images_port2.sql` - Alternative SQL script

---

## ✨ Summary

**The Y4 MUST BE IN THE DATABASE IN THE PORTID2** ✅

This setup ensures that requirement is met by:
1. Updating the database to set Y4.png for all Port 2 yards
2. Providing verification queries to confirm the update
3. Including troubleshooting steps for common issues

**Run the script and you're done!** 🚀
