$lines = Get-Content "lib\screens\yard_screen.dart"
Write-Output "Total lines: $($lines.Count)"
Write-Output ""
Write-Output "=== All 'if (isVert)' occurrences ==="
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'if \(isVert\)') {
        Write-Output "Line $($i+1): $($lines[$i])"
    }
}
Write-Output ""
Write-Output "=== All 'rootOverlay' occurrences ==="
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'rootOverlay') {
        Write-Output "Line $($i+1): $($lines[$i])"
    }
}
Write-Output ""
Write-Output "=== Lines 750-770 ==="
for ($i = 749; $i -le 769; $i++) {
    Write-Output "Line $($i+1): $($lines[$i])"
}
