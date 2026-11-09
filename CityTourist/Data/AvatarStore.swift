import Foundation
import UIKit
import ImageIO
import Observation

@MainActor @Observable
final class AvatarStore {
    private(set) var image: UIImage?
    private(set) var busy = false
    var errorMessage: String?
    private var owner = "guest"
    private let directory: URL

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "Avatars", directoryHint: .isDirectory)) {
        self.directory = directory
    }
    private func file(_ owner: String) -> URL { directory.appending(path: "\(owner).jpg") }

    func load(auth: AuthenticationStore) async {
        let key = auth.session?.user.id.uuidString.lowercased() ?? "guest"
        owner = key
        image = (try? Data(contentsOf: file(key))).flatMap(UIImage.init(data:))
        guard image == nil, let config = SupabaseConfiguration.current, let user = auth.session?.user else { return }
        do {
            var request = URLRequest(url: config.url.appending(path: "storage/v1/object/authenticated/avatars/\(user.id.uuidString.lowercased())/avatar.jpg"), timeoutInterval: 20)
            request.setValue(config.publicKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(try await auth.accessToken())", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard owner == key, (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let jpeg = try await Task.detached { try Self.compressed(data) }.value
            guard owner == key else { return }
            try save(jpeg, owner: key)
            image = UIImage(data: jpeg)
        } catch { /* No remote avatar is a normal state. Keep initials. */ }
    }

    func update(_ data: Data, auth: AuthenticationStore) async {
        guard !busy else { return }
        let key = owner
        busy = true; errorMessage = nil
        defer { busy = false }
        do {
            let jpeg = try await Task.detached { try Self.compressed(data) }.value
            guard owner == key else { return }
            try save(jpeg, owner: key)
            image = UIImage(data: jpeg)
            if let config = SupabaseConfiguration.current, let user = auth.session?.user {
                var request = URLRequest(url: config.url.appending(path: "storage/v1/object/avatars/\(user.id.uuidString.lowercased())/avatar.jpg"), timeoutInterval: 30)
                request.httpMethod = "POST"
                request.setValue(config.publicKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(try await auth.accessToken())", forHTTPHeaderField: "Authorization")
                request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                request.setValue("true", forHTTPHeaderField: "x-upsert")
                request.httpBody = jpeg
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw AccountError.server }
            }
        } catch {
            errorMessage = L10n.text("The photo could not be saved everywhere. Please choose it again to retry.")
        }
    }
    private func save(_ data: Data, owner: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: file(owner), options: [.atomic, .completeFileProtectionUnlessOpen])
    }
    /// Decode a thumbnail directly: a full-resolution camera image never enters the UI cache.
    nonisolated static func compressed(_ data: Data) throws -> Data {
        guard data.count <= 30_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 512,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary),
              let jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.78), jpeg.count <= 1_000_000
        else { throw AccountError.server }
        return jpeg
    }
}
