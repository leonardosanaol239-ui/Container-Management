$path = "lib\screens\yard_screen.dart"
$lines = Get-Content $path

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "onWillAcceptWithDetails: \(d\) => !d\.data\.isMovedOut && inYard\.length < m") {
        # Next line has the rest - combine check
        $lines[$i] = $lines[$i] -replace "onWillAcceptWithDetails: \(d\) => !d\.data\.isMovedOut && inYard\.length < m", "onWillAcceptWithDetails: (d) => !editMode && !d.data.isMovedOut && inYard.length < m"
        Write-Output "Fixed DragTarget at line $($i+1)"
    }
}

$lines -join "`n" | Set-Content $path -NoNewline
Write-Output "Done"
