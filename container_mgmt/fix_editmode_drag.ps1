$path = "lib\screens\yard_screen.dart"
$lines = Get-Content $path

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s+if \(topContainer != null\) \{$') {
        $lines[$i] = $lines[$i] -replace 'if \(topContainer != null\)', 'if (topContainer != null && !editMode)'
        Write-Output "Fixed at line $($i+1): $($lines[$i])"
    }
}

$lines -join "`n" | Set-Content $path -NoNewline
Write-Output "Done"
