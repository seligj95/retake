import Foundation
import AppKit
import Observation

/// Checks GitHub Releases for new versions and can download + install updates.
@MainActor
@Observable
final class UpdateService {
    static let shared = UpdateService()

    private let repo = "seligj95/retake"

    var latestVersion: String?
    var releaseURL: URL?       // GitHub release page
    var downloadURL: URL?      // Direct .zip download
    var releaseNotes: String?
    var isChecking = false
    var isDownloading = false
    var downloadProgress: Double = 0
    var error: String?

    var updateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return AppVersion.compare(AppVersion.current, latest) == .orderedAscending
    }

    /// Check GitHub for the latest release.
    func checkForUpdates() async {
        isChecking = true
        error = nil
        defer { isChecking = false }

        let urlString = "https://api.github.com/repos/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                return
            }

            if httpResponse.statusCode == 404 {
                latestVersion = nil
                return
            }

            guard httpResponse.statusCode == 200 else {
                error = "GitHub returned status \(httpResponse.statusCode)"
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                error = "Invalid JSON"
                return
            }

            if let tagName = json["tag_name"] as? String {
                let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                latestVersion = version
            }

            if let htmlURL = json["html_url"] as? String {
                releaseURL = URL(string: htmlURL)
            }

            releaseNotes = json["body"] as? String

            if let assets = json["assets"] as? [[String: Any]] {
                for asset in assets {
                    if let name = asset["name"] as? String,
                       name.hasSuffix(".zip") && name.contains("Retake"),
                       let downloadURLString = asset["browser_download_url"] as? String {
                        downloadURL = URL(string: downloadURLString)
                        break
                    }
                }
            }
        } catch {
            self.error = "Network error: \(error.localizedDescription)"
        }
    }

    /// Download the latest release and install it.
    func downloadAndInstall() async {
        guard let downloadURL else {
            if let releaseURL {
                NSWorkspace.shared.open(releaseURL)
            }
            return
        }

        isDownloading = true
        downloadProgress = 0
        error = nil
        defer { isDownloading = false }

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: downloadURL)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                error = "Download failed"
                return
            }

            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("RetakeUpdate-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let zipPath = tempDir.appendingPathComponent("Retake.app.zip")
            try FileManager.default.moveItem(at: tempURL, to: zipPath)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", zipPath.path, tempDir.path]
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                error = "Failed to unzip update"
                return
            }

            let extractedApp = tempDir.appendingPathComponent("Retake.app")
            guard FileManager.default.fileExists(atPath: extractedApp.path) else {
                error = "Retake.app not found in download"
                return
            }

            let currentAppPath = Bundle.main.bundlePath
            let appURL = URL(fileURLWithPath: currentAppPath)

            if currentAppPath.hasPrefix("/Applications") {
                try FileManager.default.trashItem(at: appURL, resultingItemURL: nil)
                try FileManager.default.copyItem(at: extractedApp, to: appURL)
            } else {
                let destURL = URL(fileURLWithPath: "/Applications/Retake.app")
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.trashItem(at: destURL, resultingItemURL: nil)
                }
                try FileManager.default.copyItem(at: extractedApp, to: destURL)
            }

            try? FileManager.default.removeItem(at: tempDir)

            relaunch()
        } catch {
            self.error = "Update failed: \(error.localizedDescription)"
        }
    }

    private func relaunch() {
        let appPath: String
        if Bundle.main.bundlePath.hasPrefix("/Applications") {
            appPath = Bundle.main.bundlePath
        } else {
            appPath = "/Applications/Retake.app"
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1 && open \"\(appPath)\""]
        try? process.run()

        NSApp.terminate(nil)
    }
}
