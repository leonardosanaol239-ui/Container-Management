$path = "lib\screens\yard_screen.dart"
$lines = Get-Content $path

# Find and remove the stray lines around the orphaned brace
# Pattern: line 591 has "final myPos = ...", line 592 is blank, line 593 is "          }"
# We need to remove lines 591, 592, 593 (the myPos declaration and orphaned brace)

$newLines = @()
$i = 0
while ($i -lt $lines.Count) {
    $line = $lines[$i]
    # Remove the orphaned myPos line + blank + stray closing brace
    if ($line -match '^\s+final myPos = _blockOffsets\[block\.blockId\]!;$') {
        Write-Output "Removing line $($i+1): $line"
        # skip this line, the blank after, and the stray }
        $i++  # skip blank
        $i++  # skip stray }
        $i++  # move past
        continue
    }
    $newLines += $line
    $i++
}

$newContent = $newLines -join "`n"
Set-Content $path $newContent -NoNewline
Write-Output "Done"

# Verify
$lines2 = Get-Content $path
for ($j = 585; $j -le 600; $j++) {
    Write-Output "$($j+1): $($lines2[$j])"
}
