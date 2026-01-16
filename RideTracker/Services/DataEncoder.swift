import Foundation
import Compression
import zlib

/// Encoder/decoder for compact, compressed data exchange format
/// Compatible with web version at https://github.com/chsnow/tools/blob/main/disney/index.html
///
/// Format: DISNEY_H:[gzip-compressed-url-safe-base64] for history
///         DISNEY_N:[gzip-compressed-url-safe-base64] for notes
///
/// Web version short key format for history:
///   i = id (string, used as rideId on iOS)
///   n = name (rideName)
///   p = parkName
///   t = timestamp (ISO8601)
///   e = expectedWaitMins
///   w = actualWaitMins
///   q = queueType
///
/// Web version notes format: [{i: id, t: text}, ...]

enum DataEncoder {

    // MARK: - Prefixes

    static let historyPrefix = "DISNEY_H:"
    static let notesPrefix = "DISNEY_N:"
    static let historyPrefixShort = "H:"
    static let notesPrefixShort = "N:"

    // MARK: - History Encoding

    /// Encode ride history to compact compressed format (web-compatible)
    static func encodeHistory(_ history: [RideHistoryEntry]) -> String? {
        // Convert to web-compatible format with short keys
        let compactData: [[String: Any]] = history.map { entry in
            var dict: [String: Any] = [
                "i": entry.rideId,  // Web uses 'i' for the ride ID
                "n": entry.rideName,
                "p": entry.parkName,
                "t": ISO8601DateFormatter().string(from: entry.timestamp)
            ]
            if let expected = entry.expectedWaitMinutes {
                dict["e"] = expected
            }
            if let actual = entry.actualWaitMinutes {
                dict["w"] = actual  // Web uses 'w' for actual wait
            }
            if entry.queueType == .lightningLane {
                dict["q"] = "lightning"
            }
            return dict
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: compactData),
              let compressed = gzipCompress(jsonData) else {
            return nil
        }

        let base64 = urlSafeBase64Encode(compressed)
        return historyPrefix + base64
    }

    /// Decode history from compact compressed format
    static func decodeHistory(_ encoded: String) -> [RideHistoryEntry]? {
        // Strip prefix
        let data: String
        if encoded.hasPrefix(historyPrefix) {
            data = String(encoded.dropFirst(historyPrefix.count))
        } else if encoded.hasPrefix(historyPrefixShort) {
            data = String(encoded.dropFirst(historyPrefixShort.count))
        } else {
            return nil
        }

        // Decode and decompress
        guard let compressed = urlSafeBase64Decode(data),
              let decompressed = gzipDecompress(compressed),
              let array = try? JSONSerialization.jsonObject(with: decompressed) as? [[String: Any]] else {
            return nil
        }

        // Convert from web format
        let dateFormatter = ISO8601DateFormatter()
        return array.compactMap { dict -> RideHistoryEntry? in
            // Web format uses 'i' for ID and 'n' for name
            guard let rideId = dict["i"] as? String,
                  let rideName = dict["n"] as? String,
                  let timestampString = dict["t"] as? String,
                  let timestamp = dateFormatter.date(from: timestampString) else {
                return nil
            }

            let parkName = dict["p"] as? String ?? "Unknown Park"
            let queueType: QueueType = (dict["q"] as? String) == "lightning" ? .lightningLane : .standby
            let expected = dict["e"] as? Int
            let actual = dict["w"] as? Int  // Web uses 'w' for actual wait

            return RideHistoryEntry(
                rideId: rideId,
                rideName: rideName,
                parkName: parkName,
                timestamp: timestamp,
                expectedWaitMinutes: expected,
                actualWaitMinutes: actual,
                queueType: queueType
            )
        }
    }

    // MARK: - Notes Encoding

    /// Encode notes to compact compressed format (web-compatible)
    /// Web format: [{i: id, t: text}, ...]
    static func encodeNotes(_ notes: [String: String]) -> String? {
        // Convert to web-compatible array format
        let notesArray: [[String: String]] = notes.map { key, value in
            ["i": key, "t": value]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: notesArray),
              let compressed = gzipCompress(jsonData) else {
            return nil
        }

        let base64 = urlSafeBase64Encode(compressed)
        return notesPrefix + base64
    }

    /// Decode notes from compact compressed format
    /// Web format: [{i: id, t: text}, ...]
    static func decodeNotes(_ encoded: String) -> [String: String]? {
        // Strip prefix
        let data: String
        if encoded.hasPrefix(notesPrefix) {
            data = String(encoded.dropFirst(notesPrefix.count))
        } else if encoded.hasPrefix(notesPrefixShort) {
            data = String(encoded.dropFirst(notesPrefixShort.count))
        } else {
            return nil
        }

        // Decode and decompress
        guard let compressed = urlSafeBase64Decode(data),
              let decompressed = gzipDecompress(compressed) else {
            return nil
        }

        // Try to parse as array format (web format)
        if let array = try? JSONSerialization.jsonObject(with: decompressed) as? [[String: String]] {
            var notes: [String: String] = [:]
            for item in array {
                if let id = item["i"], let text = item["t"] {
                    notes[id] = text
                }
            }
            return notes
        }

        // Fallback: try dictionary format (iOS legacy)
        if let dict = try? JSONSerialization.jsonObject(with: decompressed) as? [String: String] {
            return dict
        }

        return nil
    }

    // MARK: - Format Detection

    enum DataType {
        case compressedHistory
        case compressedNotes
        case jsonHistory
        case jsonNotes
        case unknown
    }

    /// Detect the type of encoded data
    static func detectDataType(_ data: String) -> DataType {
        let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for compressed format prefixes
        if trimmed.hasPrefix(historyPrefix) || trimmed.hasPrefix(historyPrefixShort) {
            return .compressedHistory
        }
        if trimmed.hasPrefix(notesPrefix) || trimmed.hasPrefix(notesPrefixShort) {
            return .compressedNotes
        }

        // Try to detect JSON format
        guard let jsonData = trimmed.data(using: .utf8) else {
            return .unknown
        }

        // Try parsing as JSON array (history)
        if let array = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
            // Check if it looks like history (has rideId or rideName)
            if let first = array.first,
               first["rideId"] != nil || first["rideName"] != nil {
                return .jsonHistory
            }
        }

        // Try parsing as JSON object (notes)
        if (try? JSONSerialization.jsonObject(with: jsonData) as? [String: String]) != nil {
            return .jsonNotes
        }

        return .unknown
    }

    // MARK: - Gzip Compression (Web-compatible)

    /// Compress data using gzip format (compatible with web CompressionStream)
    private static func gzipCompress(_ data: Data) -> Data? {
        var stream = z_stream()

        // Initialize for gzip format (windowBits = 15 + 16 for gzip)
        guard deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { deflateEnd(&stream) }

        let outputCapacity = data.count + 128
        let outputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: outputCapacity)
        defer { outputBuffer.deallocate() }

        let result = data.withUnsafeBytes { sourcePtr -> Int32 in
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: sourcePtr.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(data.count)
            stream.next_out = outputBuffer
            stream.avail_out = uInt(outputCapacity)

            return deflate(&stream, Z_FINISH)
        }

        guard result == Z_STREAM_END else { return nil }
        return Data(bytes: outputBuffer, count: Int(stream.total_out))
    }

    /// Decompress gzip data (compatible with web DecompressionStream)
    private static func gzipDecompress(_ data: Data) -> Data? {
        var stream = z_stream()

        // Initialize for gzip format (windowBits = 15 + 16 for gzip)
        guard inflateInit2_(&stream, 15 + 16, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { inflateEnd(&stream) }

        // Allocate output buffer (estimate 10x expansion)
        let outputCapacity = data.count * 10
        let outputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: outputCapacity)
        defer { outputBuffer.deallocate() }

        let result = data.withUnsafeBytes { sourcePtr -> Int32 in
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: sourcePtr.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(data.count)
            stream.next_out = outputBuffer
            stream.avail_out = uInt(outputCapacity)

            return inflate(&stream, Z_FINISH)
        }

        guard result == Z_STREAM_END else { return nil }
        return Data(bytes: outputBuffer, count: Int(stream.total_out))
    }

    // MARK: - Base64 Utilities

    /// Encode to URL-safe base64 (replace +/- and strip padding)
    private static func urlSafeBase64Encode(_ data: Data) -> String {
        var base64 = data.base64EncodedString()
        base64 = base64.replacingOccurrences(of: "+", with: "-")
        base64 = base64.replacingOccurrences(of: "/", with: "_")
        base64 = base64.replacingOccurrences(of: "=", with: "")
        return base64
    }

    /// Decode from URL-safe base64
    private static func urlSafeBase64Decode(_ string: String) -> Data? {
        var base64 = string
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)

        return Data(base64Encoded: base64)
    }
}
