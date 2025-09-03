# Firebase Configuration Validation Script (PowerShell)
# Checks if the permanent Firebase setup is working correctly

Write-Host "🔍 Firebase Configuration Validator" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# Function to print colored output
function Write-Status {
    param($Message)
    Write-Host "[CHECK] $Message" -ForegroundColor Blue
}

function Write-Success {
    param($Message)
    Write-Host "[✓] $Message" -ForegroundColor Green
}

function Write-Warning {
    param($Message)
    Write-Host "[⚠] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param($Message)
    Write-Host "[✗] $Message" -ForegroundColor Red
}

# Check if we're in a Flutter project
if (!(Test-Path "pubspec.yaml")) {
    Write-Error "This script must be run from the root of a Flutter project"
    exit 1
}

$validationPassed = $true
$projectId = $null
$androidProjectId = $null
$iosProjectId = $null

# Check firebase_options.dart
Write-Status "Checking lib\firebase_options.dart..."
if (Test-Path "lib\firebase_options.dart") {
    $content = Get-Content "lib\firebase_options.dart" -Raw
    if ($content -match "v29bvc2fec6tbbyy7j9h4tddz1dq28") {
        Write-Warning "Still using placeholder project ID. Run permanent setup."
        $validationPassed = $false
    } else {
        # Extract project ID
        if ($content -match "projectId: '([^']+)'") {
            $projectId = $matches[1]
            Write-Success "Using real project ID: $projectId"
        } else {
            Write-Error "Could not extract project ID"
            $validationPassed = $false
        }
    }
} else {
    Write-Error "lib\firebase_options.dart not found"
    $validationPassed = $false
}

# Check Android configuration
Write-Status "Checking Android configuration..."
if (Test-Path "android\app\google-services.json") {
    $content = Get-Content "android\app\google-services.json" -Raw
    if ($content -match "v29bvc2fec6tbbyy7j9h4tddz1dq28") {
        Write-Warning "Android config still uses placeholder values"
        $validationPassed = $false
    } else {
        if ($content -match '"project_id":\s*"([^"]+)"') {
            $androidProjectId = $matches[1]
            Write-Success "Android config project ID: $androidProjectId"
        }
    }
} else {
    Write-Error "android\app\google-services.json not found"
    $validationPassed = $false
}

# Check iOS configuration
Write-Status "Checking iOS configuration..."
if (Test-Path "ios\Runner\GoogleService-Info.plist") {
    $content = Get-Content "ios\Runner\GoogleService-Info.plist" -Raw
    if ($content -match "v29bvc2fec6tbbyy7j9h4tddz1dq28") {
        Write-Warning "iOS config still uses placeholder values"
        $validationPassed = $false
    } else {
        if ($content -match "<key>PROJECT_ID</key>\s*<string>([^<]+)</string>") {
            $iosProjectId = $matches[1]
            Write-Success "iOS config project ID: $iosProjectId"
        }
    }
} else {
    Write-Warning "ios\Runner\GoogleService-Info.plist not found (iOS not configured)"
}

# Check project ID consistency
if ($projectId -and $androidProjectId) {
    if ($projectId -eq $androidProjectId) {
        Write-Success "Project IDs match between Flutter and Android configs"
    } else {
        Write-Error "Project ID mismatch: Flutter($projectId) vs Android($androidProjectId)"
        $validationPassed = $false
    }
}

if ($projectId -and $iosProjectId) {
    if ($projectId -eq $iosProjectId) {
        Write-Success "Project IDs match between Flutter and iOS configs"
    } else {
        Write-Error "Project ID mismatch: Flutter($projectId) vs iOS($iosProjectId)"
        $validationPassed = $false
    }
}

# Check for flutter dependencies
Write-Status "Checking Flutter dependencies..."
try {
    $null = & flutter pub deps 2>$null
    Write-Success "Flutter dependencies are satisfied"
} catch {
    Write-Warning "Flutter dependencies may need updating. Run: flutter pub get"
}

# Check for firebase.env (should not be needed for permanent setup)
if (Test-Path "firebase.env") {
    Write-Warning "firebase.env file found. Not needed for permanent setup."
    Write-Warning "You can remove it or keep it as backup for runtime override."
}

Write-Host ""
Write-Host "Validation Summary:" -ForegroundColor Cyan
Write-Host "=================="

if ($validationPassed) {
    Write-Success "✅ Firebase permanent setup appears to be configured correctly!"
    Write-Host ""
    Write-Host "You can now run your app with:" -ForegroundColor Green
    Write-Host "  flutter run" -ForegroundColor White
    Write-Host ""
    Write-Host "No need for --dart-define-from-file=firebase.env" -ForegroundColor Green
} else {
    Write-Error "❌ Issues found with Firebase configuration"
    Write-Host ""
    Write-Host "To fix these issues:" -ForegroundColor Yellow
    Write-Host "1. Run the permanent setup script: .\setup_firebase_permanent.ps1"
    Write-Host "2. Or follow manual setup in FIREBASE_PERMANENT_SETUP.md"
    Write-Host "3. Make sure you have a real Firebase project configured"
}

Write-Host ""
Write-Host "For more help, see FIREBASE_PERMANENT_SETUP.md" -ForegroundColor Cyan
