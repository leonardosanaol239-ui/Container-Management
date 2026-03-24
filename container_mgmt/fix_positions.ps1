$path = "lib\screens\yard_screen.dart"
$lines = Get-Content $path

$newLines = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    # 1. _loadAll: store offsets in FEET (divide by scale if they look like pixels,
    #    but actually posX/posY in DB should already be feet - just use them directly)
    #    Current: newOffsets[b.blockId] = Offset(b.posX ?? 10, b.posY ?? 10);
    #    Keep as-is (DB stores feet), _blockOffsets = feet coords
    
    # 2. _buildPositionedBlock line 545: offset is in feet, convert to px for Positioned
    #    Current: final offset = _blockOffsets[block.blockId] ?? Offset(block.posX ?? 10, block.posY ?? 10);
    if ($line -match '^\s+final offset = _blockOffsets\[block\.blockId\] \?\? Offset\(block\.posX') {
        $indent = ($line -replace '^(\s+).*','$1')
        $newLines += "${indent}// offset in feet -> convert to pixels for layout"
        $newLines += "${indent}final offsetFt = _blockOffsets[block.blockId] ?? Offset((block.posX ?? 10).toDouble(), (block.posY ?? 10).toDouble());"
        $newLines += "${indent}final offset = Offset(offsetFt.dx * _scale, offsetFt.dy * _scale);"
        Write-Output "Fixed offset px conversion at line $($i+1)"
        continue
    }

    # 3. onPanUpdate: delta is in pixels, convert back to feet before storing
    #    Current: final proposed = Offset(cur.dx + d.delta.dx, cur.dy + d.delta.dy);
    #             _blockOffsets[block.blockId] = _clampBlock(block, proposed);
    if ($line -match '^\s+final proposed = Offset\(cur\.dx \+ d\.delta\.dx') {
        $indent = ($line -replace '^(\s+).*','$1')
        $newLines += "${indent}// delta is pixels, convert to feet"
        $newLines += "${indent}final proposed = Offset(cur.dx + d.delta.dx / _scale, cur.dy + d.delta.dy / _scale);"
        Write-Output "Fixed onPanUpdate delta conversion at line $($i+1)"
        continue
    }

    # 4. onPanUpdate: cur should be in feet too
    #    Current: final cur = _blockOffsets[block.blockId] ?? offset;
    #    offset is now pixels (from step 2), but _blockOffsets is feet - use offsetFt
    if ($line -match '^\s+final cur = _blockOffsets\[block\.blockId\] \?\? offset;') {
        $indent = ($line -replace '^(\s+).*','$1')
        $newLines += "${indent}final cur = _blockOffsets[block.blockId] ?? offsetFt;"
        Write-Output "Fixed cur to use offsetFt at line $($i+1)"
        continue
    }

    # 5. _clampBlock: takes feet pos, clamp against canvas in feet
    #    Current: x = pos.dx.clamp(0, _canvasW - sz.width)  <- _canvasW is pixels, sz is pixels
    #    Need: clamp in feet: canvasW_ft = yardWidth, sz_ft = sz/scale
    #    Actually easier: keep _clampBlock working in feet by dividing canvas and size by scale
    if ($line -match '^\s+final x = pos\.dx\.clamp\(0\.0, \(_canvasW - sz\.width\)') {
        $indent = ($line -replace '^(\s+).*','$1')
        $newLines += "${indent}final yardWft = (widget.yard.yardWidth  ?? 300).toDouble();"
        $newLines += "${indent}final yardHft = (widget.yard.yardHeight ?? 170).toDouble();"
        $newLines += "${indent}final szFt = Size(sz.width / _scale, sz.height / _scale);"
        $newLines += "${indent}final x = pos.dx.clamp(0.0, (yardWft - szFt.width).clamp(0.0, yardWft));"
        Write-Output "Fixed _clampBlock x at line $($i+1)"
        continue
    }
    if ($line -match '^\s+final y = pos\.dy\.clamp\(0\.0, \(_canvasH - sz\.height\)') {
        $indent = ($line -replace '^(\s+).*','$1')
        $newLines += "${indent}final y = pos.dy.clamp(0.0, (yardHft - szFt.height).clamp(0.0, yardHft));"
        Write-Output "Fixed _clampBlock y at line $($i+1)"
        continue
    }

    # 6. onPanEnd save: myPos is in feet - save directly (correct)
    #    No change needed for the updateBlockPosition call

    # 7. non-edit Positioned: offset is already converted to px above, no change needed

    $newLines += $line
}

$newLines -join "`n" | Set-Content $path -NoNewline
Write-Output "Done. Lines: $($newLines.Count)"
