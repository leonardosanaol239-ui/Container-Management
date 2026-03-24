param([int]$from, [int]$count)
$lines = Get-Content "lib\screens\yard_screen.dart"
$end = [Math]::Min($from + $count - 1, $lines.Length - 1)
for ($i = $from; $i -le $end; $i++) {
    Write-Output "$($i+1): $($lines[$i])"
}
