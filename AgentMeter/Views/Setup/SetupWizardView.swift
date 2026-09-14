import SwiftUI
import AppKit

struct SetupWizardView: View {
    @Bindable var appModel: AppModel

    @State private var sessionKeyInput: String = ""
    @State private var isSessionKeyShown: Bool = false
    @State private var isValidating: Bool = false
    @State private var isImporting: Bool = false
    @State private var errorMessage: String?
    @State private var offersFullDiskAccessSettings: Bool = false
    @State private var hasValidationSucceeded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }

                Text("Welcome to \(AppIdentity.displayName)")
                    .font(.title3.weight(.semibold))

                Text("Track Claude and Codex from the menu bar. Start with your Claude session.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    Task {
                        await importAndSave()
                    }
                } label: {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isImporting ? "Importing…" : "Import from Browser")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isBusy)
                .accessibilityLabel(isImporting ? "Importing session" : "Import session from browser")
                .accessibilityHint("Uses the claude.ai session in a signed-in browser")

                Text("Uses the claude.ai session in Chrome, Arc, Brave, Edge, or Safari.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    VStack { Divider() }
                    Text("or paste a session")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    VStack { Divider() }
                }
                .padding(.vertical, 2)

                HStack(spacing: 8) {
                    Group {
                        if isSessionKeyShown {
                            TextField("sk-ant-…", text: $sessionKeyInput)
                        } else {
                            SecureField("sk-ant-…", text: $sessionKeyInput)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .disabled(isBusy)
                    .accessibilityLabel("Claude session")
                    .accessibilityHint("Paste a Claude session key or a Cookie header containing sessionKey")

                    Button {
                        isSessionKeyShown.toggle()
                    } label: {
                        Image(systemName: isSessionKeyShown ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(isSessionKeyShown ? "Hide session" : "Show session")
                    .disabled(isBusy)
                }

                if !sessionKeyInput.isEmpty && !isFormatValid {
                    Text("This doesn't look like a Claude session.")
                        .font(.caption)
                        .foregroundStyle(Color(nsColor: .systemRed))
                }
            }
            .padding(.horizontal, 28)

            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(nsColor: .systemOrange))
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if offersFullDiskAccessSettings {
                        Button("Open Full Disk Access") {
                            SystemSettingsOpener.openFullDiskAccess()
                        }
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .systemOrange).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .accessibilityLabel("Error: \(errorMessage)")
            }

            if hasValidationSucceeded {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(nsColor: .systemGreen))
                    Text("Connected")
                        .font(.callout)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .systemGreen).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 28)
                .padding(.top, 12)
            }

            Spacer(minLength: 16)

            if !sessionKeyInput.isEmpty {
                Button {
                    Task {
                        await validateAndSave()
                    }
                } label: {
                    Text(isValidating ? "Checking…" : "Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!isFormatValid || isBusy)
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
                .accessibilityLabel(isValidating ? "Checking session" : "Continue with pasted session")
            } else {
                Color.clear
                    .frame(height: 24)
            }
        }
        .frame(width: 370, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var isBusy: Bool {
        isValidating || isImporting
    }

    private var isFormatValid: Bool {
        let trimmed = sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = SessionKey.extractSessionKeyValue(from: trimmed) else { return false }
        return value.hasPrefix("sk-ant-") && value.count > 10
    }

    @MainActor
    private func importAndSave() async {
        isImporting = true
        errorMessage = nil
        offersFullDiskAccessSettings = false
        hasValidationSucceeded = false

        do {
            let imported = try await appModel.importAndSaveSessionKey()
            sessionKeyInput = imported.value
            hasValidationSucceeded = true
        } catch let error as SessionKeyImportError {
            errorMessage = error.localizedDescription
            offersFullDiskAccessSettings = error.offersFullDiskAccessSettings
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isImporting = false
    }

    @MainActor
    private func validateAndSave() async {
        guard !sessionKeyInput.isEmpty else {
            errorMessage = "Enter a Claude session."
            hasValidationSucceeded = false
            return
        }

        isValidating = true
        errorMessage = nil
        offersFullDiskAccessSettings = false
        hasValidationSucceeded = false

        do {
            let isValid = try await appModel.validateAndSaveSessionKey(sessionKeyInput)
            if isValid {
                hasValidationSucceeded = true
            } else {
                errorMessage = "Claude session expired. Sign in again and retry."
            }
        } catch let error as SessionKeyError {
            errorMessage = error.localizedDescription
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isValidating = false
    }
}
