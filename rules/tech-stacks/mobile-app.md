# Mobile App Development

## Scope

- **Technologies**: React Native, Flutter, Native (Swift/Kotlin)
- **Use Cases**:
  - New mobile app project kickoff
  - Mobile-specific quality standards & performance optimization
  - Store distribution & device compatibility

## Quick Reference

| Task | Command | Frequency | Notes |
|------|---------|-----------|-------|
| Dev Start (Expo) | `npx expo start` | 99% | Recommended React Native framework |
| Dev Start (Legacy) | `npm start` / `flutter run` | 90% | Metro Bundler / Hot Reload |
| iOS Device | `npm run ios` / `flutter run -d ios` | 90% | Simulator launch |
| Android Device | `npm run android` / `flutter run -d android` | 90% | Emulator launch |
| Release Build | `eas build` / `flutter build ios` | 90% | Store distribution |
| Auto Deploy | `fastlane ios beta` / `fastlane android beta` | 80% | TestFlight / Play Console |
| Security | MMKV / Keychain/KeyStore | Required | Encrypted storage |
| Optimization | WebP + FlashList | Required | Performance maximization |

## Tech Stack Selection

### Decision Matrix (ICE Score)

| Criteria | React Native | Flutter | Native | Weight |
|----------|--------------|---------|--------|--------|
| **Dev Speed** | 9 | 8 | 3 | 3x |
| **Performance** | 6 | 8 | 10 | 2x |
| **Ease of Learning** | 8 | 6 | 4 | 1x |
| **Ecosystem** | 9 | 7 | 10 | 2x |
| **Long-term Maintenance** | 7 | 7 | 9 | 2x |
| **Weighted Total** | 78 | 74 | 76 | - |

### Selection Criteria

| Condition | Recommendation |
|-----------|----------------|
| Web tech leverage, existing React code | React Native + Expo |
| High-performance UI, native feel | Flutter |
| Maximum performance, platform-specific features | Native |
| Team: Web developers | React Native + Expo |
| Team: Mobile specialists | Native |
| Prototype, MVP development | React Native + Expo / Flutter |
| Games, high FPS requirements | Native / Flutter |
| Rapid development & deployment | React Native + Expo |

**React Native Recommendation**:
- Use Expo (official recommended framework, EAS Build for CI/CD, easy setup)
- OTA Updates via EAS Update (paid service — requires Expo subscription; not free)
- Consider bare React Native only for specialized native modules not supported by Expo

### New Architecture (React Native 0.74+)

React Native New Architecture is enabled by default since RN 0.74:

- **JSI (JavaScript Interface)**: Replaces the Bridge — synchronous JS↔Native communication, no serialization overhead
- **Fabric**: New rendering system — synchronous UI updates, reduced layout passes
- **Hermes**: Default JS engine since RN 0.70 — faster startup, lower memory, bytecode precompilation
- **Expo Router**: File-based routing for Expo apps (App Router equivalent) — recommended for all new Expo projects

**Migration Note**: New Architecture is on by default in RN 0.74+. Verify library compatibility before upgrading (`npx react-native-new-architecture-helper`).

## Quality Standards

### Device Support

**Minimum Support Version (minSdkVersion / Deployment Target)**:
- **iOS**: Latest 2 versions + 1 previous major version (iOS 17+ as of 2026)
- **Android**: API 26+ (Android 8.0+) recommended — API 21 covers <1% of active devices (2026 data)
- **Screen Sizes**: All devices (iPhone SE ~ iPad Pro, various Android)

**Store Distribution Requirements (targetSdkVersion / SDK)**:
- **iOS**: Latest Xcode + latest iOS SDK required for builds (min deployment target can be older)
- **Android**: API 35 (Android 15) required for new apps submitted to Google Play since August 2025
- **Note**: Build SDK ≠ support version (SDK = build time, minSdk = runtime minimum)

### Performance Standards & Optimization

**Measurement Criteria**:
- App Size: < 50MB initial download (mainstream apps); games/AI apps may exceed — use Android App Bundle / on-demand resources
- Launch Time: < 2s (cold start)
- FPS: Maintain 60fps (scrolling, animations), 120fps for ProMotion displays
- Memory: Appropriate range, leak prevention

**Optimization Techniques**:
- **Images**: WebP format, appropriate size, lazy loading
- **Lists**:
  - React Native: Shopify's `FlashList` (recommended, 5-10x faster than FlatList) or `FlatList`
  - Flutter: `ListView.builder` with virtualization
- **Memory**: useEffect cleanup, remove unused listeners
- **Network**: Caching, offline support, optimized API calls

**Bundle Size Reduction**:
```bash
# React Native
npx react-native-bundle-visualizer

# Flutter
flutter build apk --analyze-size
flutter build ios --analyze-size
```

**Common Patterns**:
- Image optimization: PNG → WebP conversion, remove unnecessary high-res images
- Remove unused libraries: moment → dayjs (66KB → 2KB)
- ProGuard/R8 optimization: Enable for Android release builds
- Lazy loading: Essential data only at startup, others in background
- List optimization: FlatList → FlashList (React Native), large dataset support

### Test Strategy

**Test Layers**:

| Layer | Purpose | Tools | Coverage Target |
|-------|---------|-------|-----------------|
| **Unit Tests** | Logic/function validation | Jest/Vitest, flutter_test | 70-80% |
| **Component Tests** | UI component validation | React Testing Library, Widget Testing | 60-70% |
| **E2E Tests** | Flow validation on device/emulator | Detox, Maestro, flutter_driver | 3+ critical user flows |

**React Native**:
- **Unit**: Jest + `@testing-library/react-native`
- **E2E**: Detox (recommended, fast), Maestro (simple YAML-based), Appium (cross-platform)
- **Mocking**: `jest.mock()`, mocks for `@react-native-community/netinfo`, etc.

**Flutter**:
- **Unit**: `flutter_test` (standard)
- **Widget**: `WidgetTester`
- **Integration**: `integration_test` (recommended), `flutter_driver` (legacy)

**Implementation Patterns**:
- TDD: Red (failing test) → Green (minimal implementation) → Refactor (improve)
- Test automation: Run all tests in CI/CD pipeline
- Snapshot testing: Detect unintended UI changes

## Security

### Data Protection

**Local Storage**:
- **Recommended (Sensitive Data)**:
  - `react-native-mmkv` (encryption support, 30x faster than AsyncStorage)
  - `react-native-encrypted-storage` (iOS Keychain + Android KeyStore)
  - `expo-secure-store` (Expo projects)
  - Flutter: `flutter_secure_storage`
- **Non-Sensitive Data**:
  - React Native: `react-native-mmkv` (no encryption, ultra-fast)
  - Flutter: `Hive`, `shared_preferences`
- **Deprecated**: `AsyncStorage` (no encryption, slow, prohibited for sensitive data)

**Sensitive Information Management**:
- **Auth Tokens**: Store in Keychain/KeyStore
- **API Communication**: Bearer token (HTTP headers), prohibit URL parameters
- **Refresh Tokens**: Implement rotation pattern

**Certificate Pinning**:
- **Apply**: High-security apps only (banking, healthcare, payments)
- **Recommended**: Public Key Pinning (works during certificate renewal)
- **Libraries**: `react-native-ssl-pinning`, `TrustKit`
- **Required Feature**: Emergency unpin mechanism (for certificate rotation emergencies)

### Permission Management

**Patterns**:
- **Android**: `PermissionsAndroid.request()` + required explanation text
- **iOS**: Set `NSCameraUsageDescription` etc. in `Info.plist`
- **Unified Library**: `react-native-permissions`, Flutter `permission_handler`
- **Rejection Handling**: Required fallback feature or manual input option

### Code Protection

**Android (ProGuard/R8)**:
```proguard
# Security optimization rules
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
-repackageclasses
```

**iOS**:
- Bitcode: Deprecated since Xcode 14 (2022) and removed from App Store — do not enable

**JavaScript/Dart**:
- React Native: Bundle obfuscation (limited effectiveness — keep sensitive logic in native layer)
- Flutter: Compiled to native ARM code (better protection than JS bundles)

**Root/Jailbreak Detection (Optional)**:
- **Use Case**: Banking/payment apps
- **Libraries**: `react-native-root-detection`, Flutter `flutter_jailbreak_detection`

### OWASP Mobile Top 10 Compliance

| Risk | Countermeasure |
|------|----------------|
| M1: Improper Platform Usage | Follow permission request patterns |
| M2: Insecure Data Storage | Use Keychain/KeyStore, prohibit AsyncStorage |
| M3: Insecure Communication | Certificate pinning, HTTPS required |
| M4: Insecure Authentication | Token rotation, biometric auth |
| M5: Insufficient Cryptography | AES-256, use standard libraries |
| M9: Reverse Engineering | ProGuard/R8 + sensitive logic in native layer |

## Development & Operations

### Post-Edit Mandatory Checks

**Recommended execution order (React Native)**:
```bash
# 1. TypeScript type check
npx tsc --noEmit

# 2. Linter (auto-fix)
npx eslint . --ext .ts,.tsx --fix

# 3. Unit tests
npm test -- --watchAll=false
```

**Flutter equivalent**:
```bash
dart analyze
flutter test
```

**Time-constrained cases**:
```bash
# Minimum (within 30s): type check + lint
npx tsc --noEmit && npx eslint . --ext .ts,.tsx

# Standard (within 2min): above + unit tests
npx tsc --noEmit && npx eslint . --ext .ts,.tsx && npm test -- --watchAll=false

# Complete: above + build check (slow, CI/CD only)
eas build --platform all --local
```

### Monitoring & Crash Analytics

**Crash Analytics**:

| Tool | Features | Recommended Use |
|------|----------|-----------------|
| **Firebase Crashlytics** | Free, real-time, detailed stack traces | First choice (iOS/Android support) |
| **Sentry** | Open source, self-hostable, detailed analysis | Privacy-focused, customizable |
| **Bugsnag** | Paid, feature-rich, excellent UI | Enterprise |

**Performance Monitoring**:
- **Firebase Performance**: Launch time, network latency, screen rendering
- **New Relic Mobile**: APM, detailed performance analysis
- **Custom Metrics**: App-specific indicators (business logic execution time, etc.)

**React Native**:
- `@react-native-firebase/crashlytics` (recommended)
- `@sentry/react-native`

**Flutter**:
- `firebase_crashlytics` (recommended)
- `sentry_flutter`

**Implementation Patterns**:
- Enable only in production (disable during development)
- Record user identifiers (privacy consideration)
- Add custom logs/breadcrumbs
- Monitor crash reproduction rate (severity determination)

### Debug & Troubleshooting

**Debug Tools**:

| Tool | Purpose | Support |
|------|---------|---------|
| **React DevTools** | Component hierarchy, state inspection | React Native |
| **Flutter DevTools** | Widget tree, performance | Flutter |
| **Flipper** | Network, logs, layout inspection | React Native / Flutter |
| **Chrome DevTools** | JavaScript debugging | React Native (remote debug) |

**Performance Profiling**:
- **React Native**: `Systrace`, `React DevTools Profiler`
- **Flutter**: `Flutter DevTools Performance`, `Timeline view`
- **Memory Leak Detection**: `Instruments` (iOS), `Android Profiler`

**Common Issues & Solutions**:

| Issue | Cause | Solution |
|-------|-------|----------|
| Launch crash | Initialization error, native module mismatch | Check logs, rebuild, clear cache |
| Memory leak | useEffect not cleaned up, listener not removed | Detect with Profiler, implement cleanup function |
| Render delay | Unnecessary re-renders, heavy computation | React.memo, useMemo, useCallback |
| Network error | CORS, certificate, timeout | Check request with Flipper, proxy settings |

**Remote Debugging**:
- React Native: `npx react-native log-ios` / `log-android`
- Flutter: `flutter logs`
- Physical Device Debug: USB connection + enable developer mode

## Mobile-Specific Patterns

### Deep Linking

**iOS Universal Links**:
- Place `apple-app-site-association` file
- Configure Associated Domains
- Define URL scheme

**Android App Links**:
- Place `assetlinks.json` file (.well-known directory)
- Configure Intent filter
- URL verification

**Libraries**:
- React Native: `@react-navigation/native` (built-in deep linking), `react-native-branch`
- Flutter: `app_links` (recommended, replaces deprecated `uni_links`), `go_router` (built-in support)

**Testing**: Required verification of various transition patterns (Safari, Chrome, email, SNS, etc.)

### Push Notifications

**iOS (APNs)**:
- Apple Push Notification service setup
- Required permission request
- Certificate management (p8 key recommended)

**Android (FCM)**:
- Firebase Cloud Messaging setup
- Android 13+ (API 33): Required permission request
- Older versions: Auto-granted

**Libraries**:
- React Native: `@react-native-firebase/messaging`
- Flutter: `flutter_local_notifications` + `firebase_messaging`

**Implementation Patterns**:
- Handle 3 states: foreground, background, terminated
- Deep link integration on notification tap
- Topic subscription & segmentation

### Native Module Integration

**React Native**:
- **iOS**: Swift/Objective-C — prefer Turbo Modules (New Architecture) over legacy Native Modules
- **Android**: Kotlin/Java — prefer Turbo Modules (New Architecture) over legacy Native Modules
- **Decision**: Check library existence → build if unavailable
- **Testing**: Physical device required (many features don't work on simulator)

**Flutter**:
- **Platform Channels**: `MethodChannel`, `EventChannel`
- **Pigeon API**: Type-safe code generation
- **FFI**: Dart FFI for C/C++ integration

**Common Use Cases**:
- Bluetooth, NFC, biometric authentication
- Advanced camera/photo library control
- Background processing (location, etc.)

### Offline Support

**Local DB**:
- **React Native**: Realm, WatermelonDB, SQLite
- **Flutter**: Hive, Isar, sqflite

**Sync Strategy**:
- Optimistic UI (optimistic update)
- Background sync (queue-based)
- Conflict resolution: Last-Write-Wins, CRDT

**Recommended Libraries**:
- `@nozbe/watermelondb` (React Native)
- `realm` (React Native / Flutter)

**Implementation Patterns**:
- Network state monitoring (NetInfo)
- Local cache-first display
- Retry mechanism on sync failure

### State Management

**React Native**:
- **Top Priority**: `Zustand` (lightweight, minimal boilerplate)
- **Small-scale**: Context API
- **Medium-scale**: Jotai, Recoil
- **Large-scale/Enterprise**: Redux Toolkit (strict architecture)

**Flutter**:
- **Top Priority**: `Riverpod` (type-safe, modular, dependency injection)
- **Small-scale**: Provider (performance-improved)
- **Enterprise**: BLoC (predictable flow, testability)

**Selection Criteria**: App scale, team experience, async processing complexity

### Biometric Authentication

**Patterns**:
- **iOS**: Face ID, Touch ID
- **Android**: Biometric API (fingerprint, face recognition)

**Libraries**:
- React Native: `react-native-biometrics`
- Flutter: `local_auth`

**Implementation**: Fallback (passcode) required

### UI Styling

**React Native**:
- **Top Priority**: `NativeWind` (Tailwind CSS for React Native, rapid development)
- **UI Components**: `React Native Paper` (Material Design), `NativeBase/Gluestack`
- **Legacy**: StyleSheet (React Native standard)

**Flutter**:
- **Material Design**: Flutter standard (Material 3 support)
- **iOS-style**: Cupertino widgets
- **Custom**: `styled_widget`, ThemeData

**Implementation Patterns**:
- Dark mode support (system settings sync)
- Responsive design (tablet & smartphone support)
- Accessibility (font size, contrast)

### Navigation

**React Native**:
- **Top Priority**: `React Navigation` (stack, tab, drawer navigation)
- **Expo projects**: `Expo Router` (file-based routing, built on React Navigation — recommended)
- **Native-based**: `react-native-navigation` (Wix — uses native navigation components, requires significant native setup; not lightweight)

**Flutter**:
- **Top Priority**: `go_router` (official recommended, declarative routing, deep linking)
- **Legacy**: `Navigator 2.0` (Flutter standard)

**Implementation Patterns**:
- Deep linking integration (URL to in-app screen)
- State preservation (on back navigation)
- Auth guards (login-required screens)

### Background Tasks

**iOS Background Modes**:
- Location updates
- Audio playback
- Background fetch

**Android WorkManager**:
- Periodic execution tasks
- Network-constrained tasks
- Battery optimization support

**Libraries**:
- React Native: `react-native-background-fetch`, `@react-native-community/background-fetch`
- Flutter: `workmanager`

## Store Optimization

### App Store Connect (iOS)
- **Screenshots**: Device size support, attractive design
- **App Preview**: Video preview (15-30s)
- **Description**: Keyword optimization, clear value proposition
- **TestFlight**: Beta distribution, external tester invitation

### Play Console (Android)
- **Store Listing**: Title optimization, description keywords
- **Staged Rollout**: 5% → 20% → 50% → 100%
- **Crash Reports**: Firebase Crashlytics integration
- **Internal Testing**: Closed test → Open test

### Auto Deployment (Fastlane)

**Pattern**:
```bash
# fastlane/Fastfile
lane :ios_beta do
  increment_build_number
  build_app(scheme: "MyApp")
  upload_to_testflight(skip_waiting_for_build_processing: true)
  slack(message: "Build deployed to TestFlight")
end

# Execute
fastlane ios_beta
```

**Result**: Automates build numbering, compilation, upload, and Slack notification — significantly reduces manual steps after initial Fastlane setup.

---

## Document Metadata

- **Primary Use Case**: Mobile app project kickoff, library selection, quality standards (weekly)
- **Secondary Use Case**: Security review, store distribution guidance (monthly)
- **Auto-update Trigger**: React Native major release, Google Play targetSdk requirement change, iOS deployment target update
- **Obsolescence Risk**: Medium (RN New Architecture and Expo ecosystem evolve rapidly)
- **Related Docs**: `~/.claude/rules/tech-stacks/frontend-web.md` (Web tech共通部分)
- **Target**: Claude Code AI assistant
- **React Native Version**: 0.74+ (New Architecture default)
- **Flutter Version**: 3.x
- **Last Updated**: 2026-05-29
