# 📁 AutoCapture File Structure

## 🏗️ Project Organization

```
/Users/justincollins/autocapture/
├── 📁 autocapture/                          # Main iOS Application
│   ├── 📁 Assets.xcassets/                  # App Assets & Resources
│   │   ├── 📁 AccentColor.colorset/         # App accent color
│   │   ├── 📁 AppIcon.appiconset/           # App icon variations
│   │   └── 📄 Contents.json                 # Asset catalog configuration
│   │
│   ├── 📁 Models/                           # Data Models & SwiftData
│   │   ├── 📄 ProcessedImage.swift          # Enhanced image model with metadata
│   │   ├── 📄 Composition.swift             # Multi-layer editing projects
│   │   ├── 📄 UserProfile.swift             # Firebase user management
│   │   ├── 📄 BackgroundTemplate.swift      # AI prompt templates
│   │   ├── 📄 Batch.swift                   # Stock number batch management
│   │   ├── 📄 CompositionLayer.swift        # Individual layer in compositions
│   │   └── 📄 CameraError.swift             # Error definitions
│   │
│   ├── 📁 Services/                         # Business Logic Services
│   │   ├── 📄 CameraService.swift           # Advanced camera controls
│   │   ├── 📄 BackgroundRemovalService.swift # AI subject detection
│   │   ├── 📄 CompositionEditorService.swift # Visual editing engine
│   │   ├── 📄 BackgroundGenerationService.swift # AI background generation
│   │   ├── 📄 StorageManager.swift          # Hybrid storage management
│   │   ├── 📄 FirebaseAuthService.swift     # Authentication service
│   │   ├── 📄 FirebaseStorageService.swift  # Cloud storage service
│   │   ├── 📄 FirebaseFirestoreService.swift # Database service
│   │   ├── 📄 BatchProcessingService.swift  # Stock number batch handling
│   │   ├── 📄 SubjectDetectionService.swift # Specialized detection
│   │   ├── 📄 FileImportService.swift       # Multi-format file import
│   │   ├── 📄 ExportService.swift           # Composition export
│   │   ├── 📄 CloudSyncService.swift        # Data synchronization
│   │   └── 📄 PromptTemplateEngine.swift    # AI prompt generation
│   │
│   ├── 📁 ViewModels/                       # MVVM View Models
│   │   ├── 📄 CameraViewModel.swift         # Camera state management
│   │   ├── 📄 CompositionEditorViewModel.swift # Editor state management
│   │   ├── 📄 BackgroundGeneratorViewModel.swift # AI generation UI
│   │   ├── 📄 AuthenticationViewModel.swift # Auth state management
│   │   ├── 📄 BatchManagerViewModel.swift   # Batch operations UI
│   │   ├── 📄 CommunityLibraryViewModel.swift # Background library UI
│   │   ├── 📄 CameraSettingsViewModel.swift # Advanced camera controls
│   │   ├── 📄 CaptureSessionViewModel.swift # Batch capture workflow
│   │   └── 📄 SettingsViewModel.swift       # App settings management
│   │
│   ├── 📁 Views/                            # SwiftUI Views
│   │   ├── 📄 ContentView.swift             # Main app entry point
│   │   ├── 📄 CameraView.swift              # Professional camera interface
│   │   ├── 📄 GalleryView.swift             # Image gallery and management
│   │   ├── 📄 CompositionEditorView.swift   # Visual editor interface
│   │   ├── 📄 BackgroundGeneratorView.swift # AI background generation UI
│   │   ├── 📄 BatchManagerView.swift        # Stock number batch management
│   │   ├── 📄 AuthenticationView.swift      # Login/signup interface
│   │   ├── 📄 ProfileView.swift             # User profile management
│   │   ├── 📄 SettingsView.swift            # Application settings
│   │   ├── 📄 CommunityLibraryView.swift    # Shared background library
│   │   ├── 📄 LayerPanelView.swift          # Layer management panel
│   │   ├── 📄 ToolPanelView.swift           # Editing tools panel
│   │   ├── 📄 ImportView.swift              # File import interface
│   │   ├── 📄 ShareView.swift               # Composition sharing
│   │   ├── 📄 CaptureSettingsView.swift     # Capture configuration
│   │   └── 📄 PromptEditorView.swift        # AI prompt customization
│   │
│   ├── 📁 Utilities/                        # Helper Functions & Extensions
│   │   ├── 📄 ImageProcessingExtensions.swift # Core Image utilities
│   │   ├── 📄 ColorExtensions.swift         # Color manipulation helpers
│   │   ├── 📄 GeometryExtensions.swift      # Geometry calculation helpers
│   │   ├── 📄 ValidationHelpers.swift       # Input validation utilities
│   │   ├── 📄 DateExtensions.swift          # Date formatting helpers
│   │   ├── 📄 FileSystemHelpers.swift       # File system operations
│   │   └── 📄 PerformanceHelpers.swift      # Performance optimization
│   │
│   ├── 📁 Resources/                        # Configuration & Resources
│   │   ├── 📄 Info.plist                    # App configuration
│   │   ├── 📄 GoogleService-Info.plist      # Firebase configuration
│   │   ├── 📄 BackgroundTemplates.json      # AI prompt templates
│   │   ├── 📄 CameraPresets.json            # Camera configuration presets
│   │   └── 📄 AppConstants.swift            # Application constants
│   │
│   ├── 📄 autocaptureApp.swift              # App entry point & configuration
│   └── 📄 ContentView.swift                 # Main content view
│
├── 📁 Docs/                                 # Project Documentation
│   ├── 📄 master-plan.md                    # High-level project roadmap
│   ├── 📄 granular-plan.md                  # Detailed development tasks
│   ├── 📄 requirements.md                   # Detailed specifications
│   ├── 📄 api-documentation.md              # Service API documentation
│   ├── 📄 user-guide.md                     # End-user documentation
│   └── 📄 developer-guide.md                # Developer documentation
│
├── 📁 Scripts/                              # Build & Development Scripts
│   ├── 📄 lint.sh                           # SwiftLint validation script
│   ├── 📄 build.sh                          # Build validation script
│   ├── 📄 test.sh                           # Test execution script
│   ├── 📄 deploy.sh                         # Deployment script
│   └── 📄 setup.sh                          # Development environment setup
│
├── 📁 Tests/                                # Test Suites
│   ├── 📁 UnitTests/                        # Unit test files
│   │   ├── 📄 CameraServiceTests.swift      # Camera service tests
│   │   ├── 📄 BackgroundRemovalServiceTests.swift # Background removal tests
│   │   ├── 📄 CompositionEditorTests.swift  # Editor functionality tests
│   │   ├── 📄 StorageManagerTests.swift     # Storage operation tests
│   │   └── 📄 ViewModelTests.swift          # ViewModel logic tests
│   │
│   ├── 📁 IntegrationTests/                 # Integration test files
│   │   ├── 📄 FirebaseIntegrationTests.swift # Firebase service tests
│   │   ├── 📄 CameraIntegrationTests.swift  # Camera workflow tests
│   │   └── 📄 UIIntegrationTests.swift      # UI workflow tests
│   │
│   └── 📁 PerformanceTests/                 # Performance benchmark tests
│       ├── 📄 ImageProcessingBenchmarks.swift # Processing performance
│       ├── 📄 MemoryUsageTests.swift        # Memory efficiency tests
│       └── 📄 BatchProcessingTests.swift    # Batch operation tests
│
├── 📁 .cursor/                              # Cursor IDE Configuration
│   ├── 📁 commands/                         # Custom Cursor commands
│   │   ├── 📄 start-of-project.md           # Project initialization
│   │   ├── 📄 start-of-session.md           # Session initialization
│   │   ├── 📄 end-of-session.md             # Session cleanup
│   │   ├── 📄 feature-development.md        # Feature development workflow
│   │   ├── 📄 testing-workflow.md           # Testing procedures
│   │   └── 📄 deployment-workflow.md        # Deployment procedures
│   │
│   └── 📄 rules/                            # Cursor IDE rules
│       ├── 📄 swift-coding-standards.md     # Swift coding guidelines
│       ├── 📄 ui-design-principles.md       # UI/UX design rules
│       └── 📄 testing-requirements.md       # Testing standards
│
├── 📁 autocapture.xcodeproj/                # Xcode Project Configuration
│   ├── 📄 project.pbxproj                   # Xcode project file
│   ├── 📁 project.xcworkspace/              # Xcode workspace
│   │   ├── 📄 contents.xcworkspacedata      # Workspace configuration
│   │   ├── 📁 xcshareddata/                 # Shared workspace data
│   │   └── 📁 xcuserdata/                   # User-specific data
│   │
│   └── 📁 xcuserdata/                       # User-specific Xcode data
│       └── 📁 justincollins.xcuserdatad/    # User data directory
│
├── 📄 AGENTS.md                             # AI Agents & Codex Integration
├── 📄 file-structure.md                     # This file structure document
├── 📄 README.md                             # Project overview and setup
├── 📄 .gitignore                            # Git ignore patterns
├── 📄 .swiftlint.yml                        # SwiftLint configuration
└── 📄 Package.swift                         # Swift Package Manager dependencies
```

## 📋 Directory Descriptions

### 📁 autocapture/ (Main Application)
The core iOS application containing all source code, resources, and configurations.

### 📁 Models/
Data models using SwiftData for persistence, including enhanced image models, composition structures, and user management.

### 📁 Services/
Business logic services handling camera operations, AI processing, storage management, and external service integration.

### 📁 ViewModels/
MVVM pattern view models managing UI state, user interactions, and business logic coordination.

### 📁 Views/
SwiftUI views implementing the user interface with modern design principles and accessibility support.

### 📁 Utilities/
Helper functions, extensions, and utility classes supporting the main application functionality.

### 📁 Resources/
Configuration files, asset catalogs, and external resource definitions.

### 📁 Docs/
Comprehensive project documentation including planning, requirements, and developer guides.

### 📁 Scripts/
Automated build, testing, and deployment scripts for development workflow automation.

### 📁 Tests/
Complete test suite including unit tests, integration tests, and performance benchmarks.

### 📁 .cursor/
Cursor IDE configuration including custom commands and development rules.

## 🔧 File Naming Conventions

### Swift Files
- **Services**: `[Feature]Service.swift` (e.g., `CameraService.swift`)
- **ViewModels**: `[Feature]ViewModel.swift` (e.g., `CameraViewModel.swift`)
- **Views**: `[Feature]View.swift` (e.g., `CameraView.swift`)
- **Models**: `[Feature].swift` (e.g., `ProcessedImage.swift`)
- **Utilities**: `[Purpose]Extensions.swift` (e.g., `ImageProcessingExtensions.swift`)

### Configuration Files
- **JSON**: `[Purpose].json` (e.g., `BackgroundTemplates.json`)
- **Scripts**: `[action].sh` (e.g., `lint.sh`, `build.sh`)
- **Documentation**: `[purpose].md` (e.g., `master-plan.md`)

### Asset Files
- **Images**: `[purpose]-[size].[format]` (e.g., `icon-1024.png`)
- **Colors**: `[color-name].colorset` (e.g., `AccentColor.colorset`)

## 🎯 Development Workflow

### Feature Development
1. Create feature branch: `feature/[component-name]`
2. Implement in appropriate directory structure
3. Add tests in corresponding test directory
4. Update documentation as needed
5. Run linting and build scripts
6. Merge to main after validation

### File Organization Principles
- **Separation of Concerns**: Each directory has a specific purpose
- **Logical Grouping**: Related functionality grouped together
- **Scalability**: Structure supports future feature additions
- **Maintainability**: Clear naming and organization for easy navigation

### Import Organization
- System frameworks first
- Third-party dependencies second
- Local project files last
- Alphabetical ordering within each group

---

*This file structure serves as the definitive guide for project organization. All new files should follow these conventions and be placed in the appropriate directories.*

