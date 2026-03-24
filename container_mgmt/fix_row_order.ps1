$path = "lib\screens\yard_screen.dart"
$content = Get-Content $path -Raw

$old = '        final rows = rowsByBay[bay.bayId] ?? [];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...rows.map((row) => slotCell(row)),
            // Bay label on the right'

$new = '        final rows = (rowsByBay[bay.bayId] ?? []).reversed.toList();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...rows.map((row) => slotCell(row)),
            // Bay label on the right (= row 1 is rightmost = "top" in real world)'

if ($content.Contains($old)) {
    $fixed = $content.Replace($old, $new)
    Set-Content $path $fixed -NoNewline
    Write-Output "Fixed: rows now reversed so row 1 is rightmost (closest to bay label)"
} else {
    Write-Output "ERROR: pattern not found"
}
