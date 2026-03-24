$path = "lib\screens\yard_screen.dart"
$lines = Get-Content $path

$newLines = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    $newLines += $lines[$i]
    # After the onDeleteBlock closing }: null, insert onAddRow/onRemoveRow
    if ($lines[$i] -match "^\s+\} : null,$" -and $i -gt 0) {
        # Check if previous context has onDeleteBlock
        $ctx = ($lines[($i-6)..($i)] -join ' ')
        if ($ctx -match 'onDeleteBlock') {
            $newLines += ''
            $newLines += '      onAddRow: _editMode ? () async { try { await _api.addRow(block.blockId); await _loadAll(); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(''Cannot add row''))); } } : null,'
            $newLines += ''
            $newLines += '      onRemoveRow: _editMode ? () async { try { await _api.removeRow(block.blockId); await _loadAll(); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(''Cannot remove row''))); } } : null,'
            Write-Output "Wired onAddRow/onRemoveRow after line $($i+1)"
        }
    }
}

$newLines -join "`n" | Set-Content $path -NoNewline
Write-Output "Done. Lines: $($newLines.Count)"
