$path = "lib\screens\yard_screen.dart"
$content = Get-Content $path -Raw

# Fix: remove width: double.infinity from the block label Container at the bottom of horizontal block
# Replace the specific Container with width: double.infinity with one that uses no width
$old = '          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: headerBg,
            child: Text(blockLabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: borderColor)),
          ),'

$new = '          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: headerBg,
            child: Text(blockLabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: borderColor)),
          ),'

if ($content.Contains($old)) {
    $fixed = $content.Replace($old, $new)
    Set-Content $path $fixed -NoNewline
    Write-Output "Fixed: removed width: double.infinity from block label Container"
} else {
    Write-Output "Pattern not found - checking for variant..."
    # Try without trailing comma
    $old2 = '          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: headerBg,
            child: Text(blockLabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: borderColor)),
          )'
    if ($content.Contains($old2)) {
        $new2 = '          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: headerBg,
            child: Text(blockLabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: borderColor)),
          )'
        $fixed = $content.Replace($old2, $new2)
        Set-Content $path $fixed -NoNewline
        Write-Output "Fixed (variant): removed width: double.infinity"
    } else {
        Write-Output "ERROR: Could not find pattern to replace"
    }
}

# Verify
Write-Output ""
Write-Output "=== Remaining 'width: double.infinity' in yard_screen.dart ==="
Select-String -Path $path -Pattern "width: double.infinity"
