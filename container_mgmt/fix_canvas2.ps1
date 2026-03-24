$path = "lib\screens\yard_screen.dart"
$lines = Get-Content $path

# Find _buildCanvas start and end
$start = -1; $end = -1; $depth = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s+Widget _buildCanvas\(\)') { $start = $i; $depth = 0 }
    if ($start -ge 0) {
        $depth += ($lines[$i].ToCharArray() | Where-Object { $_ -eq '{' }).Count
        $depth -= ($lines[$i].ToCharArray() | Where-Object { $_ -eq '}' }).Count
        if ($depth -eq 0 -and $i -gt $start) { $end = $i; break }
    }
}
Write-Output "Found _buildCanvas: lines $($start+1) to $($end+1)"

# Also find and remove the static canvas fields + scale getters
$removeLines = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'static const double _canvasW' -or
        $lines[$i] -match 'static const double _canvasH' -or
        $lines[$i] -match 'double get _scaleX =>' -or
        $lines[$i] -match 'double get _scaleY =>') {
        $removeLines += $i
        Write-Output "Will remove line $($i+1): $($lines[$i])"
    }
}

# Build replacement for _buildCanvas
$newCanvas = @(
'  Widget _buildCanvas() {',
'    final yardW = (widget.yard.yardWidth  ?? 300).toDouble();',
'    final yardH = (widget.yard.yardHeight ?? 170).toDouble();',
'    return LayoutBuilder(builder: (ctx, constraints) {',
'      final availW = constraints.maxWidth  == double.infinity ? 800.0 : constraints.maxWidth;',
'      final availH = constraints.maxHeight == double.infinity ? 500.0 : constraints.maxHeight;',
'      // Uniform scale: fit entire yard in viewport, preserve real-world proportions',
'      final fitScale = (availW / yardW) < (availH / yardH) ? (availW / yardW) : (availH / yardH);',
'      WidgetsBinding.instance.addPostFrameCallback((_) {',
'        if (mounted && (_scale - fitScale).abs() > 0.01) setState(() => _scale = fitScale);',
'      });',
'      final cw = yardW * _scale;',
'      final ch = yardH * _scale;',
'      return ClipRRect(',
'        borderRadius: BorderRadius.circular(8),',
'        child: Container(',
'          color: Colors.grey[200],',
'          child: InteractiveViewer(',
'            minScale: 0.3, maxScale: 6.0, panEnabled: !_editMode,',
'            child: SizedBox(width: cw, height: ch,',
'              child: Stack(children: [',
'                Positioned.fill(child: Container(',
'                  decoration: BoxDecoration(color: Colors.grey[300], border: Border.all(color: Colors.grey, width: 1)),',
'                  child: CustomPaint(painter: _YardGridPainter()),',
'                )),',
'                ..._blocks.map((b) => _buildPositionedBlock(b)),',
'                if (_foundContainer != null && _foundContainer!.rowId != null)',
'                  Positioned(top: 8, right: 8,',
'                    child: _SearchResultCard(container: _foundContainer!, blocks: _blocks, baysByBlock: _baysByBlock, rowsByBay: _rowsByBay, onClose: _clearSearch)),',
'              ]),',
'            ),',
'          ),',
'        ),',
'      );',
'    });',
'  }'
)

# Build new file
$newLines = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($i -in $removeLines) { continue }  # skip removed lines
    if ($i -eq $start) {
        $newLines += $newCanvas
        continue
    }
    if ($i -gt $start -and $i -le $end) { continue }  # skip old _buildCanvas body
    $newLines += $lines[$i]
}

# Now add the _scale field and computed getters after _showMoveOutList
$finalLines = @()
for ($i = 0; $i -lt $newLines.Count; $i++) {
    $finalLines += $newLines[$i]
    if ($newLines[$i] -match 'bool _showMoveOutList = false;') {
        $finalLines += '  double _scale = 3.0;'
        $finalLines += '  double get _canvasW => (widget.yard.yardWidth  ?? 300) * _scale;'
        $finalLines += '  double get _canvasH => (widget.yard.yardHeight ?? 170) * _scale;'
        $finalLines += '  double get _scaleX  => _scale;'
        $finalLines += '  double get _scaleY  => _scale;'
        Write-Output "Inserted scale fields after _showMoveOutList"
    }
}

$finalLines -join "`n" | Set-Content $path -NoNewline
Write-Output "Done. Total lines: $($finalLines.Count)"
