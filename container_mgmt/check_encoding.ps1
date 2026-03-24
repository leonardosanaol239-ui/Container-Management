$path = "lib\screens\yard_screen.dart"
$lines = Get-Content $path
# Show lines 754-762 with char codes for hidden chars
for ($i = 753; $i -le 761; $i++) {
    $line = $lines[$i]
    $codes = ($line.ToCharArray() | ForEach-Object { [int]$_ }) -join ','
    Write-Output "Line $($i+1) [len=$($line.Length)]: $line"
    Write-Output "  chars: $codes"
}
