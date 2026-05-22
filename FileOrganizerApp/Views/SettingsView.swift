import SwiftUI

struct SettingsView: View {
    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var showOpenAIKey: Bool = false
    @State private var showAnthropicKey: Bool = false
    @State private var hasExistingOpenAIKey: Bool = false
    @State private var hasExistingAnthropicKey: Bool = false
    @State private var openAISaved: Bool = false
    @State private var anthropicSaved: Bool = false
    @State private var openAITesting: Bool = false
    @State private var anthropicTesting: Bool = false
    @State private var openAITestResult: String? = nil
    @State private var anthropicTestResult: String? = nil
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var classificationMode: ClassificationMode = ClassificationMode.persisted
    @ObservedObject private var profileStore = ProfileStore.shared
    @State private var aliasesText: String = ""
    @State private var employersText: String = ""
    @State private var newPersonName: String = ""
    @State private var newPersonTokens: String = ""
    @State private var profileSavedMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                
                Divider()
                
                classificationSection

                Divider()

                profileSection

                Divider()
                
                openAISection
                
                Divider()
                
                anthropicSection
                
                Divider()
                
                ollamaSection
                
                Divider()
                
                infoSection
            }
            .padding(24)
            .frame(maxWidth: 700)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadAPIKeys()
            loadProfileFields()
            AppActivation.activate()
        }
        .onTapGesture {
            AppActivation.activate()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        SettingsPageHeader(
            title: "Settings",
            subtitle: "Classification style, your profile, and AI service configuration."
        )
    }

    // MARK: - Classification Section

    private var classificationSection: some View {
        SettingsSection(
            icon: "folder.badge.gearshape",
            iconColor: .blue,
            title: "Classification Style",
            subtitle: "Default for AI classification runs"
        ) {
            Picker("Style", selection: $classificationMode) {
                ForEach(ClassificationMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .onChange(of: classificationMode) { _, newValue in
                ClassificationMode.persisted = newValue
            }

            Text(classificationMode.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            classificationMode = ClassificationMode.persisted
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        SettingsSection(
            icon: "person.crop.circle",
            iconColor: .purple,
            title: "About Me",
            subtitle: "Subject-aware filing: your files vs other people; region only when not default"
        ) {
            MacTextField(
                text: profileBinding(\.fullName),
                placeholder: "Full name",
                focusOnAppear: profileStore.profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .frame(height: 24)

            MacTextField(text: $aliasesText, placeholder: "Also called (comma-separated aliases)")
                .frame(height: 24)

            MacTextField(text: profileOptionalStringBinding(\.homeRegion), placeholder: "Default region (e.g. California)")
                .frame(height: 24)

            Text("Only non-default regions become folder names (e.g. New-York/Finance/…). Default region is not prefixed on every file.")
                .font(.caption)
                .foregroundColor(.secondary)

            MacTextField(text: $employersText, placeholder: "Employers (optional, comma-separated)")
                .frame(height: 24)

            Toggle("File other people's documents under Others/", isOn: profileBinding(\.enableSubjectFolders))

            HStack {
                Text("Others folder name")
                MacTextField(text: profileBinding(\.othersRootFolderName), placeholder: "Others")
                    .frame(width: 140, height: 24)
            }

            Divider()

            Text("Known other people (optional)")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                MacTextField(text: $newPersonName, placeholder: "Display name")
                    .frame(height: 24)
                MacTextField(text: $newPersonTokens, placeholder: "Match tokens (comma-separated)")
                    .frame(height: 24)
                Button("Add") {
                    profileStore.addKnownPerson(
                        displayName: newPersonName,
                        matchTokens: newPersonTokens
                    )
                    newPersonName = ""
                    newPersonTokens = ""
                }
                .disabled(newPersonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if profileStore.knownPeople.isEmpty {
                Text("Example: Jon Richardson — richardson, jon-paul, jon_paul")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                List {
                    ForEach(profileStore.knownPeople) { person in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.displayName)
                                .fontWeight(.medium)
                            Text(person.matchTokens.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete { profileStore.removeKnownPerson(at: $0) }
                }
                .frame(minHeight: 80, maxHeight: 160)
            }

            HStack {
                Button("Save Profile") {
                    saveProfileFields()
                }
                .buttonStyle(.borderedProminent)

                if let msg = profileSavedMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }

    private func loadProfileFields() {
        aliasesText = profileStore.profile.nameAliases.joined(separator: ", ")
        employersText = profileStore.profile.employers.joined(separator: ", ")
    }

    private func profileBinding(_ keyPath: WritableKeyPath<UserProfile, String>) -> Binding<String> {
        Binding(
            get: { profileStore.profile[keyPath: keyPath] },
            set: { newValue in profileStore.updateProfile { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func profileBinding(_ keyPath: WritableKeyPath<UserProfile, Bool>) -> Binding<Bool> {
        Binding(
            get: { profileStore.profile[keyPath: keyPath] },
            set: { newValue in profileStore.updateProfile { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func profileOptionalStringBinding(_ keyPath: WritableKeyPath<UserProfile, String?>) -> Binding<String> {
        Binding(
            get: { profileStore.profile[keyPath: keyPath] ?? "" },
            set: { newValue in
                profileStore.updateProfile { $0[keyPath: keyPath] = newValue.isEmpty ? nil : newValue }
            }
        )
    }

    private func saveProfileFields() {
        profileStore.updateProfile { profile in
            profile.nameAliases = aliasesText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            profile.employers = employersText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        profileStore.save()
        profileSavedMessage = "Saved"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            profileSavedMessage = nil
        }
    }

    // MARK: - OpenAI Section
    
    private var openAISection: some View {
        SettingsSection(
            icon: "brain",
            iconColor: .green,
            title: "OpenAI (ChatGPT)",
            subtitle: "GPT-4, GPT-3.5 Turbo models",
            trailing: {
                statusBadge(isConfigured: hasExistingOpenAIKey, isTesting: openAITesting, testResult: openAITestResult)
            }
        ) {
            openAIKeyContent
        }
    }

    @ViewBuilder
    private var openAIKeyContent: some View {
        apiKeyEditor(
            key: $openAIKey,
            showKey: $showOpenAIKey,
            hasExisting: hasExistingOpenAIKey,
            placeholder: "sk-...",
            onClear: {
                openAIKey = ""
                UserDefaults.standard.removeObject(forKey: "openai_api_key")
                hasExistingOpenAIKey = false
            },
            onSave: saveOpenAIKey,
            onTest: testOpenAIKey,
            isSaved: openAISaved,
            isTesting: openAITesting,
            testResult: openAITestResult,
            keyURL: URL(string: "https://platform.openai.com/api-keys")!
        )
    }
    
    // MARK: - Anthropic Section
    
    private var anthropicSection: some View {
        SettingsSection(
            icon: "sparkles",
            iconColor: .purple,
            title: "Anthropic (Claude)",
            subtitle: "Claude 3 Opus, Sonnet, Haiku models",
            trailing: {
                statusBadge(isConfigured: hasExistingAnthropicKey, isTesting: anthropicTesting, testResult: anthropicTestResult)
            }
        ) {
            apiKeyEditor(
                key: $anthropicKey,
                showKey: $showAnthropicKey,
                hasExisting: hasExistingAnthropicKey,
                placeholder: "sk-ant-...",
                onClear: {
                    anthropicKey = ""
                    UserDefaults.standard.removeObject(forKey: "anthropic_api_key")
                    hasExistingAnthropicKey = false
                },
                onSave: saveAnthropicKey,
                onTest: testAnthropicKey,
                isSaved: anthropicSaved,
                isTesting: anthropicTesting,
                testResult: anthropicTestResult,
                keyURL: URL(string: "https://console.anthropic.com/")!
            )
        }
    }
    
    // MARK: - Ollama Section
    
    private var ollamaSection: some View {
        SettingsSection(
            icon: "server.rack",
            iconColor: .blue,
            title: "Ollama (Local AI)",
            subtitle: "Runs locally, no API key needed",
            trailing: { ollamaStatusBadge }
        ) {
            Text("Ollama runs on your local machine. No API key required.")
                .font(.caption)
                .foregroundColor(.secondary)

            Link("Install Ollama", destination: URL(string: "https://ollama.ai")!)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var ollamaStatusBadge: some View {
        if checkOllamaAvailable() {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Available")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.orange)
                Text("Not Running")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        SettingsSection(
            icon: "info.circle",
            iconColor: .secondary,
            title: "Information",
            subtitle: "Security, cost, and privacy notes"
        ) {
            InfoRow(
                icon: "lock.shield",
                title: "Security",
                description: "API keys are stored locally in UserDefaults. For production use, consider Keychain storage."
            )

            InfoRow(
                icon: "dollarsign.circle",
                title: "Costs",
                description: "OpenAI and Anthropic are paid services. Ollama is free and runs locally."
            )

            InfoRow(
                icon: "eye.slash",
                title: "Privacy",
                description: "Ollama keeps all data local. Cloud services send file metadata to their servers."
            )
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func apiKeyEditor(
        key: Binding<String>,
        showKey: Binding<Bool>,
        hasExisting: Bool,
        placeholder: String,
        onClear: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onTest: @escaping () -> Void,
        isSaved: Bool,
        isTesting: Bool,
        testResult: String?,
        keyURL: URL
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Key")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Group {
                    if showKey.wrappedValue {
                        TextField(hasExisting ? "API key is set (click to change)" : placeholder, text: key)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField(hasExisting ? "API key is set (click to change)" : placeholder, text: key)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Button(action: { showKey.wrappedValue.toggle() }) {
                    Image(systemName: showKey.wrappedValue ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(showKey.wrappedValue ? "Hide API key" : "Show API key")

                if !key.wrappedValue.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear API key")
                }
            }

            HStack(spacing: 12) {
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(key.wrappedValue.isEmpty)

                Button("Test", action: onTest)
                    .buttonStyle(.bordered)
                    .disabled(key.wrappedValue.isEmpty || isTesting)

                if isSaved {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Saved")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                if isTesting {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Testing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let result = testResult {
                    HStack(spacing: 4) {
                        Image(systemName: result.contains("Success") ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.contains("Success") ? .green : .red)
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("Success") ? .green : .red)
                    }
                }
            }

            if !key.wrappedValue.isEmpty {
                Link("Get API Key", destination: keyURL)
                    .font(.caption)
            }
        }
    }

    private func statusBadge(isConfigured: Bool, isTesting: Bool, testResult: String?) -> some View {
        Group {
            if isTesting {
                ProgressView()
                    .scaleEffect(0.7)
            } else if let result = testResult {
                if result.contains("Success") {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Valid")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Invalid")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            } else if isConfigured {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Configured")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Not Set")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Methods
    
    private func loadAPIKeys() {
        // Check if keys exist (but don't load them for security)
        hasExistingOpenAIKey = UserDefaults.standard.string(forKey: "openai_api_key") != nil
        hasExistingAnthropicKey = UserDefaults.standard.string(forKey: "anthropic_api_key") != nil
        
        // Keep fields empty - don't set placeholder as actual value
        // This allows text to display properly when user types/pastes
        openAIKey = ""
        anthropicKey = ""
    }
    
    private func saveOpenAIKey() {
        guard !openAIKey.isEmpty else {
            showError(message: "Please enter an API key to save")
            return
        }
        
        guard openAIKey.hasPrefix("sk-") else {
            showError(message: "Invalid OpenAI API key format. Should start with 'sk-'")
            return
        }
        
        UserDefaults.standard.set(openAIKey, forKey: "openai_api_key")
        hasExistingOpenAIKey = true
        openAISaved = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            openAISaved = false
        }
    }
    
    private func saveAnthropicKey() {
        guard !anthropicKey.isEmpty else {
            showError(message: "Please enter an API key to save")
            return
        }
        
        guard anthropicKey.hasPrefix("sk-ant-") else {
            showError(message: "Invalid Anthropic API key format. Should start with 'sk-ant-'")
            return
        }
        
        UserDefaults.standard.set(anthropicKey, forKey: "anthropic_api_key")
        hasExistingAnthropicKey = true
        anthropicSaved = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            anthropicSaved = false
        }
    }
    
    private func testOpenAIKey() {
        // Get actual key from UserDefaults if testing existing key
        let keyToTest: String
        if openAIKey.isEmpty {
            if let existingKey = UserDefaults.standard.string(forKey: "openai_api_key") {
                keyToTest = existingKey
            } else {
                showError(message: "Please enter a valid API key to test")
                return
            }
        } else {
            keyToTest = openAIKey
        }
        
        guard !keyToTest.isEmpty else {
            showError(message: "Please enter a valid API key to test")
            return
        }
        
        openAITesting = true
        openAITestResult = nil
        
        Task {
            do {
                let service = OpenAILLMService(apiKey: keyToTest, model: "gpt-3.5-turbo", maxTokens: 10)
                _ = try await service.generateCompletion(prompt: "test")
                await MainActor.run {
                    openAITesting = false
                    openAITestResult = "Success: API key is valid"
                }
            } catch {
                await MainActor.run {
                    openAITesting = false
                    openAITestResult = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func testAnthropicKey() {
        // Get actual key from UserDefaults if testing existing key
        let keyToTest: String
        if anthropicKey.isEmpty {
            if let existingKey = UserDefaults.standard.string(forKey: "anthropic_api_key") {
                keyToTest = existingKey
            } else {
                showError(message: "Please enter a valid API key to test")
                return
            }
        } else {
            keyToTest = anthropicKey
        }
        
        guard !keyToTest.isEmpty else {
            showError(message: "Please enter a valid API key to test")
            return
        }
        
        anthropicTesting = true
        anthropicTestResult = nil
        
        Task {
            do {
                let service = AnthropicLLMService(apiKey: keyToTest, model: "claude-3-haiku-20240307", maxTokens: 10)
                _ = try await service.generateCompletion(prompt: "test")
                await MainActor.run {
                    anthropicTesting = false
                    anthropicTestResult = "Success: API key is valid"
                }
            } catch {
                await MainActor.run {
                    anthropicTesting = false
                    anthropicTestResult = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func checkOllamaAvailable() -> Bool {
        let url = URL(string: "http://localhost:11434/api/tags")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        
        var isAvailable = false
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                isAvailable = httpResponse.statusCode == 200
            }
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 1.5)
        return isAvailable
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

