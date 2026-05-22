# API Key Configuration Guide

Complete guide for configuring API keys for all LLM models in FileOrganizerApp.

## 📋 Supported LLM Services

1. **Ollama** (Local AI) - No API key needed
2. **OpenAI** (ChatGPT) - Requires API key
3. **Anthropic** (Claude) - Requires API key
4. **Fallback** (Rule-Based) - No API key needed

---

## 🔑 API Key Configuration Methods

### Method 1: Using Terminal (UserDefaults)

#### OpenAI API Key
```bash
# Set OpenAI API key
defaults write com.fileorganizer.app openai_api_key "sk-your-openai-api-key-here"

# Verify it's set
defaults read com.fileorganizer.app openai_api_key

# Remove API key
defaults delete com.fileorganizer.app openai_api_key
```

#### Anthropic API Key
```bash
# Set Anthropic API key
defaults write com.fileorganizer.app anthropic_api_key "sk-ant-your-anthropic-api-key-here"

# Verify it's set
defaults read com.fileorganizer.app anthropic_api_key

# Remove API key
defaults delete com.fileorganizer.app anthropic_api_key
```

### Method 2: Using Swift Code (Programmatically)

```swift
import Foundation

// Set OpenAI API key
UserDefaults.standard.set("sk-your-openai-api-key-here", forKey: "openai_api_key")

// Set Anthropic API key
UserDefaults.standard.set("sk-ant-your-anthropic-api-key-here", forKey: "anthropic_api_key")

// Verify keys are set
let openAIKey = UserDefaults.standard.string(forKey: "openai_api_key")
let anthropicKey = UserDefaults.standard.string(forKey: "anthropic_api_key")

// Remove keys
UserDefaults.standard.removeObject(forKey: "openai_api_key")
UserDefaults.standard.removeObject(forKey: "anthropic_api_key")
```

### Method 3: Environment Variables (For Testing)

```bash
# Set environment variables
export OPENAI_API_KEY="sk-your-openai-api-key-here"
export ANTHROPIC_API_KEY="sk-ant-your-anthropic-api-key-here"

# Run the app with environment variables
swift run
```

---

## 🔐 Getting API Keys

### OpenAI (ChatGPT)

1. **Get API Key:**
   - Visit: https://platform.openai.com/api-keys
   - Sign up or log in
   - Click "Create new secret key"
   - Copy the key (starts with `sk-`)
   - ⚠️ **Save it immediately** - you won't see it again!

2. **API Key Format:**
   - Starts with: `sk-`
   - Example: `sk-proj-abc123def456...`

3. **Default Model:** `gpt-4`
   - Available models: `gpt-4`, `gpt-4-turbo`, `gpt-3.5-turbo`
   - Can be changed in code: `OpenAILLMService(apiKey: key, model: "gpt-3.5-turbo")`

4. **Default Settings:**
   - `maxTokens`: 500
   - `temperature`: 0.3

### Anthropic (Claude)

1. **Get API Key:**
   - Visit: https://console.anthropic.com/
   - Sign up or log in
   - Go to "API Keys" section
   - Click "Create Key"
   - Copy the key (starts with `sk-ant-`)
   - ⚠️ **Save it immediately** - you won't see it again!

2. **API Key Format:**
   - Starts with: `sk-ant-`
   - Example: `sk-ant-api03-abc123def456...`

3. **Default Model:** `claude-3-sonnet-20240229`
   - Available models:
     - `claude-3-opus-20240229` (Most capable, expensive)
     - `claude-3-sonnet-20240229` (Balanced, default)
     - `claude-3-haiku-20240307` (Fastest, cheapest)
   - Can be changed in code: `AnthropicLLMService(apiKey: key, model: "claude-3-haiku-20240307")`

4. **Default Settings:**
   - `maxTokens`: 500
   - `temperature`: 0.3

### Ollama (Local - No API Key)

1. **Installation:**
   ```bash
   # macOS
   brew install ollama
   
   # Or download from: https://ollama.ai
   ```

2. **Start Ollama:**
   ```bash
   ollama serve
   ```

3. **Download a Model:**
   ```bash
   ollama pull llama3.2:3b
   # or
   ollama pull mistral:7b
   ```

4. **Default Settings:**
   - `baseURL`: `http://localhost:11434`
   - `model`: `llama3.2:3b`
   - `temperature`: 0.1
   - `topP`: 0.95
   - `topK`: 40

---

## ⚙️ Advanced Configuration

### Custom Model Selection

#### OpenAI
```swift
let llmService = OpenAILLMService(
    apiKey: "sk-...",
    model: "gpt-4-turbo",  // Change model
    maxTokens: 1000        // Change max tokens
)
```

#### Anthropic
```swift
let llmService = AnthropicLLMService(
    apiKey: "sk-ant-...",
    model: "claude-3-opus-20240229",  // Change model
    maxTokens: 1000                   // Change max tokens
)
```

#### Ollama
```swift
let llmService = OllamaLLMService(
    baseURL: URL(string: "http://localhost:11434"),
    model: "mistral:7b",      // Change model
    temperature: 0.2,         // Change temperature
    topP: 0.9,                // Change top_p
    topK: 50                  // Change top_k
)
```

---

## 🔍 Verification

### Check if API Keys are Configured

#### In Terminal:
```bash
# Check OpenAI key
defaults read com.fileorganizer.app openai_api_key

# Check Anthropic key
defaults read com.fileorganizer.app anthropic_api_key
```

#### In Swift:
```swift
let hasOpenAI = UserDefaults.standard.string(forKey: "openai_api_key") != nil
let hasAnthropic = UserDefaults.standard.string(forKey: "anthropic_api_key") != nil

print("OpenAI configured: \(hasOpenAI)")
print("Anthropic configured: \(hasAnthropic)")
```

#### In App:
- The service selection UI will show which services are available
- Services with configured API keys will be enabled
- Services without API keys will be disabled/grayed out

---

## 🔒 Security Best Practices

### Current Implementation (UserDefaults)
- ⚠️ **Warning**: API keys are stored in UserDefaults (plain text)
- ✅ **Better**: Should use Keychain for secure storage (see below)

### Recommended: Use Keychain

The app should migrate to Keychain storage. Example implementation:

```swift
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.fileorganizer.app"
    
    func store(apiKey: String, for serviceName: String) throws {
        let data = apiKey.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).\(serviceName)",
            kSecAttrAccount as String: "apiKey",
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainError", code: Int(status))
        }
    }
    
    func retrieve(for serviceName: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).\(serviceName)",
            kSecAttrAccount as String: "apiKey",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return apiKey
    }
}

// Usage:
try KeychainManager.shared.store(apiKey: "sk-...", for: "openai")
let key = KeychainManager.shared.retrieve(for: "openai")
```

---

## 📊 Service Comparison

| Service | API Key Required | Cost | Speed | Privacy | Models |
|---------|-----------------|------|-------|---------|--------|
| **Ollama** | ❌ No | Free | Medium | ✅ 100% Private | llama3.2, mistral, etc. |
| **OpenAI** | ✅ Yes | Paid | Fast | ⚠️ Cloud | gpt-4, gpt-3.5-turbo |
| **Anthropic** | ✅ Yes | Paid | Fast | ⚠️ Cloud | claude-3-opus, sonnet, haiku |
| **Fallback** | ❌ No | Free | Instant | ✅ 100% Private | Rule-based |

---

## 🛠️ Troubleshooting

### API Key Not Working

1. **Verify key is set:**
   ```bash
   defaults read com.fileorganizer.app openai_api_key
   ```

2. **Check key format:**
   - OpenAI: Should start with `sk-`
   - Anthropic: Should start with `sk-ant-`

3. **Test API key directly:**
   ```bash
   # Test OpenAI
   curl https://api.openai.com/v1/models \
     -H "Authorization: Bearer sk-your-key-here"
   
   # Test Anthropic
   curl https://api.anthropic.com/v1/messages \
     -H "x-api-key: sk-ant-your-key-here" \
     -H "anthropic-version: 2023-06-01" \
     -H "Content-Type: application/json" \
     -d '{"model":"claude-3-sonnet-20240229","max_tokens":10,"messages":[{"role":"user","content":"test"}]}'
   ```

### Service Not Available in UI

- Check if API key is configured
- Restart the app after setting API key
- Check console for error messages

### Rate Limiting

- OpenAI: Check your rate limits at https://platform.openai.com/account/limits
- Anthropic: Check your rate limits at https://console.anthropic.com/settings/limits
- Consider using Ollama for unlimited local requests

---

## 📝 Quick Reference

### Storage Keys
- OpenAI: `openai_api_key`
- Anthropic: `anthropic_api_key`

### Default Models
- OpenAI: `gpt-4`
- Anthropic: `claude-3-sonnet-20240229`
- Ollama: `llama3.2:3b`

### API Endpoints
- OpenAI: `https://api.openai.com/v1/chat/completions`
- Anthropic: `https://api.anthropic.com/v1/messages`
- Ollama: `http://localhost:11434/api/generate`

---

## 🎯 Next Steps

1. **Set your API keys** using one of the methods above
2. **Launch the app** and select your preferred service
3. **Test classification** with a small batch of files
4. **Monitor costs** if using cloud services
5. **Consider Keychain migration** for production use

---

**Note**: For production use, consider implementing Keychain storage for better security.

