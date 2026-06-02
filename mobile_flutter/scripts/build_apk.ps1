# Genera APK release. Ejecutar desde la raíz del proyecto Flutter.
param(
    [string]$ApiBaseUrl = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path ".env")) {
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Host "Creado .env desde .env.example" -ForegroundColor Yellow
    } else {
        Write-Error "Falta .env. Copia .env.example a .env y configura API_BASE_URL."
    }
}

if ($ApiBaseUrl -ne "") {
    $content = Get-Content ".env" -Raw
    if ($content -match "API_BASE_URL=.*") {
        $content = $content -replace "API_BASE_URL=.*", "API_BASE_URL=$ApiBaseUrl"
    } else {
        $content += "`nAPI_BASE_URL=$ApiBaseUrl`n"
    }
    Set-Content ".env" $content.TrimEnd()
    Write-Host "API_BASE_URL=$ApiBaseUrl" -ForegroundColor Cyan
}

flutter pub get
flutter build apk --release

$apk = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apk) {
    Write-Host "`nAPK listo:" -ForegroundColor Green
    Write-Host $apk
} else {
    Write-Error "No se encontró el APK. Revisa errores de flutter build."
}
