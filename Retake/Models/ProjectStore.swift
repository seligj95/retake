import Foundation
import AVFoundation
import Observation

/// Manages project persistence: saving, loading, and tracking recent projects
/// Supports both directory bundle (.retakeproject) and JSON sidecar (.retakeproject.json) formats
@MainActor
@Observable
final class ProjectStore {
    
    /// Errors that can occur during project operations
    enum ProjectStoreError: LocalizedError {
        case invalidProjectFormat
        case fileReadFailed(URL)
        case fileWriteFailed(URL, Error)
        case decodingFailed(Error)
        case encodingFailed(Error)
        case projectNotFound(URL)
        case bundleCreationFailed(URL)
        
        var errorDescription: String? {
            switch self {
            case .invalidProjectFormat:
                return "Invalid project file format"
            case .fileReadFailed(let url):
                return "Failed to read project file at \(url.path)"
            case .fileWriteFailed(let url, let error):
                return "Failed to write project file at \(url.path): \(error.localizedDescription)"
            case .decodingFailed(let error):
                return "Failed to decode project data: \(error.localizedDescription)"
            case .encodingFailed(let error):
                return "Failed to encode project data: \(error.localizedDescription)"
            case .projectNotFound(let url):
                return "Project not found at \(url.path)"
            case .bundleCreationFailed(let url):
                return "Failed to create project bundle at \(url.path)"
            }
        }
    }
    
    /// Format for saving projects
    enum ProjectFormat {
        /// Directory bundle (.retakeproject package) — contains project.json + raw video + assets
        case bundle
        
        /// JSON sidecar (.retakeproject.json) — JSON file next to raw video
        case sidecar
    }
    
    // MARK: - State
    
    /// List of recent project URLs (max 10, most recent first)
    private(set) var recentProjects: [URL] = []
    
    /// UserDefaults key for recent projects list
    private let recentProjectsKey = "com.retake.recentProjects"
    
    /// Maximum number of recent projects to track
    private let maxRecentProjects = 10
    
    /// File manager for I/O operations
    private let fileManager = FileManager.default
    
    /// JSON encoder with pretty printing
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return enc
    }()
    
    /// JSON decoder
    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()
    
    // MARK: - Initialization
    
    init() {
        loadRecentProjects()
    }
    
    // MARK: - Save Operations
    
    /// Save a project to disk
    /// - Parameters:
    ///   - project: The project to save
    ///   - format: The format to save in (bundle or sidecar)
    ///   - url: Optional destination URL (defaults to project name in Documents)
    /// - Returns: URL where the project was saved
    @discardableResult
    func save(project: Project, format: ProjectFormat = .bundle, to url: URL? = nil) async throws -> URL {
        let destinationURL = url ?? defaultProjectURL(for: project, format: format)
        
        switch format {
        case .bundle:
            try await saveAsBundle(project: project, to: destinationURL)
        case .sidecar:
            try await saveAsSidecar(project: project, to: destinationURL)
        }
        
        // Add to recent projects list
        addToRecentProjects(url: destinationURL)
        
        return destinationURL
    }
    
    /// Save project as a directory bundle (.retakeproject)
    private func saveAsBundle(project: Project, to bundleURL: URL) async throws {
        // Create bundle directory
        do {
            try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        } catch {
            throw ProjectStoreError.bundleCreationFailed(bundleURL)
        }
        
        // Save project.json
        let projectJSONURL = bundleURL.appendingPathComponent("project.json")
        try await saveProjectJSON(project: project, to: projectJSONURL)
        
        // Copy raw video into bundle if it's not already inside
        let bundledVideoURL = bundleURL.appendingPathComponent("raw-video.mov")
        if !project.rawVideoURL.path.starts(with: bundleURL.path) {
            do {
                if fileManager.fileExists(atPath: bundledVideoURL.path) {
                    try fileManager.removeItem(at: bundledVideoURL)
                }
                try fileManager.copyItem(at: project.rawVideoURL, to: bundledVideoURL)
            } catch {
                throw ProjectStoreError.fileWriteFailed(bundledVideoURL, error)
            }
        }
        
        // Future: Copy exported videos, thumbnails, waveform cache, etc.
    }
    
    /// Save project as a JSON sidecar (.demoproject.json)
    private func saveAsSidecar(project: Project, to sidecarURL: URL) async throws {
        try await saveProjectJSON(project: project, to: sidecarURL)
    }
    
    /// Encode and write project to JSON file
    private func saveProjectJSON(project: Project, to url: URL) async throws {
        let data: Data
        do {
            data = try encoder.encode(project)
        } catch {
            throw ProjectStoreError.encodingFailed(error)
        }
        
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            throw ProjectStoreError.fileWriteFailed(url, error)
        }
    }
    
    // MARK: - Load Operations
    
    /// Load a project from disk
    /// - Parameter url: URL to .retakeproject bundle or .retakeproject.json file
    /// - Returns: Loaded project
    func load(from url: URL) async throws -> Project {
        guard fileManager.fileExists(atPath: url.path) else {
            throw ProjectStoreError.projectNotFound(url)
        }
        
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        
        let project: Project
        if isDirectory.boolValue {
            // Load from bundle
            project = try await loadFromBundle(url: url)
        } else {
            // Load from sidecar JSON
            project = try await loadFromSidecar(url: url)
        }
        
        // Add to recent projects list
        addToRecentProjects(url: url)
        
        return project
    }
    
    /// Load project from directory bundle
    private func loadFromBundle(url bundleURL: URL) async throws -> Project {
        let projectJSONURL = bundleURL.appendingPathComponent("project.json")
        
        guard fileManager.fileExists(atPath: projectJSONURL.path) else {
            throw ProjectStoreError.invalidProjectFormat
        }
        
        return try await loadProjectJSON(from: projectJSONURL)
    }
    
    /// Load project from JSON sidecar
    private func loadFromSidecar(url: URL) async throws -> Project {
        return try await loadProjectJSON(from: url)
    }
    
    /// Decode project from JSON file
    private func loadProjectJSON(from url: URL) async throws -> Project {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ProjectStoreError.fileReadFailed(url)
        }
        
        do {
            return try decoder.decode(Project.self, from: data)
        } catch {
            throw ProjectStoreError.decodingFailed(error)
        }
    }
    
    // MARK: - Recent Projects Management
    
    /// Get list of recent projects (cached in memory)
    func listRecentProjects() -> [URL] {
        return recentProjects
    }
    
    /// Add a project URL to recent projects list
    private func addToRecentProjects(url: URL) {
        // Remove if already exists (to move to front)
        recentProjects.removeAll { $0 == url }
        
        // Add to front
        recentProjects.insert(url, at: 0)
        
        // Trim to max size
        if recentProjects.count > maxRecentProjects {
            recentProjects = Array(recentProjects.prefix(maxRecentProjects))
        }
        
        // Persist to UserDefaults
        saveRecentProjects()
    }
    
    /// Load recent projects from UserDefaults
    private func loadRecentProjects() {
        guard let data = UserDefaults.standard.data(forKey: recentProjectsKey) else {
            return
        }
        
        do {
            let bookmarks = try decoder.decode([Data].self, from: data)
            recentProjects = bookmarks.compactMap { bookmark in
                var isStale = false
                return try? URL(
                    resolvingBookmarkData: bookmark,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
            }
        } catch {
            // Failed to load recent projects; reset list
            recentProjects = []
        }
    }
    
    /// Save recent projects to UserDefaults using security-scoped bookmarks
    private func saveRecentProjects() {
        let bookmarks = recentProjects.compactMap { url in
            try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        
        guard let data = try? encoder.encode(bookmarks) else {
            return
        }
        
        UserDefaults.standard.set(data, forKey: recentProjectsKey)
    }
    
    // MARK: - Delete Operations
    
    /// Delete a project from disk and remove from recent projects
    /// - Parameter url: URL to the project bundle or sidecar file
    func deleteProject(at url: URL) async throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw ProjectStoreError.projectNotFound(url)
        }
        
        // Delete from disk
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw ProjectStoreError.fileWriteFailed(url, error)
        }
        
        // Remove from recent projects
        recentProjects.removeAll { $0 == url }
        saveRecentProjects()
    }
    
    // MARK: - Utility
    
    /// Generate default project URL for saving
    private func defaultProjectURL(for project: Project, format: ProjectFormat) -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let projectsDir = documentsURL.appendingPathComponent("Retake", isDirectory: true)
        
        // Ensure projects directory exists
        try? fileManager.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        
        let sanitizedName = sanitizeFilename(project.name)
        
        switch format {
        case .bundle:
            return projectsDir.appendingPathComponent("\(sanitizedName).retakeproject", isDirectory: true)
        case .sidecar:
            return projectsDir.appendingPathComponent("\(sanitizedName).retakeproject.json")
        }
    }
    
    /// Sanitize a filename by removing invalid characters
    private func sanitizeFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name.components(separatedBy: invalidCharacters).joined(separator: "-")
    }
}

// MARK: - Convenience Extensions

extension Project {
    static func fromRecording(videoURL: URL) -> Project {
        let filename = videoURL.deletingPathExtension().lastPathComponent
        let name = filename.hasPrefix("recording-") ? "Untitled Recording" : filename
        return Project(name: name, rawVideoURL: videoURL)
    }
}
