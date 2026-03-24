$path = "lib\screens\yard_screen.dart"
$lines = Get-Content $path

# ── 1. Add onAddRow / onRemoveRow fields after onDeleteBlock ──────────────────
$newLines = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    $newLines += $lines[$i]
    if ($lines[$i] -match '^\s+final VoidCallback\? onDeleteBlock;$') {
        $newLines += '  final VoidCallback? onAddRow;'
        $newLines += '  final VoidCallback? onRemoveRow;'
        Write-Output "Added onAddRow/onRemoveRow fields at line $($i+1)"
    }
}
$lines = $newLines

# ── 2. Add onAddRow/onRemoveRow to constructor params after onDeleteBlock ─────
$newLines = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    $newLines += $lines[$i]
    if ($lines[$i] -match '^\s+this\.onDeleteBlock,$') {
        $newLines += '    this.onAddRow,'
        $newLines += '    this.onRemoveRow,'
        Write-Output "Added constructor params at line $($i+1)"
    }
}
$lines = $newLines

# ── 3. Rewrite VERTICAL block layout ─────────────────────────────────────────
# Find the vertical return Row( block and replace it
$vertStart = -1; $vertEnd = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^\s+return Row\(" -and $vertStart -eq -1) {
        # Check context: look back for isVert
        for ($j = [Math]::Max(0,$i-5); $j -lt $i; $j++) {
            if ($lines[$j] -match 'if \(isVert\)') { $vertStart = $i; break }
        }
    }
    if ($vertStart -ge 0 -and $vertEnd -eq -1) {
        # find matching closing of this return Row(
        $depth = 0
        for ($j = $vertStart; $j -lt $lines.Count; $j++) {
            $depth += ($lines[$j].ToCharArray() | Where-Object {$_ -eq '('}).Count
            $depth -= ($lines[$j].ToCharArray() | Where-Object {$_ -eq ')'}).Count
            if ($depth -eq 0 -and $j -gt $vertStart) {
                # check next non-empty line is '} else {'
                $vertEnd = $j
                break
            }
        }
        break
    }
}
Write-Output "Vertical block: lines $($vertStart+1) to $($vertEnd+1)"

$newVert = @(
'      // VERTICAL layout:',
'      // - Row buttons (add/remove row) at TOP-LEFT',
'      // - Block name rotated on left',
'      // - Slots + bay labels',
'      // - Bay buttons (add/remove bay) at BOTTOM-RIGHT',
'      return Column(',
'        mainAxisSize: MainAxisSize.min,',
'        crossAxisAlignment: CrossAxisAlignment.start,',
'        children: [',
'          // Top: row +/- buttons at top-left',
'          if (editMode)',
'            Row(mainAxisSize: MainAxisSize.min, children: [',
'              GestureDetector(onTap: onAddRow,    child: const Icon(Icons.add_circle,    size: 18, color: Colors.green)),',
'              GestureDetector(onTap: onRemoveRow, child: const Icon(Icons.remove_circle, size: 18, color: Colors.orange)),',
'            ]),',
'          // Middle: block name + slots',
'          Row(',
'            mainAxisSize: MainAxisSize.min,',
'            crossAxisAlignment: CrossAxisAlignment.start,',
'            children: [',
'              // Block name rotated on the left',
'              RotatedBox(',
'                quarterTurns: 3,',
'                child: Container(',
'                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),',
'                  color: headerBg,',
'                  child: Text(blockLabel,',
'                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: borderColor)),',
'                ),',
'              ),',
'              // Bays + bay labels',
'              Container(',
'                decoration: BoxDecoration(',
'                  color: bgColor,',
'                  border: Border.all(color: borderColor, width: 1.5),',
'                  borderRadius: BorderRadius.circular(4),',
'                ),',
'                child: Column(mainAxisSize: MainAxisSize.min, children: bayRows),',
'              ),',
'            ],',
'          ),',
'          // Bottom: bay +/- buttons at bottom-right',
'          if (editMode)',
'            Row(mainAxisSize: MainAxisSize.max, mainAxisAlignment: MainAxisAlignment.end, children: [',
'              GestureDetector(onTap: onAddBay,    child: const Icon(Icons.add_circle,    size: 18, color: Colors.green)),',
'              GestureDetector(onTap: onRemoveBay, child: const Icon(Icons.remove_circle, size: 18, color: Colors.orange)),',
'            ]),',
'        ],',
'      );'
)

# ── 4. Rewrite HORIZONTAL block layout ───────────────────────────────────────
# Find the horizontal return Container( block
$horizStart = -1; $horizEnd = -1
for ($i = $vertEnd+1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^\s+return Container\(") {
        $horizStart = $i
        $depth = 0
        for ($j = $horizStart; $j -lt $lines.Count; $j++) {
            $depth += ($lines[$j].ToCharArray() | Where-Object {$_ -eq '('}).Count
            $depth -= ($lines[$j].ToCharArray() | Where-Object {$_ -eq ')'}).Count
            if ($depth -eq 0 -and $j -gt $horizStart) { $horizEnd = $j; break }
        }
        break
    }
}
Write-Output "Horizontal block: lines $($horizStart+1) to $($horizEnd+1)"

$newHoriz = @(
'      // HORIZONTAL layout:',
'      // - Bay +/- buttons at TOP-RIGHT',
'      // - Bay labels + slots',
'      // - Block name at bottom',
'      // - Row +/- buttons at BOTTOM-LEFT',
'      return Container(',
'        decoration: BoxDecoration(',
'          color: bgColor,',
'          border: Border.all(color: borderColor, width: 1.5),',
'          borderRadius: BorderRadius.circular(4),',
'        ),',
'        child: Column(mainAxisSize: MainAxisSize.min, children: [',
'          // Top row: bay +/- on right',
'          if (editMode)',
'            Row(mainAxisAlignment: MainAxisAlignment.end, children: [',
'              GestureDetector(onTap: onAddBay,    child: const Icon(Icons.add_circle,    size: 18, color: Colors.green)),',
'              const SizedBox(width: 2),',
'              GestureDetector(onTap: onRemoveBay, child: const Icon(Icons.remove_circle, size: 18, color: Colors.orange)),',
'            ]),',
'          // Columns with bay labels + slots',
'          Row(mainAxisSize: MainAxisSize.min, children: cols),',
'          // Block name at bottom',
'          Container(',
'            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),',
'            color: headerBg,',
'            child: Text(blockLabel,',
'                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: borderColor)),',
'          ),',
'          // Bottom row: row +/- on left',
'          if (editMode)',
'            Row(mainAxisAlignment: MainAxisAlignment.start, children: [',
'              GestureDetector(onTap: onAddRow,    child: const Icon(Icons.add_circle,    size: 18, color: Colors.green)),',
'              const SizedBox(width: 2),',
'              GestureDetector(onTap: onRemoveRow, child: const Icon(Icons.remove_circle, size: 18, color: Colors.orange)),',
'            ]),',
'        ]),',
'      );'
)

# ── 5. Build final file ───────────────────────────────────────────────────────
$finalLines = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($i -eq $vertStart) {
        foreach ($l in $newVert) { $finalLines += $l }
        $i = $vertEnd  # skip old vert block
        continue
    }
    if ($i -eq $horizStart) {
        foreach ($l in $newHoriz) { $finalLines += $l }
        $i = $horizEnd  # skip old horiz block
        continue
    }
    $finalLines += $lines[$i]
}

$finalLines -join "`n" | Set-Content $path -NoNewline
Write-Output "Done. Lines: $($finalLines.Count)"
