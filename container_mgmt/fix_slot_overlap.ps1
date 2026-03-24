$path = "lib\screens\yard_screen.dart"
$lines = Get-Content $path

# We need to:
# 1. Add a _getSlotsRect(Block, Offset posInFt) -> Rect method that returns the
#    slots-only bounding box in FEET
# 2. Replace the overlap check in onPanEnd to use slots rects

# Find the _rectsOverlap method and insert _getSlotsRect after it
$insertAfter = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'bool _rectsOverlap') { 
        # find end of this method
        $depth = 0
        for ($j = $i; $j -lt $lines.Count; $j++) {
            $depth += ($lines[$j].ToCharArray() | Where-Object {$_ -eq '{'}).Count
            $depth -= ($lines[$j].ToCharArray() | Where-Object {$_ -eq '}'}).Count
            if ($depth -eq 0 -and $j -gt $i) { $insertAfter = $j; break }
        }
        break
    }
}
Write-Output "Will insert _getSlotsRect after line $($insertAfter+1)"

$getSlotsRect = @(
'',
'  // Returns the slots-only bounding rect in FEET for a block at posInFt.',
'  // Headers (bay labels, block name label) are excluded.',
'  Rect _getSlotsRect(Block block, Offset posInFt) {',
'    final bays = _baysByBlock[block.blockId] ?? [];',
'    final isVert = block.isVertical;',
'    final is40 = block.is40ft;',
'    // slot dimensions in feet',
'    final slotLong = (is40 ? k40ftWidth : k20ftWidth); // 20 or 40 ft',
'    final slotShort = kContainerHeight;                 // 8 ft',
'    final slotW = isVert ? slotShort : slotLong;',
'    final slotH = isVert ? slotLong  : slotShort;',
'    int maxRows = 0;',
'    for (final bay in bays) {',
'      final rows = _rowsByBay[bay.bayId] ?? [];',
'      if (rows.length > maxRows) maxRows = rows.length;',
'    }',
'    final slotsW = bays.isEmpty ? slotW : bays.length * slotW;',
'    final slotsH = maxRows == 0 ? slotH : maxRows * slotH;',
'    // Header offsets in feet (convert fixed px to ft)',
'    // Horizontal: bay-label row on top = 14px, block-name at bottom not relevant for overlap',
'    // Vertical:   block-name rotated on left = 14px wide',
'    final headerFt = 14.0 / _scale;',
'    final left = isVert ? posInFt.dx + headerFt : posInFt.dx;',
'    final top  = isVert ? posInFt.dy            : posInFt.dy + headerFt;',
'    return Rect.fromLTWH(left, top, slotsW, slotsH);',
'  }',
''
)

# Also add overlap check back in onPanEnd using slots rects
# Find onPanEnd and the save line
$panEndSave = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'onPanEnd.*async' -or ($lines[$i] -match 'onPanEnd' -and $lines[$i+1] -match 'async')) {
        # find the myPos + save line
        for ($j = $i; $j -lt [Math]::Min($i+20, $lines.Count); $j++) {
            if ($lines[$j] -match 'final myPos = _blockOffsets') {
                $panEndSave = $j
                break
            }
        }
        break
    }
}
Write-Output "onPanEnd save at line $($panEndSave+1)"

# Build new file
$newLines = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    $newLines += $lines[$i]
    
    # Insert _getSlotsRect after _rectsOverlap
    if ($i -eq $insertAfter) {
        foreach ($l in $getSlotsRect) { $newLines += $l }
    }
    
    # Replace the save block in onPanEnd with overlap check + save
    if ($i -eq $panEndSave) {
        # Remove the line we just added (it was the old myPos line)
        $newLines = $newLines[0..($newLines.Count-2)]
        $newLines += '          final myPos = _blockOffsets[block.blockId]!;'
        $newLines += '          // Check slots-only overlap with every other block'
        $newLines += '          final myRect = _getSlotsRect(block, myPos);'
        $newLines += '          bool overlaps = false;'
        $newLines += '          for (final other in _blocks) {'
        $newLines += '            if (other.blockId == block.blockId) continue;'
        $newLines += '            final otherPos = _blockOffsets[other.blockId] ?? Offset((other.posX ?? 10).toDouble(), (other.posY ?? 10).toDouble());'
        $newLines += '            final otherRect = _getSlotsRect(other, otherPos);'
        $newLines += '            if (myRect.overlaps(otherRect)) { overlaps = true; break; }'
        $newLines += '          }'
        $newLines += '          if (overlaps) {'
        $newLines += '            setState(() => _blockOffsets[block.blockId] = Offset((block.posX ?? 10).toDouble(), (block.posY ?? 10).toDouble()));'
        $newLines += '            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(''Slot areas cannot overlap''), duration: Duration(seconds: 1)));'
        $newLines += '            return;'
        $newLines += '          }'
        Write-Output "Inserted overlap check at line $($i+1)"
    }
}

$newLines -join "`n" | Set-Content $path -NoNewline
Write-Output "Done. Lines: $($newLines.Count)"
