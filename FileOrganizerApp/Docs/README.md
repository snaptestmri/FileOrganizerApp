# File Organizer App - Documentation

Welcome to the File Organizer App documentation. This directory contains comprehensive documentation organized by category.

## 📚 Documentation Structure

```
Docs/
├── Architecture/          # System architecture and design
│   ├── DESIGN_DOCUMENT.md
│   ├── ARCHITECTURE_BLOCKS.md
│   └── ARCHITECTURE_MIGRATION_STATUS.md
│
├── Testing/              # Testing guides and documentation
│   ├── AIClassificationTests_README.md
│   ├── AutomatedTests-README.md
│   ├── CLASSIFIER_TESTING_GUIDE.md
│   ├── HOW_TO_TEST_CLASSIFIERS.md
│   ├── MANUAL_TEST_INSTRUCTIONS.md
│   └── XCTEST_HTML_REPORT_SETUP.md
│
├── Tuning/               # Classifier tuning and optimization
│   ├── TUNING_OLLAMA_CLASSIFIER.md
│   ├── TUNING_SUMMARY.md
│   ├── TUNING_TEST_GUIDE.md
│   ├── QUICK_TUNING_REFERENCE.md
│   └── RUN_TUNING_TEST.md
│
└── Guides/               # User and developer guides
    ├── HOW_OLLAMA_WORKS.md
    ├── OFFLINE_CLASSIFICATION_GUIDE.md
    ├── LLM_CLASSIFICATION_REQUIREMENTS.md
    └── CLASSIFIER_IMPROVEMENTS.md
```

## 🚀 Quick Start

### For Developers

1. **Start Here**: [Architecture/DESIGN_DOCUMENT.md](./Architecture/DESIGN_DOCUMENT.md)
   - Complete system architecture
   - Component design
   - Data flow and interactions

2. **Visual Reference**: [Architecture/ARCHITECTURE_BLOCKS.md](./Architecture/ARCHITECTURE_BLOCKS.md)
   - System overview diagrams
   - Component interaction blocks
   - Data flow visualizations

3. **Migration Status**: [Architecture/ARCHITECTURE_MIGRATION_STATUS.md](./Architecture/ARCHITECTURE_MIGRATION_STATUS.md)
   - Current architecture state
   - Migration completion status
   - New vs old architecture comparison

### For Users

1. **Setup Guide**: [Guides/OFFLINE_CLASSIFICATION_GUIDE.md](./Guides/OFFLINE_CLASSIFICATION_GUIDE.md)
   - Installation instructions
   - Offline options (Ollama)
   - Troubleshooting

2. **How Ollama Works**: [Guides/HOW_OLLAMA_WORKS.md](./Guides/HOW_OLLAMA_WORKS.md)
   - Understanding local AI
   - Setup and configuration

### For Testers

1. **Testing Guide**: [Testing/HOW_TO_TEST_CLASSIFIERS.md](./Testing/HOW_TO_TEST_CLASSIFIERS.md)
   - Manual testing procedures
   - Automated test suite
   - Test reporting

2. **Classifier Testing**: [Testing/CLASSIFIER_TESTING_GUIDE.md](./Testing/CLASSIFIER_TESTING_GUIDE.md)
   - Comprehensive testing strategies
   - Test scenarios

## 📖 Documentation by Category

### Architecture
- **[DESIGN_DOCUMENT.md](./Architecture/DESIGN_DOCUMENT.md)** - Complete design specification
- **[ARCHITECTURE_BLOCKS.md](./Architecture/ARCHITECTURE_BLOCKS.md)** - Visual architecture diagrams
- **[ARCHITECTURE_MIGRATION_STATUS.md](./Architecture/ARCHITECTURE_MIGRATION_STATUS.md)** - Migration status and comparison

### Testing
- **[HOW_TO_TEST_CLASSIFIERS.md](./Testing/HOW_TO_TEST_CLASSIFIERS.md)** - Testing overview
- **[CLASSIFIER_TESTING_GUIDE.md](./Testing/CLASSIFIER_TESTING_GUIDE.md)** - Detailed testing guide
- **[AIClassificationTests_README.md](./Testing/AIClassificationTests_README.md)** - Test suite documentation
- **[AutomatedTests-README.md](./Testing/AutomatedTests-README.md)** - Automated test documentation
- **[MANUAL_TEST_INSTRUCTIONS.md](./Testing/MANUAL_TEST_INSTRUCTIONS.md)** - Manual testing procedures
- **[XCTEST_HTML_REPORT_SETUP.md](./Testing/XCTEST_HTML_REPORT_SETUP.md)** - Test reporting setup

### Tuning
- **[TUNING_OLLAMA_CLASSIFIER.md](./Tuning/TUNING_OLLAMA_CLASSIFIER.md)** - Ollama classifier tuning
- **[TUNING_SUMMARY.md](./Tuning/TUNING_SUMMARY.md)** - Tuning summary and results
- **[TUNING_TEST_GUIDE.md](./Tuning/TUNING_TEST_GUIDE.md)** - Tuning test procedures
- **[QUICK_TUNING_REFERENCE.md](./Tuning/QUICK_TUNING_REFERENCE.md)** - Quick reference guide
- **[RUN_TUNING_TEST.md](./Tuning/RUN_TUNING_TEST.md)** - How to run tuning tests

### Guides
- **[OFFLINE_CLASSIFICATION_GUIDE.md](./Guides/OFFLINE_CLASSIFICATION_GUIDE.md)** - Offline setup and usage
- **[HOW_OLLAMA_WORKS.md](./Guides/HOW_OLLAMA_WORKS.md)** - Understanding Ollama
- **[LLM_CLASSIFICATION_REQUIREMENTS.md](./Guides/LLM_CLASSIFICATION_REQUIREMENTS.md)** - Requirements specification
- **[CLASSIFIER_IMPROVEMENTS.md](./Guides/CLASSIFIER_IMPROVEMENTS.md)** - Improvement notes

## 🔑 Key Concepts

### Classification Methods
- **Ollama (Local)** - Runs on your Mac, 100% private, offline
- **OpenAI (Cloud)** - High accuracy, requires internet, paid
- **Anthropic (Cloud)** - Claude models, requires internet, paid
- **Fallback (Rule-Based)** - Instant, always available, pattern matching

### Privacy Model
- **Metadata Only** - Never sends file content
- **Local First** - Ollama runs on localhost
- **User Choice** - Explicit selection of cloud vs local

### Architecture
- **Service-Based** - LLMService protocol for extensibility
- **Fallback Chain** - Automatic fallback if classifier unavailable
- **Modular Design** - Clear separation of concerns
- **Organized Structure** - Models organized by Core/Services/Storage/Constants

## 📋 Current Project Structure

```
FileOrganizerApp/
├── Models/
│   ├── Core/                    # Core data models
│   ├── Services/                # Business logic services
│   │   ├── Classification/     # Classification services
│   │   └── LLM/                # LLM service implementations
│   ├── Storage/                 # Data persistence
│   └── Constants/              # Application constants
├── Views/                       # SwiftUI views
└── Docs/                       # This documentation
```

## 🔧 Implementation Status

✅ **Completed:**
- Core classification system
- Ollama integration (local)
- OpenAI integration (cloud)
- Anthropic integration (cloud)
- Fallback classifier
- UI components
- Progress tracking
- Error handling
- Telemetry and analytics
- A/B testing framework
- Project reorganization

🚧 **In Progress:**
- Performance optimization
- User feedback integration

📋 **Planned:**
- Learning from corrections
- Custom prompts
- Image classification
- Advanced analytics

---

**Last Updated:** 2025-01-17  
**Documentation Version:** 2.0
