# Mobile Application Conventions

> **Priority**: HIGH - Apply to iOS/Android mobile apps  
> **Source**: RecipeArchive/Agents.md

## ⚠️ Critical Build Rules

### Never Modify Source In Place

```bash
# ❌ WRONG - modifying source during build
flutter build ios --dart-define=... > output.log

# ✅ CORRECT - build outputs to designated directories
flutter build ios --release  # Outputs to build/ios/
```

### Build Timeouts

Mobile builds take time. Set appropriate timeouts:

| Operation | Timeout | Notes |
|-----------|---------|-------|
| `pod install` | 10 min | Network-dependent |
| `flutter build ios` | 10 min | First build longer |
| `flutter build apk` | 10 min | Gradle can be slow |
| Gradle sync | 10 min | Dependency resolution |
| Xcode archive | 15 min | For release builds |

### Clean Build When Stuck

If builds fail unexpectedly:

```bash
# Flutter
flutter clean
flutter pub get
cd ios && pod install && cd ..

# iOS-specific
rm -rf ios/Pods ios/Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData

# Android-specific
cd android && ./gradlew clean && cd ..
```

## iOS Development

### Xcode Build

```bash
# Open in Xcode for native debugging
open ios/Runner.xcworkspace

# Build from command line
flutter build ios --release

# For simulator
flutter build ios --simulator
```

### CocoaPods Management

```bash
cd ios
pod install       # First time / after Podfile changes
pod update        # Update all pods
pod repo update   # Update pod specs repo
```

### Common iOS Issues

| Issue | Solution |
|-------|----------|
| Pod install fails | `pod repo update` then retry |
| Signing errors | Check Xcode signing settings |
| Module not found | Clean and rebuild |
| Simulator won't start | Reset simulator via menu |

## Android Development

### Gradle Build

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

### Gradle Issues

```bash
# Fix gradle wrapper issues
cd android
./gradlew wrapper --gradle-version=8.0

# Clear gradle cache
./gradlew clean
rm -rf ~/.gradle/caches/
```

## Cross-Platform Patterns

### Platform Detection

```dart
import 'dart:io';

if (Platform.isIOS) {
  // iOS-specific code
} else if (Platform.isAndroid) {
  // Android-specific code
}
```

### Responsive UI

```dart
// Use LayoutBuilder for responsive design
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 600) {
      return WideLayout();
    }
    return NarrowLayout();
  },
)
```

## Testing on Devices

### Simulators/Emulators

```bash
# List available simulators
flutter emulators

# Start emulator
flutter emulators --launch <emulator_id>

# Run on specific device
flutter run -d <device_id>
```

### Physical Devices

1. Enable Developer Mode on device
2. Connect via USB
3. Trust the computer (iOS)
4. Run `flutter devices` to verify
5. Run `flutter run -d <device_id>`

## Perplexity Escalation

**After 5 minutes OR 3 failed attempts** on build issues:
1. Stop trying to fix manually
2. Generate a Perplexity prompt with:
   - Exact error message
   - Flutter version (`flutter --version`)
   - Platform (iOS/Android)
   - Last successful build info
3. Ask: "Research how to fix [error] in Flutter [version] on [platform]"

