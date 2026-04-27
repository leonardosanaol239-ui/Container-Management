# Gothong Southern Container Management - Color Scheme Guide

## Official Pantone Colors

### PRIMARY COLOR: Cyber Yellow
- **Pantone**: Cyber Yellow
- **HEX**: `#FFD300`
- **RGB**: R-255, G-211, B-0
- **Usage**: Primary brand color, headers, buttons, highlights

### SECONDARY COLORS

#### Scarlet Red
- **Pantone**: Scarlet Red  
- **HEX**: `#FF2800`
- **RGB**: R-255, G-40, B-0
- **Usage**: Alerts, errors, empty containers, delete actions

#### Lincoln Green
- **Pantone**: Lincoln Green
- **HEX**: `#0B560D`
- **RGB**: R-11, G-86, B-13
- **Usage**: Success states, active status, table headers, action buttons

---

## Color Application Rules

### 1. Headers & Navigation
- **AppBar Background**: `AppColors.yellow` (#FFD300)
- **AppBar Text**: `AppColors.textDark` (almost black)
- **AppBar Icons**: `AppColors.textDark`

### 2. Buttons

#### Primary Action Buttons
- **Background**: `AppColors.green` (#0B560D)
- **Text**: `AppColors.yellow` (#FFD300)
- **Example**: ADD USER, Submit, Confirm

#### Secondary Action Buttons
- **Background**: `AppColors.yellow` (#FFD300)
- **Text**: `AppColors.textDark`
- **Example**: Edit, Filter, Search

#### Destructive Actions
- **Background**: `AppColors.red` (#FF2800)
- **Text**: `AppColors.white`
- **Example**: Delete, Remove, Cancel

### 3. Status Indicators

#### Container Status
- **Laden**: `AppColors.yellow` (#FFD300)
- **Empty**: `AppColors.empty` (#2196F3 - Blue)
- **Active**: `AppColors.green` (#0B560D)

#### User Status
- **Active**: `AppColors.green` (#0B560D)
- **Inactive**: Orange/Amber
- **Deleted**: `AppColors.red` (#FF2800)

### 4. Tables & Lists

#### Table Headers
- **Background**: `AppColors.green` (#0B560D)
- **Text**: `AppColors.yellow` (#FFD300)
- **Font Weight**: w900 (Extra Bold)

#### Table Rows
- **Even Rows**: `AppColors.white`
- **Odd Rows**: `AppColors.surface` (warm white #FFFDE7)
- **Border**: `AppColors.yellow` with 30% opacity

#### Summary Bars
- **Normal Mode**: `AppColors.green` background, `AppColors.yellow` text
- **Deleted Mode**: `AppColors.red` background, `AppColors.yellow` text

### 5. Forms & Inputs
- **Border (default)**: `AppColors.yellow` with 40% opacity
- **Border (focused)**: `AppColors.yellow` solid
- **Background**: `AppColors.white`
- **Text**: `AppColors.textDark`

### 6. Badges & Pills
- **Role Badges**: Background with 12% opacity of role color, border with 50% opacity
- **Status Badges**: Same as role badges
- **Count Badges**: `AppColors.green` background, `AppColors.yellow` text

---

## Consistency Checklist

When adding new features, ensure:

- [ ] Headers use yellow (#FFD300) background
- [ ] Primary actions use green (#0B560D) buttons with yellow text
- [ ] Destructive actions use red (#FF2800)
- [ ] Table headers are green with yellow text
- [ ] Status colors follow the defined palette
- [ ] No custom colors outside the defined palette
- [ ] Hover states use opacity variations of base colors
- [ ] Shadows use the same color as the element with reduced opacity

---

## Code Reference

```dart
// Import the theme
import '../theme/app_theme.dart';

// Use colors consistently
Container(
  color: AppColors.yellow,        // Primary
  child: Text(
    'Header',
    style: TextStyle(
      color: AppColors.textDark,  // Text on yellow
    ),
  ),
)

// Buttons
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.green,
    foregroundColor: AppColors.yellow,
  ),
  child: Text('Action'),
)

// Status indicators
Container(
  color: user.isActive 
    ? AppColors.green 
    : AppColors.red,
)
```

---

## Brand Guidelines Summary

**Stick to the core color palette in all content:**
- Primary: Cyber Yellow (#FFD300)
- Secondary: Scarlet Red (#FF2800), Lincoln Green (#0B560D)
- Neutrals: White, Warm White Surface, Text Dark, Text Grey

**Never:**
- Use colors outside this palette
- Mix different shades without approval
- Use low contrast combinations
- Override theme colors with hardcoded values

**Always:**
- Reference `AppColors` constants
- Maintain consistent color usage across screens
- Test color contrast for accessibility
- Use opacity variations for hover/disabled states
