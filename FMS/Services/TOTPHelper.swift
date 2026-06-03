import Foundation
import CryptoKit

struct TOTPHelper {
    /// Verify if a 6-digit OTP code is valid for a given Base32 secret key.
    /// Supports a time window drift of ±30 seconds.
    static func verify(code: String, secret: String) -> Bool {
        let cleanSecret = secret.replacingOccurrences(of: " ", with: "").uppercased()
        guard let keyData = base32Decode(cleanSecret) else { return false }
        
        let currentTimeStep = Int64(Date().timeIntervalSince1970) / 30
        
        // Check current, previous, and next time step to handle slight time drift
        for offset in -1...1 {
            let targetCode = generateTOTP(timeStep: currentTimeStep + Int64(offset), keyData: keyData)
            if targetCode == code {
                return true
            }
        }
        return false
    }
    
    private static func generateTOTP(timeStep: Int64, keyData: Data) -> String {
        var counter = timeStep.bigEndian
        let counterData = Data(bytes: &counter, count: MemoryLayout.size(ofValue: counter))
        
        // HMAC-SHA1 is the standard hashing algorithm for TOTP
        let symmetricKey = SymmetricKey(data: keyData)
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: symmetricKey)
        let macData = Data(mac)
        
        // Dynamic Truncation
        let offset = Int(macData.last! & 0x0f)
        let binary = macData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> UInt32 in
            let byte0 = UInt32(ptr[offset])
            let byte1 = UInt32(ptr[offset + 1])
            let byte2 = UInt32(ptr[offset + 2])
            let byte3 = UInt32(ptr[offset + 3])
            return (byte0 << 24) | (byte1 << 16) | (byte2 << 8) | byte3
        }
        
        let otp = (binary & 0x7fffffff) % 1_000_000
        return String(format: "%06d", otp)
    }
    
    private static func base32Decode(_ string: String) -> Data? {
        let characterMap = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var data = Data()
        var buffer: UInt32 = 0
        var count = 0
        
        for char in string {
            if char == "=" { break }
            guard let index = characterMap.firstIndex(of: char) else { continue }
            let value = characterMap.distance(from: characterMap.startIndex, to: index)
            
            buffer = (buffer << 5) | UInt32(value)
            count += 5
            
            if count >= 8 {
                count -= 8
                let byte = UInt8((buffer >> count) & 0xFF)
                data.append(byte)
            }
        }
        return data.isEmpty ? nil : data
    }
}
