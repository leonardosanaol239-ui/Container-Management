$path = "lib\screens\yard_screen.dart"
$content = Get-Content $path -Raw

# Remove the overlap check in onPanEnd - replace the whole overlap-checking block
# with just the save call
$old = '          final myPos = _blockOffsets[block.blockId]!;

          final mySize = _getBlockSize(block);

          // Check overlap with every other block and revert if overlapping    

          bool overlaps = false;

          for (final other in _blocks) {

            if (other.blockId == block.blockId) continue;

            final otherPos = _blockOffsets[other.blockId] ?? Offset(other.posX 
 ?? 10, other.posY ?? 10);

            final otherSize = _getBlockSize(other);

            if (_rectsOverlap(myPos, mySize, otherPos, otherSize)) {

              overlaps = true;

              break;

            }

          }

          if (overlaps) {

            // Revert to last saved position

            setState(() => _blockOffsets[block.blockId] = Offset(block.posX ?? 
 10, block.posY ?? 10));

            if (mounted) ScaffoldMessenger.of(context).showSnackBar(

              const SnackBar(content: Text(''Blocks cannot overlap''), duration: 
 Duration(seconds: 1)));

            return;

          }'

if ($content.Contains($old)) {
    Write-Output "Found exact pattern"
} else {
    Write-Output "Exact pattern not found - trying line by line search"
}

# Use line-by-line approach instead
$lines = Get-Content $path
$startLine = -1
$endLine = -1

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'Check overlap with every other block') {
        $startLine = $i - 2  # include the myPos/mySize lines before it
        Write-Output "Found overlap comment at line $($i+1)"
    }
    if ($startLine -ge 0 -and $lines[$i] -match 'return;' -and $i -gt $startLine) {
        $endLine = $i + 1  # include the closing brace of if(overlaps)
        Write-Output "Found return at line $($i+1), endLine=$($endLine+1)"
        break
    }
}

Write-Output "startLine=$($startLine+1) endLine=$($endLine+1)"

if ($startLine -ge 0 -and $endLine -ge 0) {
    # Show what we're removing
    Write-Output "=== Lines to remove ==="
    for ($i = $startLine; $i -le $endLine; $i++) {
        Write-Output "$($i+1): $($lines[$i])"
    }
    
    # Build new content: keep lines before startLine, skip to endLine+1
    $newLines = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($i -lt $startLine -or $i -gt $endLine) {
            $newLines += $lines[$i]
        }
    }
    $newContent = $newLines -join "`n"
    Set-Content $path $newContent -NoNewline
    Write-Output "Done: removed overlap check block"
} else {
    Write-Output "ERROR: Could not find overlap block boundaries"
}
