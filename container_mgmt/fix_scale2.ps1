$path = "lib\screens\yard_screen.dart"
$content = Get-Content $path -Raw

# Revert kContainerHeight back to 8.0 (correct: slot depth = 8ft)
$content = $content.Replace('const double kContainerHeight = 20.0;', 'const double kContainerHeight = 8.0;')

# The canvas pixel size should reflect the yard ft dimensions at a chosen px/ft ratio.
# Yard = 300ft wide x 170ft tall.
# Pick a scale of ~2.0 px/ft -> canvas = 600 x 340 px
# That gives:
#   horizontal slot: 20ft * 2.0 = 40px wide, 8ft * 2.0 = 16px tall  (good readable size)
#   vertical slot:    8ft * 2.0 = 16px wide, 20ft * 2.0 = 40px tall
# scaleX = 600/300 = 2.0, scaleY = 340/170 = 2.0  (uniform scale, no distortion)
$content = $content.Replace('  static const double _canvasW = 700.0;', '  static const double _canvasW = 600.0;')
$content = $content.Replace('  static const double _canvasH = 400.0;', '  static const double _canvasH = 340.0;')

Set-Content $path $content -NoNewline
Write-Output "Done"

# Verify
Select-String -Path $path -Pattern "kContainerHeight|k20ftWidth|k40ftWidth|_canvasW|_canvasH"
