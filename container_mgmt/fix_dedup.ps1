$path = "lib\screens\yard_screen.dart"
$lines = Get-Content $path

# Remove the stale comment block + duplicate scale fields (lines 56-61 area)
$newLines = @()
$skipNext = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($skipNext -gt 0) { $skipNext--; continue }
    # Detect the duplicate block starting with the comment
    if ($lines[$i] -match '// Computed by LayoutBuilder') {
        # Skip this line + next 5 (the duplicate declarations)
        $skipNext = 5
        Write-Output "Removing duplicate block at line $($i+1)"
        continue
    }
    $newLines += $lines[$i]
}

$newLines -join "`n" | Set-Content $path -NoNewline
Write-Output "Done. Lines: $($newLines.Count)"

# Verify
$v = Get-Content $path
for ($i = 48; $i -le 60; $i++) { Write-Output "$($i+1): $($v[$i])" }
