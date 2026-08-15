# راهنمای GitHub Actions برای Flutter Plugin Package

> **هدف:** هر بار که پکیج Flutter جدید می‌نویسی، این فایل را مرور کن تا CI از اول اوکی باشه.

---

## ۱. چک‌لیست قبل از اولین Push

### ۱.۱ iOS — هماهنگی Deployment Target (مهم‌ترین)

یکی از رایج‌ترین دلایل شکست CI، ناهماهنگی deployment target بین این سه فایل است:

| فایل | مکان | چه می‌کند |
|---|---|---|
| `Package.swift` | `ios/PLUGIN_NAME/Package.swift` | deployment target برای Swift Package Manager |
| `*.podspec` | `ios/*.podspec` | deployment target برای CocoaPods (CI از این استفاده می‌کند) |
| `project.pbxproj` | `example/ios/Runner.xcodeproj/project.pbxproj` | deployment target برای example app |

**قانون طلایی:** هر سه باید یک عدد یکسان داشته باشند.

```ruby
# *.podspec
s.platform = :ios, '14.0'
```

```swift
// Package.swift
platforms: [
    .iOS("14.0")
],
```

```
# project.pbxproj (سه بار باید این مقدار باشد)
IPHONEOS_DEPLOYMENT_TARGET = 14.0;
```

> دام مهم: Podfile در .gitignore است و در CI وجود ندارد.
> پس deployment target حتماً از project.pbxproj خوانده می‌شود.

---

### ۱.۲ iOS — قوانین Swift API Availability

هر API که در نسخه‌های بالاتر iOS اضافه شده باید گارد داشته باشد:

```swift
// درست
if #available(iOS 14, *) {
    safe.success(status == .authorized || status == .limited)
} else {
    safe.success(status == .authorized)
}

// اشتباه — بدون گارد کامپایل نمی‌شود
safe.success(status == .authorized || status == .limited)
```

| Framework | حداقل iOS | نکته |
|---|---|---|
| `UniformTypeIdentifiers` (UTType) | iOS 14 | از `MobileCoreServices` برای iOS 13 استفاده کن |
| `PHAuthorizationStatus.limited` | iOS 14 | در PHPhotoLibrary |
| `PHPhotoLibrary.requestAuthorization(for:)` | iOS 14 | نسخه قدیم بدون for: برای iOS 13 |

---

### ۱.۳ macOS — هماهنگی Deployment Target

```ruby
# *.podspec
s.platform = :osx, '10.14'
```

```swift
// Package.swift
platforms: [
    .macOS("10.14")
],
```

---

### ۱.۴ Android — نکات مهم

```groovy
// android/build.gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21   // با pubspec.yaml هماهنگ کن
        targetSdkVersion 34
    }
}
```

---

## ۲. ساختار صحیح GitHub Actions Workflow

### ۲.۱ قانون کلی: بیلد به جای تست Integration

**روش قدیمی (مشکل‌دار):**
```yaml
- name: Run integration tests on iOS Simulator
  run: flutter test integration_test/... -d "$SIMULATOR_UDID"
```
مشکل: نیاز به simulator بوت، code signing، حدود ۵ دقیقه زمان

**روش صحیح:**
```yaml
- name: Build iOS example app (no code signing)
  working-directory: example
  run: flutter build ios --no-codesign --debug
```
اگر build شد = پکیج OK است. بدون simulator، بدون signing، حدود ۱ دقیقه.

---

### ۲.۲ Template کامل iOS — فایل: `.github/workflows/ios_build.yml`

```yaml
name: iOS Build Check

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

jobs:
  ios-build:
    name: Build iOS Example App
    runs-on: macos-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x.x'
          channel: 'stable'
          cache: true

      - name: Install dependencies (plugin root)
        run: flutter pub get

      - name: Analyze Dart/Flutter code
        run: flutter analyze --no-fatal-infos

      - name: Run unit tests
        run: flutter test --reporter=expanded

      - name: Install dependencies (example app)
        working-directory: example
        run: flutter pub get

      - name: Build iOS example app (no code signing)
        working-directory: example
        run: flutter build ios --no-codesign --debug
```

---

### ۲.۳ Template کامل Android — فایل: `.github/workflows/android_build.yml`

```yaml
name: Android Build Check

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

jobs:
  android-build:
    name: Build Android Example App
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x.x'
          channel: 'stable'
          cache: true

      - name: Install dependencies (plugin root)
        run: flutter pub get

      - name: Analyze Dart/Flutter code
        run: flutter analyze --no-fatal-infos

      - name: Run unit tests
        run: flutter test --reporter=expanded

      - name: Install dependencies (example app)
        working-directory: example
        run: flutter pub get

      - name: Build Android APK (example app)
        working-directory: example
        run: flutter build apk --debug
```

---

### ۲.۴ Template کامل macOS — فایل: `.github/workflows/macos_build.yml`

```yaml
name: macOS Build Check

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

jobs:
  macos-build:
    name: Build macOS Example App
    runs-on: macos-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x.x'
          channel: 'stable'
          cache: true

      - name: Install dependencies (plugin root)
        run: flutter pub get

      - name: Analyze Dart/Flutter code
        run: flutter analyze --no-fatal-infos

      - name: Run unit tests
        run: flutter test --reporter=expanded

      - name: Install dependencies (example app)
        working-directory: example
        run: flutter pub get

      - name: Build macOS example app
        working-directory: example
        run: flutter build macos --debug
```

---

### ۲.۵ Template Dart Unit Tests — فایل: `.github/workflows/dart_tests.yml`

```yaml
name: Dart Unit Tests

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

jobs:
  dart-tests:
    name: Dart Unit Tests
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x.x'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Run static analysis
        run: flutter analyze --no-fatal-infos

      - name: Run unit tests with coverage
        run: flutter test --coverage --reporter=expanded

      - name: Upload coverage (optional)
        uses: codecov/codecov-action@v4
        with:
          file: coverage/lcov.info
```

---

## ۳. چک‌لیست نهایی قبل از Push

```
[ ] pubspec.yaml    --> version دارد (مثلاً 0.1.0+1)
[ ] pubspec.yaml    --> sdk: '>=3.0.0 <4.0.0'
[ ] ios/*.podspec   --> s.platform با Package.swift یکسان است
[ ] project.pbxproj --> IPHONEOS_DEPLOYMENT_TARGET یکسان با podspec
[ ] Swift APIs      --> همه API های جدید داخل #available() گارد شدند
[ ] Android APIs    --> داخل Build.VERSION.SDK_INT چک شدند
[ ] flutter analyze --> صفر error
[ ] flutter test    --> همه پاس
[ ] flutter build ios --no-codesign --debug  --> موفق (تست لوکال)
[ ] flutter build apk --debug                --> موفق (تست لوکال)
[ ] example/lib/main.dart --> وجود دارد و runApp دارد
[ ] .github/workflows/    --> workflow فایل‌ها وجود دارند
```

---

## ۴. خطاهای رایج و راه‌حل سریع

| خطا | علت | راه‌حل |
|---|---|---|
| `'limited' is only available in iOS 14` | deployment target کمتر از 14 | podspec و pbxproj را به 14.0 برسان |
| `Module 'Foundation' has no member 'UTType'` | UniformTypeIdentifiers روی iOS 13 | deployment target را به 14.0 برسان |
| `Missing build name (CFBundleShortVersionString)` | نسخه در pubspec.yaml نیست | version: 0.1.0+1 به pubspec اضافه کن |
| `Could not build the application for the simulator` | deployment target مغشوش | podspec / Package.swift / pbxproj را هم‌تراز کن |
| `No Flutter engine found` | flutter pub get در example نشده | مرحله Install dependencies (example app) اضافه کن |
| `fatal: path example/ios/Podfile does not exist` | Podfile در .gitignore است | طبیعی است؛ deployment target را در pbxproj بگذار |
| CI هنوز step قدیمی نشان می‌دهد | لاگ از قبل از commit است | آخرین run در GitHub Actions را چک کن |

---

## ۵. فلوچارت تشخیص مشکل CI

```
CI شکست خورد
     |
     |-- Swift Compiler Error?
     |        |
     |        |-- "only available in iOS X"
     |        |        --> deployment target را در podspec و pbxproj بالا ببر
     |        |
     |        +-- "Module has no member"
     |                 --> deployment target را بالا ببر یا #available گارد اضافه کن
     |
     |-- "Could not build the application for the simulator"
     |        --> از flutter build ios --no-codesign --debug استفاده کن
     |
     |-- "Missing build name/number"
     |        --> version: x.y.z+n را به pubspec.yaml اضافه کن
     |
     +-- Dart Analyze Error?
              --> flutter analyze را لوکال اجرا کن
```

---

*این سند از درس‌های واقعی پروژه `media_manager` استخراج شده است.*
