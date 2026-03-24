$path = "lib\screens\yard_screen.dart"
$lines = Get-Content $path

# Find the updateBlockPosition line and insert myPos before it
$newLines = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'updateBlockPosition\(block\.blockId, myPos') {
        Write-Output "Found at line $($i+1): $($lines[$i])"
        # Insert myPos declaration before this line (with same indentation)
        $newLines += '          final myPos = _blockOffsets[block.blockId]!;'
    }
    $newLines += $lines[$i]
}

$newContent = $newLines -join "`n"
Set-Content $path $newContent -NoNewline
Write-Output "Done"

# Verify
$lines2 = Get-Content $path
for ($j = 587; $j -le 598; $j++) {
    Write-Output "$($j+1): $($lines2[$j])"
}
