# Dart/Flutter Coding Conventions

> **Priority**: HIGH - Apply to all Dart/Flutter projects  
> **Source**: RecipeArchive/Agents.md

## Code Quality Requirements

- **Linting**: `flutter analyze` or `dart analyze`
- **Testing**: `flutter test` with coverage
- **Formatting**: `dart format` (automated)

## AppLogger Structured Logging

**CRITICAL**: Use AppLogger for all logging. Never use raw `print()` or `debugPrint()`.

```dart
// Category-based loggers with privacy controls
class AppLogger {
  static final _auth = Logger('Auth');
  static final _api = Logger('API');
  static final _ui = Logger('UI');
  
  static void auth(String message, {bool sensitive = false}) {
    if (sensitive && !kDebugMode) return;  // Redact in release
    _auth.info(message);
  }
  
  static void api(String endpoint, {int? statusCode}) {
    _api.info('$endpoint -> $statusCode');
  }
}
```

### Logger Categories

| Category | Use For | Privacy |
|----------|---------|---------|
| `Auth` | Login, tokens, user sessions | HIGH - redact in release |
| `API` | Network requests, responses | MEDIUM - log endpoints only |
| `UI` | Navigation, user actions | LOW - safe to log |
| `Storage` | Database operations | MEDIUM - no user data |
| `Error` | Exceptions, crashes | HIGH - sanitize stack traces |

### Logging Rules

```dart
// ✅ Correct - category-based, privacy-aware
AppLogger.auth('User logged in', sensitive: true);
AppLogger.api('/recipes', statusCode: 200);
AppLogger.error('Failed to sync', error: e, stackTrace: s);

// ❌ Wrong - raw print
print('User logged in');  // Never use
debugPrint('API call');   // Never use
```

## Testing Patterns

```dart
void main() {
  group('RecipeRepository', () {
    late MockApiClient mockApi;
    late RecipeRepository repository;
    
    setUp(() {
      mockApi = MockApiClient();
      repository = RecipeRepository(api: mockApi);
    });
    
    test('fetches recipes successfully', () async {
      when(() => mockApi.get('/recipes')).thenAnswer(
        (_) async => Response(data: [{'id': 1}]),
      );
      
      final recipes = await repository.fetchAll();
      
      expect(recipes, hasLength(1));
      verify(() => mockApi.get('/recipes')).called(1);
    });
    
    test('throws on network error', () async {
      when(() => mockApi.get('/recipes')).thenThrow(NetworkException());
      
      expect(
        () => repository.fetchAll(),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
```

## Widget Testing

```dart
testWidgets('shows loading indicator', (tester) async {
  await tester.pumpWidget(
    MaterialApp(home: RecipeListScreen()),
  );
  
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  
  // Wait for async operations
  await tester.pumpAndSettle();
  
  expect(find.byType(CircularProgressIndicator), findsNothing);
});
```

## Commands

```bash
# Analyze code
flutter analyze

# Run tests with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Format code
dart format lib test

# Check outdated packages
flutter pub outdated
```

## Platform-Specific Patterns

### iOS Build

```bash
cd ios
pod install
flutter build ios --release
```

### Android Build

```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

## ⚠️ Build Timeouts

Mobile builds can take time. Use **10-minute timeout** for:
- `pod install`
- `flutter build ios`
- `flutter build apk`
- Gradle sync operations

If build times out, check for:
- Corrupt build cache (`flutter clean`)
- Xcode/Gradle updates needed
- Network issues fetching dependencies

