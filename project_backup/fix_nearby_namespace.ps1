$pluginPath = "C:\Users\Om Khanjodkar\AppData\Local\Pub\Cache\hosted\pub.dev\nearby_connections-3.3.1\android\build.gradle"

Write-Host "Fixing nearby_connections plugin namespace..." -ForegroundColor Yellow

if (Test-Path $pluginPath) {
    # Read the file
    $content = Get-Content $pluginPath -Raw
    
    # Check if namespace already exists
    if ($content -match "namespace") {
        Write-Host "✅ Namespace already exists in build.gradle" -ForegroundColor Green
    } else {
        # Add namespace after 'android {' line
        $content = $content -replace '(android\s*\{)', "`$1`n    namespace ''com.pkmnapps.nearby_connections''"
        
        # Write back to file
        Set-Content -Path $pluginPath -Value $content -NoNewline
        
        Write-Host "✅ Namespace added successfully!" -ForegroundColor Green
        Write-Host "   Added: namespace 'com.pkmnapps.nearby_connections'" -ForegroundColor Cyan
    }
} else {
    Write-Host "❌ Plugin file not found at: $pluginPath" -ForegroundColor Red
    Write-Host "   Make sure you've run 'flutter pub get' first" -ForegroundColor Yellow
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Run: flutter clean" -ForegroundColor White
Write-Host "2. Run: flutter run" -ForegroundColor White
