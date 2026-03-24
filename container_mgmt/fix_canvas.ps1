$path = "lib\screens\yard_screen.dart"
$content = Get-Content $path -Raw

# 1. Remove static canvas constants and computed scale getters
$content = $content -replace '  static const double _canvasW = \d+\.0;\r?\n', ''
$content = $content -replace '  static const double _canvasH = \d+\.0;\r?\n', ''
$content = $content -replace '  double get _scaleX => _canvasW / \(widget\.yard\.yardWidth \?\? 300\);\r?\n', ''
$content = $content -replace '  double get _scaleY => _canvasH / \(widget\.yard\.yardHeight \?\? 170\);\r?\n', ''

# 2. Add instance fields for scale and canvas size (set by LayoutBuilder)
$oldField = '  bool _showMoveOutList = false;'
$newField = '  bool _showMoveOutList = false;
  // Computed by LayoutBuilder to fit viewport while preserving ft proportions
  double _scale = 3.0;   // px per foot, updated in _buildCanvas
  double get _canvasW => (widget.yard.yardWidth  ?? 300) * _scale;
  double get _canvasH => (widget.yard.yardHeight ?? 170) * _scale;
  double get _scaleX  => _scale;
  double get _scaleY  => _scale;'
$content = $content.Replace($oldField, $newField)

# 3. Replace _buildCanvas to use LayoutBuilder for scale computation
$oldCanvas = '  Widget _buildCanvas() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.grey[200],
        child: InteractiveViewer(
          minScale: 0.4, maxScale: 4.0, panEnabled: !_editMode,
          child: SizedBox(width: _canvasW, height: _canvasH,
            child: Stack(children: [
              Positioned.fill(child: Container(
                decoration: BoxDecoration(color: Colors.grey[300], border: Bord
der.all(color: Colors.grey, width: 1)),
                child: CustomPaint(painter: _YardGridPainter()),
              )),
              ..._blocks.map((b) => _buildPositionedBlock(b)),
              if (_foundContainer != null && _foundContainer!.rowId != null)   
                Positioned(top: 8, right: 8,
                  child: _SearchResultCard(container: _foundContainer!, blocks:
: _blocks, baysByBlock: _baysByBlock, rowsByBay: _rowsByBay, onClose: _clearSearch)),
            ]),
          ),
        ),
      ),
    );
  }'

$newCanvas = '  Widget _buildCanvas() {
    final yardW = (widget.yard.yardWidth  ?? 300).toDouble();
    final yardH = (widget.yard.yardHeight ?? 170).toDouble();
    return LayoutBuilder(builder: (ctx, constraints) {
      // Fit the yard into the available space, uniform scale, preserve aspect ratio
      final availW = constraints.maxWidth  == double.infinity ? 800.0 : constraints.maxWidth;
      final availH = constraints.maxHeight == double.infinity ? 500.0 : constraints.maxHeight;
      final newScale = (availW / yardW).clamp(0.5, availH / yardH < availW / yardW
          ? availH / yardH
          : availW / yardW);
      // Use the smaller of the two fit-scales so the whole yard is visible
      final fitScale = (availW / yardW) < (availH / yardH)
          ? availW / yardW
          : availH / yardH;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_scale - fitScale).abs() > 0.01) {
          setState(() => _scale = fitScale);
        }
      });
      final cw = yardW * _scale;
      final ch = yardH * _scale;
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: Colors.grey[200],
          child: InteractiveViewer(
            minScale: 0.3, maxScale: 6.0, panEnabled: !_editMode,
            child: SizedBox(width: cw, height: ch,
              child: Stack(children: [
                Positioned.fill(child: Container(
                  decoration: BoxDecoration(color: Colors.grey[300], border: Border.all(color: Colors.grey, width: 1)),
                  child: CustomPaint(painter: _YardGridPainter()),
                )),
                ..._blocks.map((b) => _buildPositionedBlock(b)),
                if (_foundContainer != null && _foundContainer!.rowId != null)
                  Positioned(top: 8, right: 8,
                    child: _SearchResultCard(container: _foundContainer!, blocks: _blocks, baysByBlock: _baysByBlock, rowsByBay: _rowsByBay, onClose: _clearSearch)),
              ]),
            ),
          ),
        ),
      );
    });
  }'

if ($content.Contains($oldCanvas)) {
    $content = $content.Replace($oldCanvas, $newCanvas)
    Write-Output "Replaced _buildCanvas"
} else {
    Write-Output "ERROR: _buildCanvas pattern not found - trying partial match"
    # Check if the method exists at all
    if ($content -match '_buildCanvas') {
        Write-Output "Method exists but pattern mismatch - manual inspection needed"
    }
}

Set-Content $path $content -NoNewline
Write-Output "Done"
