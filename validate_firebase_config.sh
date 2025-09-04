#!/bin/bash

# Firebase Configuration Validation Script
# Checks if the permanent Firebase setup is working correctly

echo "🔍 Firebase Configuration Validator"
echo "==================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if we're in a Flutter project
if [ ! -f "pubspec.yaml" ]; then
    print_error "This script must be run from the root of a Flutter project"
    exit 1
fi

validation_passed=true

# Check firebase_options.dart
print_status "Checking lib/firebase_options.dart..."
if [ -f "lib/firebase_options.dart" ]; then
    if grep -q "v29bvc2fec6tbbyy7j9h4tddz1dq28" "lib/firebase_options.dart"; then
        print_warning "Still using placeholder project ID. Run permanent setup."
        validation_passed=false
    else
        # Extract project ID
        project_id=$(grep -o "projectId: '[^']*'" "lib/firebase_options.dart" | head -1 | cut -d"'" -f2)
        if [ -n "$project_id" ]; then
            print_success "Using real project ID: $project_id"
        else
            print_error "Could not extract project ID"
            validation_passed=false
        fi
    fi
else
    print_error "lib/firebase_options.dart not found"
    validation_passed=false
fi

# Check Android configuration
print_status "Checking Android configuration..."
if [ -f "android/app/google-services.json" ]; then
    if grep -q "v29bvc2fec6tbbyy7j9h4tddz1dq28" "android/app/google-services.json"; then
        print_warning "Android config still uses placeholder values"
        validation_passed=false
    else
        android_project_id=$(grep -o '"project_id": "[^"]*"' "android/app/google-services.json" | cut -d'"' -f4)
        print_success "Android config project ID: $android_project_id"
    fi
else
    print_error "android/app/google-services.json not found"
    validation_passed=false
fi

# Check iOS configuration
print_status "Checking iOS configuration..."
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    if grep -q "v29bvc2fec6tbbyy7j9h4tddz1dq28" "ios/Runner/GoogleService-Info.plist"; then
        print_warning "iOS config still uses placeholder values"
        validation_passed=false
    else
        ios_project_id=$(grep -A1 "<key>PROJECT_ID</key>" "ios/Runner/GoogleService-Info.plist" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        print_success "iOS config project ID: $ios_project_id"
    fi
else
    print_warning "ios/Runner/GoogleService-Info.plist not found (iOS not configured)"
fi

# Check project ID consistency
if [ -n "$project_id" ] && [ -n "$android_project_id" ]; then
    if [ "$project_id" = "$android_project_id" ]; then
        print_success "Project IDs match between Flutter and Android configs"
    else
        print_error "Project ID mismatch: Flutter($project_id) vs Android($android_project_id)"
        validation_passed=false
    fi
fi

if [ -n "$project_id" ] && [ -n "$ios_project_id" ]; then
    if [ "$project_id" = "$ios_project_id" ]; then
        print_success "Project IDs match between Flutter and iOS configs"
    else
        print_error "Project ID mismatch: Flutter($project_id) vs iOS($ios_project_id)"
        validation_passed=false
    fi
fi

# Check for flutter dependencies
print_status "Checking Flutter dependencies..."
if flutter pub deps > /dev/null 2>&1; then
    print_success "Flutter dependencies are satisfied"
else
    print_warning "Flutter dependencies may need updating. Run: flutter pub get"
fi

# Check for firebase.env (should not be needed for permanent setup)
if [ -f "firebase.env" ]; then
    print_warning "firebase.env file found. Not needed for permanent setup."
    print_warning "You can remove it or keep it as backup for runtime override."
fi

echo ""
echo "Validation Summary:"
echo "=================="

if [ "$validation_passed" = true ]; then
    print_success "✅ Firebase permanent setup appears to be configured correctly!"
    echo ""
    echo "You can now run your app with:"
    echo "  flutter run"
    echo ""
    echo "No need for --dart-define-from-file=firebase.env"
else
    print_error "❌ Issues found with Firebase configuration"
    echo ""
    echo "To fix these issues:"
    echo "1. Run the permanent setup script: ./setup_firebase_permanent.sh"
    echo "2. Or follow manual setup in FIREBASE_PERMANENT_SETUP.md"
    echo "3. Make sure you have a real Firebase project configured"
fi

echo ""
echo "For more help, see FIREBASE_PERMANENT_SETUP.md"
