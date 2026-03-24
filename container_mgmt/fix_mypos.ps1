$path = "lib\screens\yard_screen.dart"
$content = Get-Content $path -Raw

$old = '        onPanEnd: (_) async {


          try { await _api.updateBlockPosition(block.blockId, myPos.dx, myPos.d'

$new = '        onPanEnd: (_) async {
          final myPos = _blockOffsets[block.blockId]!;
          try { await _api.updateBlockPosition(block.blockId, myPos.dx, myPos.d'

if ($content.Contains($old)) {
    $fixed = $content.Replace($old, $new)
    Set-Content $path $fixed -NoNewline
    Write-Output "Fixed"
} else {
    Write-Output "Pattern not found - trying alternate"
    # Show lines around onPanEnd
    $lines = Get-Content $path
    for ($i = 585; $i -le 598; $i++) {
        Write-Output "$($i+1): $($lines[$i])"
    }
}
