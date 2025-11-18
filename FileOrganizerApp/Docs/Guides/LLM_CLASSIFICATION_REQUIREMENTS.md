# LLM-Powered File Classification Feature - Requirements Brainstorm

## 🎯 Core Functionality

### 1. **File Analysis & Classification (Metadata-Only Approach)**
- **Input**: **METADATA ONLY** - No file content sent to LLM
  - Filename and extension
  - File size and formatted size
  - Creation and modification dates
  - File type (UTI/MIME type)
  - Parent folder name (for context)
  - Sibling file names (for context)
  - Detected filename patterns (dates, versions, etc.)
  - **Optional**: First 200-500 characters for text files only (user-controlled)
- **Output**: Suggested category, subfolder, and confidence score
- **Classification Types**:
  - **Name-based** (analyze filename patterns) - PRIMARY METHOD
  - **Metadata-based** (file type, size, date) - PRIMARY METHOD
  - **Context-based** (folder location, related files) - PRIMARY METHOD
  - **Content-based** (optional preview for text files only) - OPTIONAL

### 2. **LLM Integration**
- **Provider Options**: OpenAI, Anthropic Claude, Local LLM (Ollama), etc.
- **API Endpoints**: 
  - Classification endpoint
  - Batch processing endpoint
- **Model Selection**: 
  - GPT-4/GPT-4 Turbo for accuracy
  - GPT-3.5 for cost efficiency
  - Local models for privacy

### 3. **Smart Folder Structure Generation**
- **Auto-create folders** based on LLM suggestions
- **Hierarchical organization**: Category → Subfolder → File
- **Custom naming conventions** (user-defined templates)
- **Merge similar categories** (e.g., "Documents" + "Docs" → "Documents")

## 🔐 Privacy & Security

### 1. **Data Handling (Metadata-First Approach)**
- **Default Mode: Metadata Only** ✅ RECOMMENDED
  - Send filename + comprehensive metadata (size, dates, type, context)
  - **NO file content** sent by default
  - Works with cloud LLM (OpenAI, Claude) or local LLM
  - Privacy-friendly: Only metadata leaves device
  
- **Enhanced Mode: Metadata + Text Preview** (Optional)
  - Send metadata + first 200-500 characters for text files only
  - User must explicitly enable this option
  - Only applies to text-based files (.txt, .md, .json, etc.)
  - User consent required
  
- **Full Content Mode** (Not Recommended)
  - Send entire file content for analysis
  - Clear warning about privacy implications
  - Only for specific use cases
  - Encryption in transit required

### 2. **API Key Management**
- Secure storage of API keys (Keychain on macOS)
- Support for multiple API keys (OpenAI, Anthropic, etc.)
- Rate limiting and usage tracking
- Cost estimation before processing

### 3. **Sensitive File Detection**
- Skip system files, hidden files
- Option to exclude specific file types/extensions
- Skip files in certain directories (e.g., ~/Library, system folders)

## 💰 Cost & Performance

### 1. **Cost Management**
- **Token Usage Tracking**: Track tokens per file
- **Cost Estimation**: Show estimated cost before processing
- **Batch Optimization**: Group similar files to reduce API calls
- **Caching**: Cache classifications for similar files
- **Budget Limits**: Set monthly/daily spending limits
- **Free Tier Support**: Use free tiers when available

### 2. **Performance Optimization**
- **Batch Processing**: Group files into batches (e.g., 10-50 files per API call)
- **Parallel Processing**: Process multiple batches concurrently
- **Smart Batching**: Group similar files together
- **Retry Logic**: Handle API failures gracefully
- **Rate Limiting**: Respect API rate limits

### 3. **Offline Mode** ✅ FULLY SUPPORTED
- **Local LLM Support**: Use Ollama for offline classification
  - Runs on `localhost:11434`
  - Completely private and offline
  - No API costs
  - Models: llama3.2:1b, mistral:7b, etc.
- **Rule-Based Classifier**: Built-in pattern matching
  - Works offline by default
  - No setup required
  - Instant classification
  - Fallback when LLM unavailable
- **Cached Classifications**: Use previous classifications for similar files
- **Fallback Chain**: Cloud LLM → Ollama → Rule-Based → Keyword Matching

## 🎨 User Experience

### 1. **Classification Workflow**
- **Preview Mode**: Show suggested classifications before applying
- **Bulk Review**: Review all suggestions in a table/list
- **Edit Suggestions**: Manually adjust LLM suggestions
- **Apply Selected**: Only move files user approves
- **Undo Support**: Ability to undo classifications

### 2. **UI Components**
- **Classification View**: 
  - List of files with suggested categories/subfolders
  - Confidence scores (visual indicators)
  - Edit buttons for each suggestion
  - Select all/none checkboxes
  
- **Settings Panel**:
  - API key configuration
  - Model selection
  - Privacy settings
  - Cost/budget settings
  - Classification rules/templates

- **Progress View**:
  - Real-time progress for batch processing
  - Cost tracking during processing
  - Error handling and retry status

### 3. **Feedback Loop**
- **Learning from User Corrections**: 
  - When user edits a suggestion, learn from it
  - Store corrections for future similar files
  - Build local knowledge base
  
- **Confidence Scoring**:
  - High confidence: Auto-apply (optional)
  - Medium confidence: Show for review
  - Low confidence: Always require approval

## 🧠 Intelligence Features

### 1. **Context Awareness**
- **Folder Context**: Consider parent folder when classifying
- **File Relationships**: Group related files together
- **Temporal Patterns**: Consider file dates (e.g., tax documents in April)
- **User Patterns**: Learn from user's manual organization

### 2. **Custom Classification Rules**
- **User Prompts**: Custom instructions for LLM (e.g., "Organize by project, not by type")
- **Template System**: Pre-defined organization templates
  - "By Project"
  - "By Date"
  - "By Type"
  - "By Client"
  - Custom templates

### 3. **Multi-file Analysis**
- **Related Files**: Detect files that belong together
- **Project Detection**: Identify project folders
- **Duplicate Handling**: Classify duplicates appropriately

## 📊 Data & Analytics

### 1. **Classification History**
- **Log of Classifications**: Track what was classified and where
- **Success Metrics**: Track accuracy of suggestions
- **Cost History**: Track API usage and costs over time

### 2. **Reporting**
- **Classification Report**: Summary of files organized
- **Cost Report**: API usage and costs
- **Accuracy Report**: How often user accepted vs. rejected suggestions

## 🔧 Technical Requirements

### 1. **API Integration**
- **OpenAI API**: Support for GPT-3.5, GPT-4, GPT-4 Turbo
- **Anthropic Claude API**: Alternative provider
- **Local LLM**: Ollama integration for offline use
- **Extensible**: Easy to add new providers

### 2. **Prompt Engineering**
- **System Prompt**: Define classification task clearly
- **File Context Prompt**: Include relevant file information
- **User Customization**: Allow user-defined prompts
- **Prompt Templates**: Pre-built prompts for common scenarios

### 3. **Response Parsing**
- **Structured Output**: Use JSON mode or function calling
- **Error Handling**: Parse and handle API errors
- **Fallback Logic**: Handle malformed responses

### 4. **Storage**
- **Classification Cache**: Store classifications to avoid re-querying
- **User Preferences**: Store API keys, settings, templates
- **History Database**: Track classification history

## 🚨 Error Handling & Edge Cases

### 1. **API Failures**
- **Network Errors**: Retry with exponential backoff
- **Rate Limiting**: Queue requests and respect limits
- **API Errors**: Show user-friendly error messages
- **Fallback**: Use keyword matching if LLM fails

### 2. **File Issues**
- **Permission Errors**: Handle files user can't access
- **Large Files**: Skip or handle large files differently
- **Corrupted Files**: Skip files that can't be read
- **Special Files**: Handle symlinks, aliases, etc.

### 3. **Classification Edge Cases**
- **Ambiguous Files**: Handle files that could fit multiple categories
- **New Categories**: Handle LLM suggesting new categories not in system
- **Invalid Suggestions**: Validate LLM output before applying

## 🎯 MVP (Minimum Viable Product) Scope

### Phase 1: Basic LLM Classification
- [ ] OpenAI API integration
- [ ] Basic file classification (filename + metadata only)
- [ ] Preview suggestions before applying
- [ ] Manual approval workflow
- [ ] Basic error handling

### Phase 2: Enhanced Features
- [ ] Batch processing
- [ ] Cost tracking
- [ ] Confidence scores
- [ ] User corrections/learning
- [ ] Multiple API providers

### Phase 3: Advanced Features
- [ ] Content analysis (optional)
- [ ] Local LLM support
- [ ] Custom prompts/templates
- [ ] Advanced analytics
- [ ] Auto-apply for high confidence

## 📝 Example User Flow

1. **User selects folder** to organize
2. **User clicks "AI Classify"** button
3. **App shows cost estimate** (if using paid API)
4. **User confirms** and processing begins
5. **App sends file info to LLM** (filename, metadata, optional preview)
6. **LLM returns suggestions** (category, subfolder, confidence)
7. **App displays suggestions** in review interface
8. **User reviews and edits** as needed
9. **User clicks "Apply"** to move files
10. **App moves files** to suggested locations
11. **App logs results** for future learning

## 📋 Example Metadata Sent to LLM

### Single File Example
```json
{
  "fileName": "Q4_2024_Financial_Report.pdf",
  "fileExtension": "pdf",
  "fileNameWithoutExtension": "Q4_2024_Financial_Report",
  "fileSize": 2458624,
  "fileSizeFormatted": "2.5 MB",
  "creationDate": "2024-10-15T10:30:00Z",
  "modificationDate": "2024-12-20T14:22:00Z",
  "fileType": "com.adobe.pdf",
  "mimeType": "application/pdf",
  "isDirectory": false,
  "parentFolder": "Documents",
  "siblingFiles": ["Invoice_2024.pdf", "Receipt_Nov.pdf", "Tax_Docs"],
  "folderDepth": 2,
  "commonPatterns": ["contains_date", "contains_numbers", "uses_underscores"]
}
```

### Why Metadata-Only Works Well
- **Filename patterns** are highly informative (e.g., "Q4_2024_Financial_Report" → Financial/Documents/2024)
- **File type** indicates category (PDF → Documents, JPG → Photos, etc.)
- **Size** helps identify type (large files often media, small often configs)
- **Dates** provide temporal context (recent files vs. archives)
- **Sibling files** provide context (files in same folder often related)
- **Parent folder** gives organizational context

### What We DON'T Send
- ❌ File content (privacy concern)
- ❌ Full file paths (privacy concern)
- ❌ File hashes or checksums
- ❌ Binary data
- ✅ Only metadata that's already "public" (filename, size, dates)

## 🤔 Open Questions

1. **Content Analysis**: ✅ **RESOLVED** - Metadata-only by default, optional text preview for text files only
2. **Auto-apply**: Should high-confidence suggestions be auto-applied?
3. **Cost Model**: Free tier vs. paid - how to balance?
4. **Privacy**: ✅ **RESOLVED** - Metadata-only is privacy-friendly, works with cloud or local LLM
5. **Learning**: How much should the system learn from user corrections?
6. **Batch Size**: Optimal batch size for API calls? (Recommendation: 10-20 files per batch)
7. **Caching Strategy**: How long to cache classifications? (Recommendation: Cache by filename hash)
8. **Fallback**: When to fall back to keyword matching? (Recommendation: If LLM fails or API unavailable)

## 💡 Future Enhancements

- **Image Classification**: Use vision models for image organization
- **Document Understanding**: Extract metadata from PDFs, Word docs
- **Smart Renaming**: Suggest better filenames based on content
- **Duplicate Detection**: Use LLM to identify semantic duplicates
- **Archive Organization**: Organize old files into archives
- **Integration**: Connect with cloud storage (iCloud, Dropbox, etc.)

