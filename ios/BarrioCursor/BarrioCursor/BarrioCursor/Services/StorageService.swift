import Foundation
import UIKit
import AVFoundation

actor StorageService {
    static let shared = StorageService()
    
    // Custom URLSession for direct Supabase uploads with longer timeouts
    private let uploadSession: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = false
        configuration.allowsCellularAccess = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        uploadSession = URLSession(configuration: configuration)
    }
    
    func uploadImage(_ imageData: Data, token: String) async throws -> String {
        let compressedData = compressImage(imageData)
        
        let sizeMB = Double(compressedData.count) / 1024.0 / 1024.0
        #if DEBUG
        print("📤 StorageService: Uploading \(String(format: "%.1f", sizeMB))MB image to Supabase...")
        #endif
        let uploadStart = Date()
        
        let api = APIService.shared
        do {
            let (uploadUrl, publicUrl) = try await api.getSignedUploadUrl(
                contentType: "image/jpeg",
                duration: nil,
                token: token
            )
            
            guard let uploadURL = URL(string: uploadUrl) else {
                throw StorageError.uploadFailed("Invalid upload URL: \(uploadUrl)")
            }
            
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "PUT"
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            request.httpBody = compressedData
            request.timeoutInterval = 60
            
            let (data, response) = try await uploadSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw StorageError.uploadFailed("Invalid response from Supabase")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                throw StorageError.uploadFailed("Upload failed with status: \(httpResponse.statusCode). \(errorBody)")
            }
            
            let uploadTime = Date().timeIntervalSince(uploadStart)
            #if DEBUG
            print("✅ StorageService: Image uploaded in \(String(format: "%.1f", uploadTime))s")
            #endif
            return publicUrl
        } catch let error as APIError {
            throw StorageError.uploadFailed(error.errorDescription ?? "Upload failed")
        } catch {
            throw StorageError.uploadFailed(error.localizedDescription)
        }
    }
    
    /// Uploads a video with duration validation (max 15 seconds per PRD 7.4)
    /// Uses direct upload to Supabase for better performance
    func uploadVideo(_ videoData: Data, token: String) async throws -> String {
        // Validate video duration using AVAsset
        let duration = try await getVideoDuration(videoData: videoData)
        
        // Check duration limit (15 seconds per PRD Section 7.4)
        if duration > 15.0 {
            throw StorageError.videoTooLong("Videos must be 15 seconds or less. This video is \(Int(ceil(duration))) seconds.")
        }
        
        // Determine content type from video data
        let contentType = determineVideoContentType(videoData: videoData)
        
        // Use direct upload to Supabase (much faster than going through our server)
        let api = APIService.shared
        do {
            // Get signed upload URL from our server (validates duration)
            let (uploadUrl, publicUrl) = try await api.getSignedUploadUrl(
                contentType: contentType,
                duration: duration,
                token: token
            )
            
            // Upload directly to Supabase using signed URL
            let fileSizeMB = Double(videoData.count) / 1024.0 / 1024.0
            #if DEBUG
            print("📤 StorageService: Uploading \(String(format: "%.1f", fileSizeMB))MB video directly to Supabase...")
            if uploadUrl.count > 100 {
                print("   Upload URL: \(uploadUrl.prefix(50))...\(uploadUrl.suffix(50))")
            } else {
                print("   Upload URL length: \(uploadUrl.count)")
            }
            #endif
            #if DEBUG
            print("   Content-Type: \(contentType)")
            #endif
            let uploadStart = Date()
            
            guard let uploadURL = URL(string: uploadUrl) else {
                throw StorageError.uploadFailed("Invalid upload URL: \(uploadUrl)")
            }
            
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "PUT"
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            request.httpBody = videoData
            request.timeoutInterval = 300  // 5 minutes for large videos (should be enough even for slow connections)
            
            #if DEBUG
            print("   Starting upload request...")
            #endif
            let (data, response) = try await uploadSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                #if DEBUG
                print("❌ StorageService: Invalid response type from Supabase")
                #endif
                throw StorageError.uploadFailed("Invalid response from Supabase")
            }
            
            #if DEBUG
            print("📡 StorageService: Supabase response - Status: \(httpResponse.statusCode)")
            let headerKeys = httpResponse.allHeaderFields.keys.compactMap { $0 as? String }
            if !headerKeys.isEmpty {
                var headerDict: [String: String] = [:]
                for key in headerKeys {
                    if let value = httpResponse.allHeaderFields[key] as? String {
                        headerDict[key] = value
                    }
                }
                print("   Response headers: \(headerDict)")
            }
            if let responseData = String(data: data, encoding: .utf8), !responseData.isEmpty {
                print("   Response body: \(responseData.prefix(200))")
            }
            #endif
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                #if DEBUG
                print("❌ StorageService: Upload failed with status \(httpResponse.statusCode)")
                print("   Error body: \(errorBody)")
                #endif
                throw StorageError.uploadFailed("Upload failed with status: \(httpResponse.statusCode). \(errorBody)")
            }
            
            let uploadTime = Date().timeIntervalSince(uploadStart)
            #if DEBUG
            print("✅ StorageService: Video uploaded successfully in \(String(format: "%.1f", uploadTime))s")
            print("   Public URL: \(publicUrl)")
            #endif
            
            return publicUrl
        } catch let error as APIError {
            throw StorageError.uploadFailed(error.errorDescription ?? "Upload failed")
        } catch {
            throw StorageError.uploadFailed(error.localizedDescription)
        }
    }
    
    /// Generates a thumbnail from video data using AVAssetImageGenerator
    func generateAndUploadVideoThumbnail(_ videoData: Data, token: String) async -> String? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")
        do {
            try videoData.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            
            let asset = AVURLAsset(url: tempURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 640)
            
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            
            guard let jpegData = uiImage.jpegData(compressionQuality: 0.7) else {
                #if DEBUG
                print("⚠️ StorageService: Failed to convert thumbnail to JPEG")
                #endif
                return nil
            }
            
            let thumbnailUrl = try await uploadImage(jpegData, token: token)
            #if DEBUG
            print("✅ StorageService: Video thumbnail uploaded: \(thumbnailUrl.prefix(60))...")
            #endif
            return thumbnailUrl
        } catch {
            #if DEBUG
            print("⚠️ StorageService: Failed to generate video thumbnail: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    /// Generates a thumbnail image from video data (no upload, for display only)
    func generateThumbnailImage(from videoData: Data) async -> UIImage? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")
        do {
            try videoData.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            
            let asset = AVURLAsset(url: tempURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 640)
            
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            #if DEBUG
            print("⚠️ StorageService: Failed to generate thumbnail image: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    /// Uploads multiple images and returns their public URLs
    func uploadImages(_ images: [Data], token: String) async throws -> [String] {
        var urls: [String] = []
        
        for imageData in images {
            let url = try await uploadImage(imageData, token: token)
            urls.append(url)
        }
        
        return urls
    }
    
    /// Get video duration using AVAsset
    private func getVideoDuration(videoData: Data) async throws -> Double {
        // Create temporary file with proper extension for AVAsset to recognize it
        // Try MOV first (most common from PhotosPicker), fallback to MP4
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        
        do {
            // Write video data to temporary file
            try videoData.write(to: tempURL)
            defer {
                // Clean up temporary file
                try? FileManager.default.removeItem(at: tempURL)
            }
            
            // Create AVAsset from file URL
            let asset = AVURLAsset(url: tempURL)
            
            // Load duration asynchronously
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            // Validate duration is valid
            guard durationSeconds.isFinite && durationSeconds > 0 else {
                throw StorageError.invalidVideo("Invalid video duration")
            }
            
            return durationSeconds
        } catch let error as StorageError {
            // Re-throw our custom errors
            throw error
        } catch {
            // AVAsset errors - provide more specific error message
            let errorMessage: String
            if let nsError = error as NSError? {
                if nsError.domain == NSURLErrorDomain {
                    errorMessage = "Could not open video file: Invalid file format or corrupted data"
                } else if nsError.localizedDescription.contains("cannot open") {
                    errorMessage = "Could not open video file: The video format may not be supported"
                } else {
                    errorMessage = "Could not read video duration: \(nsError.localizedDescription)"
                }
            } else {
                errorMessage = "Could not read video duration: \(error.localizedDescription)"
            }
            throw StorageError.invalidVideo(errorMessage)
        }
    }
    
    /// Determine video content type from data
    private func determineVideoContentType(videoData: Data) -> String {
        // Check for MP4 signature
        if videoData.count >= 4 {
            let signature = videoData.prefix(4)
            // MP4 files typically start with specific bytes
            if signature[0] == 0x00 && (signature[3] == 0x20 || signature[3] == 0x18 || signature[3] == 0x1C) {
                return "video/mp4"
            }
            // QuickTime/MOV files
            if signature == Data([0x00, 0x00, 0x00, 0x20]) || signature == Data([0x00, 0x00, 0x00, 0x18]) {
                return "video/quicktime"
            }
        }
        // Default to mp4
        return "video/mp4"
    }
    
    private func compressImage(_ data: Data, maxSizeKB: Int = 800) -> Data {
        guard var image = UIImage(data: data) else { return data }
        
        let maxDimension: CGFloat = 2048
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = maxDimension / max(image.size.width, image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            image = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
        
        var compression: CGFloat = 0.8
        var compressedData = image.jpegData(compressionQuality: compression) ?? data
        
        while compressedData.count > maxSizeKB * 1024 && compression > 0.3 {
            compression -= 0.1
            compressedData = image.jpegData(compressionQuality: compression) ?? compressedData
        }
        
        return compressedData
    }
}

enum StorageError: LocalizedError {
    case invalidURL
    case uploadFailed(String)
    case videoTooLong(String)
    case invalidVideo(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid storage URL"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .videoTooLong(let message):
            return message
        case .invalidVideo(let message):
            return message
        }
    }
}
