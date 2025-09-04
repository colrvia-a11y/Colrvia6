#!/bin/bash

# Firebase Permanent Setup Script
# This script automates the permanent Firebase configuration setup

set -e  # Exit on any error

echo "🔥 Firebase Permanent Setup Script"
echo "================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in a Flutter project
if [ ! -f "pubspec.yaml" ]; then
    print_error "This script must be run from the root of a Flutter project"
    exit 1
fi

print_status "Checking Flutter project structure..."

# Check for required directories
if [ ! -d "android/app" ]; then
    print_error "Android directory not found. Is this a Flutter project?"
    exit 1
fi

if [ ! -d "ios/Runner" ]; then
    print_warning "iOS directory not found. iOS configuration will be skipped."
fi

print_success "Flutter project structure validated"

# Check if FlutterFire CLI is installed
print_status "Checking FlutterFire CLI installation..."

if ! command -v flutterfire &> /dev/null; then
    print_warning "FlutterFire CLI not found. Installing..."
    
    # Install FlutterFire CLI
    if dart pub global activate flutterfire_cli; then
        print_success "FlutterFire CLI installed successfully"
    else
        print_error "Failed to install FlutterFire CLI"
        exit 1
    fi
else
    print_success "FlutterFire CLI is already installed"
fi

# Check if Firebase CLI is installed
print_status "Checking Firebase CLI installation..."

if ! command -v firebase &> /dev/null; then
    print_warning "Firebase CLI not found. Please install it first:"
    echo "  npm install -g firebase-tools"
    echo "  or visit: https://firebase.google.com/docs/cli#install_the_firebase_cli"
    exit 1
else
    print_success "Firebase CLI is available"
fi

# Check if user is logged in to Firebase
print_status "Checking Firebase authentication..."

if ! firebase projects:list &> /dev/null; then
    print_warning "You are not logged in to Firebase. Please login first:"
    echo ""
    echo "Run: firebase login"
    echo ""
    read -p "Press Enter after logging in to continue..."
fi

# Backup existing configuration files
print_status "Backing up existing configuration files..."

backup_dir="firebase_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# Backup lib/firebase_options.dart
if [ -f "lib/firebase_options.dart" ]; then
    cp "lib/firebase_options.dart" "$backup_dir/"
    print_success "Backed up lib/firebase_options.dart"
fi

# Backup Android config
if [ -f "android/app/google-services.json" ]; then
    cp "android/app/google-services.json" "$backup_dir/"
    print_success "Backed up android/app/google-services.json"
fi

# Backup iOS config
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    cp "ios/Runner/GoogleService-Info.plist" "$backup_dir/"
    print_success "Backed up ios/Runner/GoogleService-Info.plist"
fi

print_success "Configuration files backed up to: $backup_dir"

# Run FlutterFire configure
print_status "Running FlutterFire configuration..."
echo ""
echo "Please select your Firebase project and choose the platforms you want to configure."
echo "Recommended: Select all platforms (Android, iOS, Web, macOS, Windows)"
echo ""

if flutterfire configure; then
    print_success "FlutterFire configuration completed successfully"
else
    print_error "FlutterFire configuration failed"
    
    # Restore backups
    print_status "Restoring backup files..."
    if [ -f "$backup_dir/firebase_options.dart" ]; then
        cp "$backup_dir/firebase_options.dart" "lib/"
    fi
    if [ -f "$backup_dir/google-services.json" ]; then
        cp "$backup_dir/google-services.json" "android/app/"
    fi
    if [ -f "$backup_dir/GoogleService-Info.plist" ]; then
        cp "$backup_dir/GoogleService-Info.plist" "ios/Runner/"
    fi
    
    exit 1
fi

# Verify the configuration
print_status "Verifying configuration..."

# Check if firebase_options.dart was updated
if [ -f "lib/firebase_options.dart" ]; then
    if grep -q "v29bvc2fec6tbbyy7j9h4tddz1dq28" "lib/firebase_options.dart"; then
        print_warning "lib/firebase_options.dart still contains placeholder values"
        print_warning "FlutterFire configure may not have completed properly"
    else
        print_success "lib/firebase_options.dart updated with real configuration"
    fi
else
    print_error "lib/firebase_options.dart not found after configuration"
fi

# Check Android configuration
if [ -f "android/app/google-services.json" ]; then
    if grep -q "v29bvc2fec6tbbyy7j9h4tddz1dq28" "android/app/google-services.json"; then
        print_warning "android/app/google-services.json still contains placeholder values"
    else
        print_success "android/app/google-services.json updated with real configuration"
    fi
fi

# Check iOS configuration
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    if grep -q "v29bvc2fec6tbbyy7j9h4tddz1dq28" "ios/Runner/GoogleService-Info.plist"; then
        print_warning "ios/Runner/GoogleService-Info.plist still contains placeholder values"
    else
        print_success "ios/Runner/GoogleService-Info.plist updated with real configuration"
    fi
fi

# Clean and get dependencies
print_status "Cleaning and getting dependencies..."

if flutter clean && flutter pub get; then
    print_success "Dependencies updated successfully"
else
    print_warning "Failed to update dependencies. You may need to run 'flutter clean && flutter pub get' manually"
fi

# Final instructions
echo ""
echo "🎉 Firebase permanent setup completed!"
echo ""
echo "Next steps:"
echo "1. Test your app: flutter run"
echo "2. Enable Authentication in Firebase Console:"
echo "   - Go to Authentication > Sign-in method"
echo "   - Enable Email/Password provider"
echo "3. Set up Firestore security rules (see FIREBASE_PERMANENT_SETUP.md)"
echo "4. Remove any firebase.env files (no longer needed)"
echo ""
echo "If you encounter issues:"
echo "- Check FIREBASE_PERMANENT_SETUP.md for troubleshooting"
echo "- Restore from backup: $backup_dir"
echo ""
print_success "Setup complete!"
