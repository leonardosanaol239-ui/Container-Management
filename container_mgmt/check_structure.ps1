$lines = Get-Content "lib\screens\yard_screen.dart"
Write-Output "Total lines: $($lines.Count)"
Write-Output ""
Write-Output "=== class declarations ==="
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^class |^// --') {
        Write-Output "Line $($i+1): $($lines[$i])"
    }
}
Write-Output ""
Write-Output "=== _loadAll occurrences ==="
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '_loadAll') {
        Write-Output "Line $($i+1): $($lines[$i])"
    }
}
