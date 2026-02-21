import SwiftUI

struct AboutWindow: View {
    var updateService: UpdateService
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "record.circle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text("Retake")
                .font(.title)
                .fontWeight(.bold)
            Text("Version \(AppVersion.current)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Screen recording with live redo, redaction, trim, and pause.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Divider()
                .padding(.horizontal, 40)

            // Update section
            updateSection

            Spacer()

            Link("GitHub", destination: URL(string: "https://github.com/seligj95/retake")!)
                .font(.caption)

            Text("© 2026 Jordan Selig — MIT License")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 340, height: 380)
        .padding()
        .task {
            await updateService.checkForUpdates()
        }
    }

    @ViewBuilder
    private var updateSection: some View {
        if updateService.isChecking {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking for updates...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if updateService.updateAvailable, let latest = updateService.latestVersion {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Version \(latest) available!")
                        .font(.caption)
                        .fontWeight(.medium)
                }

                if let notes = updateService.releaseNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .frame(maxWidth: 280)
                }

                if updateService.isDownloading {
                    ProgressView("Downloading update...")
                        .controlSize(.small)
                } else {
                    HStack(spacing: 12) {
                        if updateService.downloadURL != nil {
                            Button("Install Update") {
                                Task { await updateService.downloadAndInstall() }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        if let releaseURL = updateService.releaseURL {
                            Button("View Release") {
                                NSWorkspace.shared.open(releaseURL)
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        } else if let error = updateService.error {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button("Retry") {
                Task { await updateService.checkForUpdates() }
            }
            .controlSize(.small)
        } else {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
                Text("You're up to date")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Check for Updates") {
                Task { await updateService.checkForUpdates() }
            }
            .controlSize(.small)
        }
    }
}
