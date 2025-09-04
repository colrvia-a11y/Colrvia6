# Firebase Permanent Setup Script (PowerShell)
# This script automates the permanent Firebase configuration setup on Windows

param(
    [switch]$Force,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Firebase Permanent Setup Script

This script helps you set up Firebase with real credentials for long-term use.

Usage:
  .\setup_firebase_permanent.ps1 [-Force] [-Help]

Parameters:
  -Force    Skip confirmation prompts
  -Help     Show this help message

Prerequisites:
  - Flutter and Dart installed
  - A real Firebase project
  - Internet connection
"@
    exit 0
}

# Function to print colored output
function Write-Status {
    param($Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param($Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param($Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param($Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

Write-Host "🔥 Firebase Permanent Setup Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Check if we're in a Flutter project
if (!(Test-Path "pubspec.yaml")) {
    Write-Error "This script must be run from the root of a Flutter project"
    exit 1
}

Write-Status "Checking Flutter project structure..."

# Check for required directories
if (!(Test-Path "android\app")) {
    Write-Error "Android directory not found. Is this a Flutter project?"
    exit 1
}

if (!(Test-Path "ios\Runner")) {
    Write-Warning "iOS directory not found. iOS configuration will be skipped."
}

Write-Success "Flutter project structure validated"

# Check if FlutterFire CLI is installed
Write-Status "Checking FlutterFire CLI installation..."

try {
    $null = & dart pub global list | Select-String "flutterfire_cli"
    Write-Success "FlutterFire CLI is already installed"
} catch {
    Write-Warning "FlutterFire CLI not found. Installing..."
    
    try {
        & dart pub global activate flutterfire_cli
        Write-Success "FlutterFire CLI installed successfully"
    } catch {
        Write-Error "Failed to install FlutterFire CLI"
        exit 1
    }
}

# Check if Firebase CLI is installed
Write-Status "Checking Firebase CLI installation..."

try {
    $null = & firebase --version
    Write-Success "Firebase CLI is available"
} catch {
    Write-Warning "Firebase CLI not found. Please install it first:"
    Write-Host "  npm install -g firebase-tools"
    Write-Host "  or visit: https://firebase.google.com/docs/cli#install_the_firebase_cli"
    exit 1
}

# Check if user is logged in to Firebase
Write-Status "Checking Firebase authentication..."

try {
    $null = & firebase projects:list 2>$null
} catch {
    Write-Warning "You are not logged in to Firebase. Please login first:"
    Write-Host ""
    Write-Host "Run: firebase login"
    Write-Host ""
    if (!$Force) {
        Read-Host "Press Enter after logging in to continue"
    }
}

# Backup existing configuration files
Write-Status "Backing up existing configuration files..."

$backupDir = "firebase_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

# Backup lib/firebase_options.dart
if (Test-Path "lib\firebase_options.dart") {
    Copy-Item "lib\firebase_options.dart" $backupDir
    Write-Success "Backed up lib\firebase_options.dart"
}

# Backup Android config
if (Test-Path "android\app\google-services.json") {
    Copy-Item "android\app\google-services.json" $backupDir
    Write-Success "Backed up android\app\google-services.json"
}

# Backup iOS config
if (Test-Path "ios\Runner\GoogleService-Info.plist") {
    Copy-Item "ios\Runner\GoogleService-Info.plist" $backupDir
    Write-Success "Backed up ios\Runner\GoogleService-Info.plist"
}

Write-Success "Configuration files backed up to: $backupDir"

# Run FlutterFire configure
Write-Status "Running FlutterFire configuration..."
Write-Host ""
Write-Host "Please select your Firebase project and choose the platforms you want to configure." -ForegroundColor Cyan
Write-Host "Recommended: Select all platforms (Android, iOS, Web, macOS, Windows)" -ForegroundColor Cyan
Write-Host ""

try {
    & flutterfire configure
    Write-Success "FlutterFire configuration completed successfully"
} catch {
    Write-Error "FlutterFire configuration failed"
    
    # Restore backups
    Write-Status "Restoring backup files..."
    if (Test-Path "$backupDir\firebase_options.dart") {
        Copy-Item "$backupDir\firebase_options.dart" "lib\"
    }
    if (Test-Path "$backupDir\google-services.json") {
        Copy-Item "$backupDir\google-services.json" "android\app\"
    }
    if (Test-Path "$backupDir\GoogleService-Info.plist") {
        Copy-Item "$backupDir\GoogleService-Info.plist" "ios\Runner\"
    }
    
    exit 1
}

# Verify the configuration
Write-Status "Verifying configuration..."

# Check if firebase_options.dart was updated
if (Test-Path "lib\firebase_options.dart") {
    $content = Get-Content "lib\firebase_options.dart" -Raw
    if ($content -match "v29bvc2fec6tbbyy7j9h4tddz1dq28") {
        Write-Warning "lib\firebase_options.dart still contains placeholder values"
        Write-Warning "FlutterFire configure may not have completed properly"
    } else {
        Write-Success "lib\firebase_options.dart updated with real configuration"
    }
} else {
    Write-Error "lib\firebase_options.dart not found after configuration"
}

# Check Android configuration
if (Test-Path "android\app\google-services.json") {
    $content = Get-Content "android\app\google-services.json" -Raw
    if ($content -match "v29bvc2fec6tbbyy7j9h4tddz1dq28") {
        Write-Warning "android\app\google-services.json still contains placeholder values"
    } else {
        Write-Success "android\app\google-services.json updated with real configuration"
    }
}

# Check iOS configuration
if (Test-Path "ios\Runner\GoogleService-Info.plist") {
    $content = Get-Content "ios\Runner\GoogleService-Info.plist" -Raw
    if ($content -match "v29bvc2fec6tbbyy7j9h4tddz1dq28") {
        Write-Warning "ios\Runner\GoogleService-Info.plist still contains placeholder values"
    } else {
        Write-Success "ios\Runner\GoogleService-Info.plist updated with real configuration"
    }
}

# Clean and get dependencies
Write-Status "Cleaning and getting dependencies..."

try {
    & flutter clean
    & flutter pub get
    Write-Success "Dependencies updated successfully"
} catch {
    Write-Warning "Failed to update dependencies. You may need to run 'flutter clean && flutter pub get' manually"
}

# Final instructions
Write-Host ""
Write-Host "🎉 Firebase permanent setup completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Test your app: flutter run"
Write-Host "2. Enable Authentication in Firebase Console:"
Write-Host "   - Go to Authentication > Sign-in method"
Write-Host "   - Enable Email/Password provider"
Write-Host "3. Set up Firestore security rules (see FIREBASE_PERMANENT_SETUP.md)"
Write-Host "4. Remove any firebase.env files (no longer needed)"
Write-Host ""
Write-Host "If you encounter issues:" -ForegroundColor Yellow
Write-Host "- Check FIREBASE_PERMANENT_SETUP.md for troubleshooting"
Write-Host "- Restore from backup: $backupDir"
Write-Host ""
Write-Success "Setup complete!"
