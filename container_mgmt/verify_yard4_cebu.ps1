# ============================================================================
# Verify Yard 4 in Cebu Port Setup
# ============================================================================
# This script verifies that Yard 4 is properly set up in Cebu Port with Y4.png
# ============================================================================

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "VERIFYING YARD 4 IN CEBU PORT SETUP" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

$AllChecks = @()
$PassedChecks = 0
$FailedChecks = 0

# ============================================================================
# Check 1: SQL Server Connection
# ============================================================================
Write-Host "CHECK 1: SQL Server Connection" -ForegroundColor Yellow
try {
    $result = sqlcmd -S localhost -E -Q "SELECT @@VERSION" -h -1 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ SQL Server is accessible" -ForegroundColor Green
        $PassedChecks++
    } else {
        Write-Host "  ❌ Cannot connect to SQL Server" -ForegroundColor Red
        $FailedChecks++
    }
} catch {
    Write-Host "  ❌ SQL Server connection failed: $_" -ForegroundColor Red
    $FailedChecks++
}
Write-Host ""

# ============================================================================
# Check 2: Database Exists
# ============================================================================
Write-Host "CHECK 2: ContainerManagement Database" -ForegroundColor Yellow
try {
    $result = sqlcmd -S localhost -E -Q "SELECT name FROM sys.databases WHERE name = 'ContainerManagement'" -h -1 2>&1
    if ($result -match "ContainerManagement") {
        Write-Host "  ✅ ContainerManagement database exists" -ForegroundColor Green
        $PassedChecks++
    } else {
        Write-Host "  ❌ ContainerManagement database not found" -ForegroundColor Red
        $FailedChecks++
    }
} catch {
    Write-Host "  ❌ Database check failed: $_" -ForegroundColor Red
    $FailedChecks++
}
Write-Host ""

# ============================================================================
# Check 3: Cebu Port Exists
# ============================================================================
Write-Host "CHECK 3: Cebu Port (PortId = 2)" -ForegroundColor Yellow
try {
    $query = "SELECT PortId, PortDesc FROM Ports WHERE PortId = 2"
    $result = sqlcmd -S localhost -d ContainerManagement -E -Q $query -h -1 2>&1
    if ($result -match "Cebu") {
        Write-Host "  ✅ Cebu Port exists" -ForegroundColor Green
        Write-Host "     $result" -ForegroundColor Gray
        $PassedChecks++
    } else {
        Write-Host "  ❌ Cebu Port not found" -ForegroundColor Red
        $FailedChecks++
    }
} catch {
    Write-Host "  ❌ Cebu Port check failed: $_" -ForegroundColor Red
    $FailedChecks++
}
Write-Host ""

# ============================================================================
# Check 4: Yard 4 Exists in Cebu Port
# ============================================================================
Write-Host "CHECK 4: Yard 4 in Cebu Port" -ForegroundColor Yellow
try {
    $query = "SELECT YardId, YardNumber, PortId FROM Yards WHERE PortId = 2 AND YardNumber = 4"
    $result = sqlcmd -S localhost -d ContainerManagement -E -Q $query -h -1 2>&1
    if ($result -match "4.*2" -or $result -match "2.*4") {
        Write-Host "  ✅ Yard 4 exists in Cebu Port" -ForegroundColor Green
        $PassedChecks++
    } else {
        Write-Host "  ❌ Yard 4 not found in Cebu Port" -ForegroundColor Red
        Write-Host "     Run: .\run_add_yard4_cebu.ps1" -ForegroundColor Yellow
        $FailedChecks++
    }
} catch {
    Write-Host "  ❌ Yard 4 check failed: $_" -ForegroundColor Red
    $FailedChecks++
}
Write-Host ""

# ============================================================================
# Check 5: ImagePath is Y4.png
# ============================================================================
Write-Host "CHECK 5: ImagePath = 'Y4.png'" -ForegroundColor Yellow
try {
    $query = "SELECT ImagePath FROM Yards WHERE PortId = 2 AND YardNumber = 4"
    $result = sqlcmd -S localhost -d ContainerManagement -E -Q $query -h -1 2>&1
    if ($result -match "Y4\.png") {
        Write-Host "  ✅ ImagePath is set to 'Y4.png'" -ForegroundColor Green
        $PassedChecks++
    } else {
        Write-Host "  ❌ ImagePath is not 'Y4.png'" -ForegroundColor Red
        Write-Host "     Current value: $result" -ForegroundColor Gray
        Write-Host "     Run: .\run_add_yard4_cebu.ps1" -ForegroundColor Yellow
        $FailedChecks++
    }
} catch {
    Write-Host "  ❌ ImagePath check failed: $_" -ForegroundColor Red
    $FailedChecks++
}
Write-Host ""

# ============================================================================
# Check 6: Y4.png Asset File Exists
# ============================================================================
Write-Host "CHECK 6: Y4.png Asset File" -ForegroundColor Yellow
if (Test-Path "assets/Y4.png") {
    Write-Host "  ✅ assets/Y4.png exists" -ForegroundColor Green
    $fileInfo = Get-Item "assets/Y4.png"
    Write-Host "     Size: $($fileInfo.Length) bytes" -ForegroundColor Gray
    $PassedChecks++
} else {
    Write-Host "  ❌ assets/Y4.png not found" -ForegroundColor Red
    $FailedChecks++
}
Write-Host ""

# ============================================================================
# Check 7: pubspec.yaml Configuration
# ============================================================================
Write-Host "CHECK 7: pubspec.yaml Configuration" -ForegroundColor Yellow
if (Test-Path "pubspec.yaml") {
    $pubspecContent = Get-Content "pubspec.yaml" -Raw
    if ($pubspecContent -match "assets/Y4\.png") {
        Write-Host "  ✅ Y4.png is listed in pubspec.yaml" -ForegroundColor Green
        $PassedChecks++
    } else {
        Write-Host "  ❌ Y4.png not found in pubspec.yaml" -ForegroundColor Red
        Write-Host "     Add this line under flutter > assets:" -ForegroundColor Yellow
        Write-Host "       - assets/Y4.png" -ForegroundColor Yellow
        $FailedChecks++
    }
} else {
    Write-Host "  ❌ pubspec.yaml not found" -ForegroundColor Red
    $FailedChecks++
}
Write-Host ""

# ============================================================================
# Check 8: All Cebu Yards Summary
# ============================================================================
Write-Host "CHECK 8: All Cebu Port Yards Summary" -ForegroundColor Yellow
try {
    $query = @"
SELECT 
    YardNumber, 
    ImagePath,
    CASE 
        WHEN ImagePath = 'Y4.png' THEN 'OK'
        WHEN ImagePath IS NULL THEN 'NULL'
        ELSE 'DIFFERENT'
    END AS Status
FROM Yards 
WHERE PortId = 2 
ORDER BY YardNumber
"@
    Write-Host "  Cebu Port Yards:" -ForegroundColor Cyan
    sqlcmd -S localhost -d ContainerManagement -E -Q $query -W
    $PassedChecks++
} catch {
    Write-Host "  ❌ Failed to retrieve Cebu yards: $_" -ForegroundColor Red
    $FailedChecks++
}
Write-Host ""

# ============================================================================
# Summary
# ============================================================================
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "VERIFICATION SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

$TotalChecks = $PassedChecks + $FailedChecks
$SuccessRate = [math]::Round(($PassedChecks / $TotalChecks) * 100, 1)

Write-Host "Total Checks: $TotalChecks" -ForegroundColor White
Write-Host "Passed: $PassedChecks" -ForegroundColor Green
Write-Host "Failed: $FailedChecks" -ForegroundColor $(if ($FailedChecks -eq 0) { "Green" } else { "Red" })
Write-Host "Success Rate: $SuccessRate%" -ForegroundColor $(if ($SuccessRate -eq 100) { "Green" } elseif ($SuccessRate -ge 75) { "Yellow" } else { "Red" })
Write-Host ""

if ($FailedChecks -eq 0) {
    Write-Host "============================================================================" -ForegroundColor Green
    Write-Host "✅ ALL CHECKS PASSED!" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Yard 4 in Cebu Port is properly configured with Y4.png!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Run: flutter pub get" -ForegroundColor White
    Write-Host "2. Restart your Flutter app (not hot reload)" -ForegroundColor White
    Write-Host "3. Navigate to Cebu Port > Yard 4" -ForegroundColor White
    Write-Host "4. Verify Y4.png is displayed as background" -ForegroundColor White
} else {
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host "⚠️ SOME CHECKS FAILED" -ForegroundColor Red
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please review the failed checks above and take corrective action." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Common Solutions:" -ForegroundColor Yellow
    Write-Host "- If Yard 4 doesn't exist: Run .\run_add_yard4_cebu.ps1" -ForegroundColor White
    Write-Host "- If ImagePath is wrong: Run .\run_add_yard4_cebu.ps1" -ForegroundColor White
    Write-Host "- If SQL Server issues: Check SQL Server service is running" -ForegroundColor White
    Write-Host "- If asset issues: Verify assets/Y4.png exists" -ForegroundColor White
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan

# Exit with appropriate code
exit $FailedChecks
