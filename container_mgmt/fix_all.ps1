# Fix rootOverlay: true -> false in container_holding_area.dart
$path1 = "lib\widgets\container_holding_area.dart"
$content1 = Get-Content $path1 -Raw
$fixed1 = $content1 -replace 'rootOverlay: true', 'rootOverlay: false'
Set-Content $path1 $fixed1 -NoNewline
Write-Output "container_holding_area.dart: done"

# Fix rootOverlay: true -> false in yard1_screen.dart
$path2 = "lib\screens\yard1_screen.dart"
$content2 = Get-Content $path2 -Raw
$fixed2 = $content2 -replace 'rootOverlay: true', 'rootOverlay: false'
Set-Content $path2 $fixed2 -NoNewline
Write-Output "yard1_screen.dart: done"

# Fix rootOverlay: true -> false in yard_map.dart
$path3 = "lib\widgets\yard_map.dart"
$content3 = Get-Content $path3 -Raw
$fixed3 = $content3 -replace 'rootOverlay: true', 'rootOverlay: false'
Set-Content $path3 $fixed3 -NoNewline
Write-Output "yard_map.dart: done"

# Verify
Write-Output ""
Write-Output "=== Remaining rootOverlay: true occurrences ==="
Select-String -Path "lib\widgets\container_holding_area.dart","lib\screens\yard1_screen.dart","lib\widgets\yard_map.dart","lib\screens\yard_screen.dart" -Pattern "rootOverlay: true"
Write-Output "=== All rootOverlay occurrences ==="
Select-String -Path "lib\widgets\container_holding_area.dart","lib\screens\yard1_screen.dart","lib\widgets\yard_map.dart","lib\screens\yard_screen.dart" -Pattern "rootOverlay"
