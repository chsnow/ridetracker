import Foundation
import Compression

/// Encoder/decoder for compact, compressed data exchange format
/// Compatible with web version at https://github.com/chsnow/tools/blob/main/disney/index.html
///
/// Format: DISNEY_H:[gzip-compressed-url-safe-base64] for history
///         DISNEY_N:[gzip-compressed-url-safe-base64] for notes
///
/// Short key format for history:
///   i = id (UUID string)
///   r = rideId
///   n = rideName
///   p = parkName
///   t = timestamp (ISO8601)
///   e = expectedWaitMinutes
///   a = actualWaitMinutes
///   q = queueType (0=standby, 1=lightningLane)

enum DataEncoder {

    // MARK: - Prefixes

    static let historyPrefix = "DISNEY_H:"
    static let notesPrefix = "DISNEY_N:"
    static let historyPrefixShort = "H:"
    static let notesPrefixShort = "N:"

    // MARK: - History Encoding

    /// Encode ride history to compact compressed format
    static func encodeHistory(_ history: [RideHistoryEntry]) -> String? {
        // Convert to compact format with short keys
        let compactData: [[String: Any]] = history.map { entry in
            var dict: [String: Any] = [
                "i": entry.id.uuidString,
                "r": entry.rideId,
                "n": entry.rideName,
                "p": entry.parkName,
                "t": ISO8601DateFormatter().string(from: entry.timestamp),
                "q": entry.queueType == .lightningLane ? 1 : 0
            ]
            if let expected = entry.expectedWaitMinutes {
                dict["e"] = expected
            }
            if let actual = entry.actualWaitMinutes {
                dict["a"] = actual
            }
            return dict
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: compactData),
              let compressed = compress(jsonData) else {
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
              let decompressed = decompress(compressed),
              let array = try? JSONSerialization.jsonObject(with: decompressed) as? [[String: Any]] else {
            return nil
        }

        // Convert from compact format
        let dateFormatter = ISO8601DateFormatter()
        return array.compactMap { dict -> RideHistoryEntry? in
            guard let idString = dict["i"] as? String,
                  let id = UUID(uuidString: idString),
                  let rideId = dict["r"] as? String,
                  let rideName = dict["n"] as? String,
                  let parkName = dict["p"] as? String,
                  let timestampString = dict["t"] as? String,
                  let timestamp = dateFormatter.date(from: timestampString) else {
                return nil
            }

            let queueType: QueueType = (dict["q"] as? Int) == 1 ? .lightningLane : .standby
            let expected = dict["e"] as? Int
            let actual = dict["a"] as? Int

            return RideHistoryEntry(
                id: id,
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

    /// Encode notes to compact compressed format
    static func encodeNotes(_ notes: [String: String]) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: notes),
              let compressed = compress(jsonData) else {
            return nil
        }

        let base64 = urlSafeBase64Encode(compressed)
        return notesPrefix + base64
    }

    /// Decode notes from compact compressed format
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
              let decompressed = decompress(compressed),
              let dict = try? JSONSerialization.jsonObject(with: decompressed) as? [String: String] else {
            return nil
        }

        return dict
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

    // MARK: - Compression Utilities

    /// Compress data using gzip
    private static func compress(_ data: Data) -> Data? {
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        defer { destinationBuffer.deallocate() }

        let compressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let sourcePtr = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return 0
            }
            return compression_encode_buffer(
                destinationBuffer,
                data.count,
                sourcePtr,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard compressedSize > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: compressedSize)
    }

    /// Decompress gzip data
    private static func decompress(_ data: Data) -> Data? {
        // Allocate buffer for decompressed data (estimate 10x expansion)
        let destinationSize = data.count * 10
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationSize)
        defer { destinationBuffer.deallocate() }

        let decompressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let sourcePtr = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return 0
            }
            return compression_decode_buffer(
                destinationBuffer,
                destinationSize,
                sourcePtr,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decompressedSize > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: decompressedSize)
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
