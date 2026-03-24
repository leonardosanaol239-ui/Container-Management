$path = "lib\screens\yard_screen.dart"
$content = Get-Content $path -Raw

# Use 4px per foot scale:
# Canvas = 300*4 x 170*4 = 1200 x 680
# Horizontal slot: 20ft*4=80px wide, 8ft*4=32px tall  (readable)
# Vertical slot:    8ft*4=32px wide, 20ft*4=80px tall  (readable)
# 170ft / 20ft = 8.5 bays fit vertically -> 8 full bays in 680px canvas
$content = $content.Replace('  static const double _canvasW = 600.0;', '  static const double _canvasW = 1200.0;')
$content = $content.Replace('  static const double _canvasH = 340.0;', '  static const double _canvasH = 680.0;')

Set-Content $path $content -NoNewline
Write-Output "Done: canvas 1200x680 (4px/ft)"

Select-String -Path $path -Pattern "_canvasW|_canvasH|_scaleX|_scaleY"
