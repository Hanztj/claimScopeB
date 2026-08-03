$privateRepo = "C:\flutter_projects\Hanz"
$publicRepo  = "C:\flutter_projects\claimScopeB"

Write-Host "Cleaning public repo..." -ForegroundColor Cyan

# Limpia el repositorio público respetando la carpeta .git para no romper el historial de Git
Get-ChildItem $publicRepo -Exclude ".git" | Remove-Item -Recurse -Force

Write-Host "Copying files securely..." -ForegroundColor Cyan

# Ejecución de robocopy con todas las exclusiones de seguridad y compilación
# Se agregó "functions\node_modules" a /XD y ".env.claim-scope" a /XF
robocopy $privateRepo $publicRepo /MIR `
 /XD ".git" "build" ".dart_tool" ".gradle" ".idea" ".vscode" "lib\secrets" "android\app\keys" "functions\node_modules" `
 /XF ".env" ".env.production" ".env.claim-scope" "google-services.json" "GoogleService-Info.plist" "firebase_options.dart" "stripe_keys.dart" "local.properties" "key.properties" ".firebaserc" "*.keystore" "*.jks"

# Nota: Robocopy usa códigos de salida (Exit Codes) del 0 al 3 para indicar éxito (copiado exitoso o sin cambios).
if ($LASTEXITCODE -le 3) {
    Write-Host "Done. Public repository updated securely." -ForegroundColor Green
} else {
    Write-Host "Robocopy finished with warnings or errors. Exit Code: $LASTEXITCODE" -ForegroundColor Yellow
}