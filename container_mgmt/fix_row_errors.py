import re

with open('lib/screens/yard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix onAddRow line - restore proper $e interpolation
old_add = "onAddRow: _editMode ? () async { try { await _api.addRow(block.blockId); await _loadAll(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add row failed: \\'), duration: const Duration(seconds: 4))); } } : null,"
new_add = "onAddRow: _editMode ? () async { try { await _api.addRow(block.blockId); await _loadAll(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot add row: $e'), duration: const Duration(seconds: 4))); } } : null,"

# Fix onRemoveRow line
old_rem = "onRemoveRow: _editMode ? () async { try { await _api.removeRow(block.blockId); await _loadAll(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Remove row failed: \\'), duration: const Duration(seconds: 4))); } } : null,"
new_rem = "onRemoveRow: _editMode ? () async { try { await _api.removeRow(block.blockId); await _loadAll(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot remove row: $e'), duration: const Duration(seconds: 4))); } } : null,"

if old_add in content:
    content = content.replace(old_add, new_add)
    print("Fixed onAddRow")
else:
    print("onAddRow pattern not found - trying partial match")
    # Try to find and fix by pattern
    content = re.sub(
        r"onAddRow: _editMode \? \(\) async \{ try \{ await _api\.addRow\(block\.blockId\); await _loadAll\(\); \} catch \(e\) \{ if \(mounted\) ScaffoldMessenger\.of\(context\)\.showSnackBar\(SnackBar\(content: Text\('[^']*'\), duration: const Duration\(seconds: 4\)\)\); \} \} : null,",
        new_add,
        content
    )
    print("Applied regex fix for onAddRow")

if old_rem in content:
    content = content.replace(old_rem, new_rem)
    print("Fixed onRemoveRow")
else:
    print("onRemoveRow pattern not found - trying partial match")
    content = re.sub(
        r"onRemoveRow: _editMode \? \(\) async \{ try \{ await _api\.removeRow\(block\.blockId\); await _loadAll\(\); \} catch \(e\) \{ if \(mounted\) ScaffoldMessenger\.of\(context\)\.showSnackBar\(SnackBar\(content: Text\('[^']*'\), duration: const Duration\(seconds: 4\)\)\); \} \} : null,",
        new_rem,
        content
    )
    print("Applied regex fix for onRemoveRow")

with open('lib/screens/yard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
