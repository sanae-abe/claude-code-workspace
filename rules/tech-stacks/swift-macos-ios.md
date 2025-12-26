# Swift (macOS/iOS) Development

## Scope

- **Technologies**: Swift 5.9+, SwiftUI, UIKit, AppKit, Xcode
- **Platforms**: macOS 13.0+, iOS 16.0+, watchOS 9.0+, tvOS 16.0+
- **Use Cases**:
  - macOS/iOS native app development
  - QuickLook extensions, App Extensions
  - System integrations (Keychain, FileProvider, etc.)

## Quick Reference

| Task | Command | Frequency | Notes |
|------|---------|-----------|-------|
| Build (Debug) | `xcodebuild -scheme MyApp` | 99% | Debug build |
| Build (Release) | `xcodebuild -scheme MyApp -configuration Release` | 90% | Production build |
| Run Tests | `xcodebuild test -scheme MyApp` | 95% | Unit + UI tests |
| Swift Format | `swift-format -i -r .` | 90% | Code formatting |
| SwiftLint | `swiftlint` | 99% | Linter check |
| SwiftLint Auto-fix | `swiftlint --fix` | 85% | Auto-fix violations |
| Type Check | Build with Xcode (⌘+B) | 99% | Compiler errors/warnings |
| Code Coverage | `xcodebuild test -enableCodeCoverage YES` | 80% | Test coverage report |
| Dependencies (SPM) | Xcode > File > Add Packages | 90% | Swift Package Manager |
| Clean Build | `xcodebuild clean` | 70% | Clear build artifacts |

## Framework Selection

### UI Framework Decision

| Criteria | SwiftUI | UIKit/AppKit | Weight |
|----------|---------|--------------|--------|
| **Dev Speed** | 9 | 5 | 3x |
| **Platform Support** | 9 (iOS 13+, macOS 10.15+) | 10 (Legacy support) | 2x |
| **Customization** | 6 | 10 | 2x |
| **Learning Curve** | 7 | 4 | 1x |
| **Community Support** | 8 | 10 | 2x |
| **Weighted Total** | 81 | 76 | - |

### Selection Criteria

| Condition | Recommendation |
|-----------|----------------|
| New project, iOS 16+/macOS 13+ | SwiftUI (declarative, less code) |
| Legacy support (iOS 12-, macOS 10.14-) | UIKit/AppKit |
| Complex custom UI | UIKit/AppKit (fine-grained control) |
| Rapid prototyping | SwiftUI |
| Enterprise (existing codebase) | UIKit/AppKit + gradual SwiftUI adoption |
| Animations & gestures | SwiftUI (built-in modifiers) |

## Quality Standards

### Swift Compiler Warnings & Errors

**Required**:
- **Zero compiler errors**: Build must succeed
- **Zero warnings**: Treat warnings as errors in Release builds
  ```swift
  // Build Settings
  SWIFT_TREAT_WARNINGS_AS_ERRORS = YES
  ```

**Type Safety**:
- **Force unwrap (`!`) minimization**: Use optional binding or guard
  ```swift
  // Bad: Force unwrap (crash risk)
  let user = users.first!

  // Good: Optional binding
  guard let user = users.first else { return }

  // Good: Nil coalescing
  let user = users.first ?? defaultUser
  ```

- **Implicitly unwrapped optionals (`!`)**: Use only for:
  - IBOutlets (guaranteed initialized by storyboard)
  - Properties initialized in `viewDidLoad` or `init`

- **`any` keyword**: Prefer concrete types over existentials

### SwiftLint Configuration

**Setup**:
```yaml
# .swiftlint.yml
disabled_rules:
  - trailing_whitespace  # Prettier handles this
opt_in_rules:
  - force_unwrapping  # Detect force unwrap
  - implicitly_unwrapped_optional  # Detect `!` types
  - redundant_optional_initialization
excluded:
  - Pods
  - Build
  - DerivedData
line_length: 120
```

**Execution**:
```bash
# Check violations
swiftlint

# Auto-fix
swiftlint --fix

# CI/CD (fail on violations)
swiftlint --strict
```

### Code Formatting

**swift-format** (Apple official):
```bash
# Install
brew install swift-format

# Format all files
swift-format -i -r Sources/

# Configuration (.swift-format.json)
{
  "version": 1,
  "lineLength": 100,
  "indentation": {
    "spaces": 2
  },
  "respectsExistingLineBreaks": true
}
```

**Xcode built-in** (⌃+I):
- Indentation: 2 or 4 spaces (project consistency)
- Automatic formatting: Editor > Format > Re-Indent

### Testing Standards

**XCTest Framework**:
```swift
import XCTest
@testable import MyApp

final class MyTests: XCTestCase {
    func testExample() {
        XCTAssertEqual(2 + 2, 4)
    }

    func testAsyncOperation() async throws {
        let result = await fetchData()
        XCTAssertNotNil(result)
    }
}
```

**Coverage Targets**:
- **Unit Tests**: 70-80% for business logic
- **UI Tests**: Critical user flows only (5-10% of tests)
- **Integration Tests**: API calls, database operations

**Test Execution**:
```bash
# All tests
xcodebuild test -scheme MyApp

# Specific test class
xcodebuild test -scheme MyApp -only-testing:MyAppTests/MyTests

# Code coverage
xcodebuild test -scheme MyApp -enableCodeCoverage YES

# View coverage report
# Xcode > Report Navigator > Coverage tab
```

## Security

### Keychain Access (Sensitive Data Storage)

**Use Cases**: Passwords, API tokens, encryption keys

```swift
import Security

// Store
func saveToKeychain(key: String, data: Data) -> Bool {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data
    ]

    SecItemDelete(query as CFDictionary)  // Remove existing
    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
}

// Retrieve
func loadFromKeychain(key: String) -> Data? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    return status == errSecSuccess ? (result as? Data) : nil
}
```

**Recommended Library**: `KeychainAccess` (Swift Package)
```swift
import KeychainAccess

let keychain = Keychain(service: "com.example.app")
keychain["token"] = "secret"  // Store
let token = keychain["token"]  // Retrieve
```

### App Transport Security (ATS)

**Default**: HTTPS only (HTTP blocked)

**Exception** (development only):
```xml
<!-- Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Production**: Remove all HTTP exceptions

### Data Protection

**File Protection** (iOS):
```swift
// Encrypt file with device passcode
let attributes: [FileAttributeKey: Any] = [
    .protectionKey: FileProtectionType.complete
]

try FileManager.default.setAttributes(
    attributes,
    ofItemAtPath: filePath
)
```

**Protection Levels**:
- `.complete`: Locked when device locked (most secure)
- `.completeUnlessOpen`: Readable while open, even if locked
- `.completeUntilFirstUserAuthentication`: After first unlock (default)

### Code Signing

**Development**:
- Automatic signing: Xcode manages certificates
- Manual signing: Specify provisioning profile

**Distribution**:
- App Store: Apple Distribution certificate
- Ad-hoc/Enterprise: Distribution certificate + provisioning profile
- Notarization (macOS): Required for distribution outside App Store

```bash
# Notarize macOS app
xcrun notarytool submit MyApp.zip \
  --apple-id "email@example.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password"

# Staple notarization ticket
xcrun stapler staple MyApp.app
```

### OWASP Mobile Top 10 Compliance

| Risk | Mitigation |
|------|------------|
| M1: Improper Platform Usage | Follow iOS/macOS security guidelines |
| M2: Insecure Data Storage | Use Keychain, FileProtection |
| M3: Insecure Communication | Enforce HTTPS, certificate pinning |
| M4: Insecure Authentication | Biometric auth, secure token storage |
| M5: Insufficient Cryptography | Use CryptoKit (AES-256, SHA-256) |
| M9: Reverse Engineering | Code obfuscation (limited on iOS) |

## Performance Optimization

### Instruments Profiling

**Tools**:
- **Time Profiler**: CPU usage, hot paths
- **Allocations**: Memory usage, leaks
- **Leaks**: Memory leak detection
- **Energy Log**: Battery usage
- **Network**: HTTP requests, bandwidth

**Usage**:
```bash
# Profile with Instruments
xcodebuild -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 15' \
  -derivedDataPath ./Build \
  -enableCodeCoverage NO \
  | xcpretty

# Open in Instruments
open /Applications/Xcode.app/Contents/Applications/Instruments.app
```

### Memory Management

**ARC (Automatic Reference Counting)**:
```swift
class ViewController: UIViewController {
    var closure: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Bad: Strong reference cycle (memory leak)
        closure = {
            self.view.backgroundColor = .red
        }

        // Good: Weak reference
        closure = { [weak self] in
            self?.view.backgroundColor = .red
        }

        // Good: Unowned (guaranteed non-nil)
        closure = { [unowned self] in
            self.view.backgroundColor = .red
        }
    }
}
```

**Common Patterns**:
- **Weak self** in closures: Prevent retain cycles
- **Lazy loading**: Defer initialization until needed
- **Image caching**: Use `NSCache` (auto memory management)

```swift
// Image cache
let imageCache = NSCache<NSString, UIImage>()

func loadImage(url: URL) async -> UIImage? {
    // Check cache
    if let cached = imageCache.object(forKey: url.absoluteString as NSString) {
        return cached
    }

    // Download
    guard let (data, _) = try? await URLSession.shared.data(from: url),
          let image = UIImage(data: data) else {
        return nil
    }

    // Cache
    imageCache.setObject(image, forKey: url.absoluteString as NSString)
    return image
}
```

### SwiftUI Performance

**Optimization Techniques**:

```swift
// 1. Equatable for struct diffing
struct TaskRow: View, Equatable {
    let task: Task

    var body: some View {
        Text(task.title)
    }

    static func == (lhs: TaskRow, rhs: TaskRow) -> Bool {
        lhs.task.id == rhs.task.id
    }
}

// 2. @State minimization (derive values)
struct ContentView: View {
    @State private var items: [Item] = []

    // Bad: Duplicate state
    // @State private var itemCount: Int = 0

    // Good: Computed property
    var itemCount: Int { items.count }
}

// 3. LazyVStack for large lists
LazyVStack {
    ForEach(items) { item in
        ItemRow(item: item)
    }
}

// 4. Task cancellation
.task {
    await fetchData()
}
.task(id: searchText) {  // Re-run when searchText changes
    await search(searchText)
}
```

## Concurrency (Swift 5.5+)

### async/await

```swift
// Async function
func fetchUser(id: String) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

// Usage
Task {
    do {
        let user = try await fetchUser(id: "123")
        print(user.name)
    } catch {
        print("Error: \(error)")
    }
}
```

### Actors (Thread-Safe State)

```swift
actor UserCache {
    private var cache: [String: User] = [:]

    func get(id: String) -> User? {
        cache[id]
    }

    func set(user: User) {
        cache[user.id] = user
    }
}

// Usage
let cache = UserCache()
await cache.set(user: user)
let cachedUser = await cache.get(id: "123")
```

### MainActor (UI Updates)

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var users: [User] = []

    func loadUsers() async {
        let users = try? await fetchUsers()
        self.users = users ?? []  // Auto on main thread
    }
}
```

## Dependency Management

### Swift Package Manager (SPM)

**Xcode Integration**:
1. File > Add Packages...
2. Enter repository URL: `https://github.com/Alamofire/Alamofire`
3. Select version rule (branch/tag/commit)
4. Add to target

**Package.swift** (for libraries):
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyLibrary",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "MyLibrary", targets: ["MyLibrary"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
    ],
    targets: [
        .target(
            name: "MyLibrary",
            dependencies: ["Alamofire"]
        ),
        .testTarget(
            name: "MyLibraryTests",
            dependencies: ["MyLibrary"]
        )
    ]
)
```

### CocoaPods (Legacy)

**Podfile**:
```ruby
platform :ios, '16.0'
use_frameworks!

target 'MyApp' do
  pod 'Alamofire', '~> 5.8'
  pod 'SDWebImage', '~> 5.17'
end
```

**Commands**:
```bash
pod install       # Install dependencies
pod update        # Update to latest versions
pod outdated      # Check for updates
```

## Development Workflow

### Post-Edit Mandatory Checks

**Recommended execution order**:
```bash
# 1. Build (⌘+B in Xcode)
xcodebuild -scheme MyApp

# 2. SwiftLint
swiftlint --fix  # Auto-fix
swiftlint        # Check remaining violations

# 3. Tests
xcodebuild test -scheme MyApp

# 4. (Optional) Code coverage
xcodebuild test -scheme MyApp -enableCodeCoverage YES
```

**Time-constrained cases**:
```bash
# Minimum (within 30s): Build + SwiftLint
xcodebuild -scheme MyApp && swiftlint

# Standard (within 2min): Build + SwiftLint + Unit tests
xcodebuild -scheme MyApp && swiftlint && xcodebuild test -scheme MyApp -only-testing:MyAppTests

# Complete (within 10min): Full tests + coverage
xcodebuild test -scheme MyApp -enableCodeCoverage YES
```

### Git Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

set -e

echo "Running SwiftLint..."
swiftlint --strict || {
    echo "SwiftLint failed. Fix violations and try again."
    exit 1
}

echo "Building project..."
xcodebuild -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 15' \
    build-for-testing | xcpretty || {
    echo "Build failed."
    exit 1
}

echo "Running tests..."
xcodebuild -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 15' \
    test-without-building | xcpretty || {
    echo "Tests failed."
    exit 1
}
```

## Common Patterns

### SwiftUI MVVM

```swift
// Model
struct User: Identifiable, Codable {
    let id: String
    let name: String
}

// ViewModel
@MainActor
class UserViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var error: Error?

    func fetchUsers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            users = try await UserService.shared.fetchUsers()
        } catch {
            self.error = error
        }
    }
}

// View
struct UserListView: View {
    @StateObject private var viewModel = UserViewModel()

    var body: some View {
        List(viewModel.users) { user in
            Text(user.name)
        }
        .task {
            await viewModel.fetchUsers()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}
```

### Networking with URLSession

```swift
class APIClient {
    static let shared = APIClient()

    func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET"
    ) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// Usage
let users: [User] = try await APIClient.shared.request(
    "https://api.example.com/users"
)
```

### UserDefaults Wrapper (Type-Safe)

```swift
@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T

    var wrappedValue: T {
        get {
            UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

// Usage
struct Settings {
    @UserDefault(key: "isDarkMode", defaultValue: false)
    static var isDarkMode: Bool

    @UserDefault(key: "username", defaultValue: "Guest")
    static var username: String
}

Settings.isDarkMode = true
print(Settings.username)  // "Guest"
```

## Error Handling

### Result Type

```swift
enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
}

func fetchData() -> Result<Data, NetworkError> {
    guard let url = URL(string: "https://api.example.com") else {
        return .failure(.invalidURL)
    }

    // Fetch data...
    return .success(data)
}

// Usage
switch fetchData() {
case .success(let data):
    print("Success: \(data)")
case .failure(let error):
    print("Error: \(error)")
}
```

### Custom Error Types

```swift
enum UserServiceError: LocalizedError {
    case networkError(Error)
    case invalidResponse
    case userNotFound(id: String)

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case .userNotFound(let id):
            return "User with ID \(id) not found"
        }
    }
}
```

## Platform-Specific Features

### macOS

**AppKit Integration**:
```swift
import AppKit

class CustomViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
    }
}
```

**Menu Bar App**:
```swift
@main
struct MenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()  // No main window
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "My App"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
```

### iOS

**UIKit Integration (SwiftUI)**:
```swift
import UIKit
import SwiftUI

struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Update if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Handle image
        }
    }
}
```

## Resources

- **Swift Official**: https://swift.org/
- **SwiftUI Documentation**: https://developer.apple.com/documentation/swiftui
- **Swift Package Index**: https://swiftpackageindex.com/
- **WWDC Videos**: https://developer.apple.com/videos/
- **Swift Evolution**: https://github.com/apple/swift-evolution

---

**Document Metadata**:
- **Primary Use Case**: macOS/iOS native app development (weekly)
- **Secondary Use Case**: QuickLook/App Extension development (monthly)
- **Auto-update Trigger**: Swift version upgrade (yearly), major macOS/iOS release
- **Target**: Claude Code AI assistant
- **Swift Version**: 5.9+ (MSRV)
- **Last Updated**: 2025-11-20
