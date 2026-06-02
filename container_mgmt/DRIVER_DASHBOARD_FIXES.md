# Driver Dashboard Fixes - June 1, 2026

## Issues Fixed

### 1. Color Consistency with Admin Dashboard ✅
**Problem**: Driver dashboard was using different colors than the admin dashboard.

**Solution**: Updated all color constants to match the admin dashboard's Gothong Southern brand colors:

```dart
// OLD COLORS
static const _primaryGreen = Color(0xFF0B5D1E);
static const _secondaryGold = Color(0xFFF5C400);
static const _accent = Color(0xFFFF8C42);
static const _background = Color(0xFFF8F9FA);
static const _textDark = Color(0xFF1E293B);
static const _textLight = Color(0xFF64748B);
static const _successGreen = Color(0xFF10B981);
static const _warningRed = Color(0xFFEF4444);

// NEW COLORS (matching admin dashboard)
static const _primaryGreen = Color(0xFF0B560D);    // emerald
static const _secondaryGold = Color(0xFFFFD300);   // gold
static const _accent = Color(0xFFE65100);          // orange
static const _background = Color(0xFFF0F2EE);      // bg
static const _textDark = Color(0xFF1A1A0A);        // textD
static const _textLight = Color(0xFF757575);       // textL
static const _successGreen = Color(0xFF1A7A1C);    // emeraldL
static const _warningRed = Color(0xFFFF2800);      // red
```

### 2. Loading State Issue ✅
**Problem**: Dashboard was stuck in loading state or loading continuously.

**Solution**: 
- Improved error handling in `_loadData()` function
- Added proper `mounted` checks before calling `setState()`
- Ensured `_loading` is always set to `false` after data load completes or fails
- Added user-friendly error messages via SnackBar

**Key Changes**:
```dart
Future<void> _loadData() async {
  try {
    // ... data loading logic ...
    
    if (mounted) {
      setState(() {
        _moveRequests = moveRequests;
        _yardsById = yardsById;
        _portNames = portNames;
        _requestCountByYard = requestCountByYard;
        _loading = false;  // ✅ Always set to false
      });
      
      _fadeController.forward(from: 0);
      _slideController.forward(from: 0);
    }
  } catch (e) {
    if (mounted) {
      setState(() => _loading = false);  // ✅ Set to false on error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading dashboard: ${e.toString()}'),
          backgroundColor: _warningRed,
        ),
      );
    }
  }
}
```

### 3. Confirm Move Request Function ✅
**Problem**: The "Confirm" button on move requests was not functional (empty `onPressed: () {}`).

**Solution**: Implemented the complete `_confirmMoveRequest()` function that:
1. Shows a loading dialog while processing
2. Calls the API to confirm the move request (sets `locationStatusId` to 1)
3. Reloads the dashboard data to reflect changes
4. Shows success/error messages to the user

**Implementation**:
```dart
Future<void> _confirmMoveRequest(ContainerModel container) async {
  try {
    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: _primaryGreen),
      ),
    );

    // Call API to confirm move request (sets locationStatusId to 1)
    await _api.confirmMoveRequest(container.containerId);

    // Close loading dialog
    if (mounted) Navigator.of(context).pop();

    // Reload data to refresh the list
    await _loadData();

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Move request confirmed for ${container.containerNumber}',
          ),
          backgroundColor: _successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  } catch (e) {
    // Close loading dialog if still open
    if (mounted) Navigator.of(context).pop();

    // Show error message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error confirming request: ${e.toString()}'),
          backgroundColor: _warningRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
```

**Button Update**:
```dart
// OLD - Non-functional button
ElevatedButton(
  onPressed: () {},  // ❌ Empty function
  // ... styling ...
  child: const Text('Confirm'),
),

// NEW - Functional button
ElevatedButton(
  onPressed: () => _confirmMoveRequest(container),  // ✅ Calls confirm function
  // ... styling ...
  child: const Text('Confirm'),
),
```

## Testing

Run the application:
```bash
cd container_mgmt
flutter run -d chrome
```

### Test Scenarios:
1. **Color Consistency**: Verify that driver dashboard colors match admin dashboard
2. **Loading State**: Dashboard should load properly and not get stuck
3. **Confirm Function**: Click "Confirm" on a move request and verify:
   - Loading dialog appears
   - Request is confirmed in the backend
   - Dashboard refreshes automatically
   - Success message is displayed
   - Request disappears from the list (locationStatusId changes from 3 to 1)

## Files Modified
- `lib/screens/driver_dashboard_screen.dart`

## API Endpoint Used
- `PUT /Containers/{containerId}/locationstatus` with `{"locationStatusId": 1}`

## Notes
- All changes maintain the modern Material 3 design
- Port filtering is preserved (drivers only see their assigned port)
- All existing functionality remains intact
- Proper error handling and user feedback implemented
