# Build release version with environment variables from .env file
# Usage: .\build_release.ps1 [apk|apk-split|appbundle|all]

param(
    [string]$Target = "apk"
)

# Read .env file
$envFile = ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^(.+?)=(.+)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
            Write-Host "Loaded: $name = ***" -ForegroundColor DarkGray
        }
    }
    Write-Host "Environment variables loaded from .env" -ForegroundColor Green
} else {
    Write-Error ".env file not found!"
    exit 1
}

# Build dart-define arguments
$defines = @()
if ($env:COUNTLY_SERVER_URL) {
    $defines += "--dart-define=COUNTLY_SERVER_URL=`"$env:COUNTLY_SERVER_URL`""
}
if ($env:COUNTLY_APP_KEY) {
    $defines += "--dart-define=COUNTLY_APP_KEY=`"$env:COUNTLY_APP_KEY`""
}

# Build based on target
switch ($Target.ToLower()) {
    "apk" { $cmd = "flutter build apk --release" }
    "apk-split" { $cmd = "flutter build apk --release --split-per-abi" }
    "appbundle" { $cmd = "flutter build appbundle --release" }
    "all" {
        Write-Host "Building all Android targets..." -ForegroundColor Magenta
        & flutter build apk --release @defines
        & flutter build apk --release --split-per-abi @defines
        & flutter build appbundle --release @defines
        if ($LASTEXITCODE -eq 0) {
            Write-Host "All builds completed successfully!" -ForegroundColor Green
        } else {
            Write-Error "Build failed!"
        }
        exit 0
    }
    default {
        Write-Error "Unknown target: $Target"
        Write-Host "Valid targets: apk, apk-split, appbundle, all"
        exit 1
    }
}

Write-Host "Building: $cmd with dart-defines" -ForegroundColor Cyan
& flutter build $Target --release @defines

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build completed successfully!" -ForegroundColor Green
} else {
    Write-Error "Build failed!"
}
