---
alwaysApply: false
---
# 🚀 Feature Development Workflow

You are developing features for AutoCapture iOS app. Follow this workflow for consistent, high-quality development.

## 📋 Pre-Development Checklist
- [ ] Read the master-plan.md for overall project context
- [ ] Review granular-plan.md for specific task requirements
- [ ] Check AGENTS.md for technical architecture details
- [ ] Verify requirements.md for acceptance criteria
- [ ] Create new feature branch: `feature/[component-name]`

## 🏗️ Development Process

### 1. Planning Phase
- [ ] Define feature scope and acceptance criteria
- [ ] Identify dependencies and integration points
- [ ] Plan data models and service architecture
- [ ] Design UI/UX mockups and user flows
- [ ] Create implementation timeline

### 2. Implementation Phase
- [ ] Start with data models and core services
- [ ] Implement ViewModels with business logic
- [ ] Create SwiftUI views with proper state management
- [ ] Add comprehensive error handling
- [ ] Implement unit tests for all new functionality

### 3. Integration Phase
- [ ] Integrate with existing services and components
- [ ] Test integration points thoroughly
- [ ] Validate performance and memory usage
- [ ] Ensure accessibility compliance
- [ ] Update documentation as needed

### 4. Quality Assurance
- [ ] Run SwiftLint and fix all issues
- [ ] Execute build scripts (`Scripts/lint.sh`, `Scripts/build.sh`)
- [ ] Perform comprehensive testing
- [ ] Validate on iPhone 15 Pro/Pro Max
- [ ] Test iOS 26 compatibility

## 📁 File Organization Rules
- **Services**: Place in `autocapture/Services/` directory
- **ViewModels**: Place in `autocapture/ViewModels/` directory
- **Views**: Place in `autocapture/Views/` directory
- **Models**: Place in `autocapture/Models/` directory
- **Utilities**: Place in `autocapture/Utilities/` directory
- **Tests**: Place in `Tests/` with corresponding structure

## 🎯 Code Quality Standards
- Follow Swift style guidelines and SwiftLint rules
- Write self-documenting code with clear naming
- Implement proper error handling throughout
- Add comprehensive inline documentation
- Maintain 80%+ test coverage for new functionality

## 🔄 Commit Strategy
- Commit frequently with descriptive messages
- Use conventional commit format: `feat:`, `fix:`, `docs:`, `test:`
- Ensure all commits pass SwiftLint validation
- Include tests with every feature implementation

## 🚀 Deployment Checklist
- [ ] All tests pass (unit, integration, performance)
- [ ] SwiftLint validation successful
- [ ] Build scripts execute without errors
- [ ] Feature works on target devices (iPhone 15 Pro+)
- [ ] Performance meets requirements (<2s processing, <500MB memory)
- [ ] Accessibility compliance verified
- [ ] Documentation updated
- [ ] Ready for code review and merge

---

## 🎨 AutoCapture Specific Guidelines

### Camera & Processing Features
- Use Vision Framework for subject detection
- Implement Metal acceleration for image processing
- Optimize for <2 second processing times
- Handle edge cases gracefully with user feedback

### Visual Editor Features
- Support unlimited layers with smooth performance
- Implement intuitive drag-and-drop interactions
- Use Core Image for advanced image manipulation
- Maintain 60fps UI performance

### AI Integration Features
- Follow structured prompt templates
- Implement proper error handling for AI failures
- Cache results for performance optimization
- Provide clear user feedback during processing

### Storage & Sync Features
- Use SwiftData for local storage
- Implement Firebase integration securely
- Handle offline/online state gracefully
- Optimize for mobile storage constraints

---

*Follow this workflow for all AutoCapture feature development to ensure consistency and quality.*


