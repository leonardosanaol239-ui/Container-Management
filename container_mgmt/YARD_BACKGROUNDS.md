# Yard Background Images Guide

## Overview
Each yard in the Cebu Port can have its own background image for better visualization and consistency.

## Current Configuration

### Yard 1 (Cebu Port)
- **Background Image**: `assets/Y4.png`
- **Location**: Cebu Port, Yard 1
- **Status**: ✅ Configured

### All Other Yards
- **Background Image**: `assets/Y4.png` (consistent across all yards)
- **Fallback**: `assets/yard1_bg.png`

## How It Works

The `YardMap` widget now accepts a `yardNumber` parameter that determines which background image to use:

```dart
YardMap(
  yardNumber: 1, // Specifies which yard (1-5)
  blocks: _blocks,
  baysByBlock: _baysByBlock,
  // ... other parameters
)
```

## Adding New Yard Backgrounds

### Step 1: Add Image to Assets

1. Place your yard background image in the `assets/` folder
2. Name it descriptively (e.g., `Y1.png`, `Y2.png`, `Y3.png`, etc.)

### Step 2: Update pubspec.yaml

Add the new image to the assets list:

```yaml
flutter:
  assets:
    - assets/yard1_bg.png
    - assets/Y4.png
    - assets/Y1.png  # Add your new image
    - assets/Y2.png  # Add your new image
    - assets/gothong_logo.png
```

### Step 3: Update YardMap Widget

Edit `lib/widgets/yard_map.dart` and update the switch statement:

```dart
String backgroundImage;
switch (widget.yardNumber) {
  case 1:
    backgroundImage = 'assets/Y4.png';  // Yard 1
    break;
  case 2:
    backgroundImage = 'assets/Y2.png';  // Yard 2 - NEW
    break;
  case 3:
    backgroundImage = 'assets/Y3.png';  // Yard 3 - NEW
    break;
  case 4:
    backgroundImage = 'assets/Y4.png';  // Yard 4
    break;
  case 5:
    backgroundImage = 'assets/Y5.png';  // Yard 5 - NEW
    break;
  default:
    backgroundImage = 'assets/yard1_bg.png';  // Fallback
}
```

### Step 4: Restart the App

After making changes:
1. Stop the Flutter app (Ctrl+C)
2. Run `flutter pub get` to update assets
3. Restart: `flutter run -d chrome` or `flutter run -d windows`

## Image Requirements

### Recommended Specifications
- **Format**: PNG (with transparency support)
- **Resolution**: 1920x1080 or higher
- **Aspect Ratio**: 16:9 or match your yard layout
- **File Size**: < 5MB for optimal performance
- **Content**: Aerial view of the yard showing:
  - Roads and pathways
  - Building outlines
  - Yard boundaries
  - Reference landmarks

### Image Preparation Tips
1. Use high-quality aerial photos or satellite imagery
2. Ensure good contrast for white block overlays
3. Consider adding slight transparency (80-90% opacity)
4. Optimize file size using tools like TinyPNG

## Consistency Guidelines

To maintain consistency across all yards:

1. **Same Image for All Yards** (Current Setup)
   - All yards use `Y4.png`
   - Ensures uniform appearance
   - Easier to maintain

2. **Unique Images Per Yard** (Alternative)
   - Each yard has its own background
   - More accurate representation
   - Requires more maintenance

## Troubleshooting

### Image Not Showing
1. Check if image exists in `assets/` folder
2. Verify image is listed in `pubspec.yaml`
3. Run `flutter pub get`
4. Restart the app (hot reload won't work for assets)

### Image Quality Issues
1. Check original image resolution
2. Ensure image is not overly compressed
3. Try different image formats (PNG vs JPG)

### Performance Issues
1. Reduce image file size
2. Use appropriate resolution (don't use 4K for small displays)
3. Consider using cached network images for large files

## Current Files

```
container_mgmt/
├── assets/
│   ├── Y4.png              ← Main yard background (Yard 1)
│   ├── yard1_bg.png        ← Fallback background
│   └── gothong_logo.png    ← Logo
├── lib/
│   └── widgets/
│       └── yard_map.dart   ← Background logic here
└── pubspec.yaml            ← Asset registration
```

## Future Enhancements

Potential improvements:
- [ ] Dynamic background loading from backend
- [ ] Support for multiple zoom levels (different images per zoom)
- [ ] Background image rotation/scaling controls
- [ ] Overlay opacity adjustment
- [ ] Real-time satellite imagery integration
