//
//  Digest.swift
//  
//
//  Created by Rocky Wei on 2023-03-23.
//

public enum DigestAlgorithm: String {
    case SHA256 = "SHA256"
    case SHA512 = "SHA512"
}

public typealias Digest = DigestAlgorithm

public extension DigestAlgorithm {
    static func hash(streamReaderFileNumber: Int32, algorithm: Self) -> [UInt8] {
        switch algorithm {
        case .SHA256:
            let sha = DigestAlgorithmSHA256(streamReaderFileNumber: streamReaderFileNumber)
            return sha.hash
        case .SHA512:
            let sha = DigestAlgorithmSHA512(streamReaderFileNumber: streamReaderFileNumber)
            return sha.hash
        }
    }
    static let all: [Self] = [.SHA256, .SHA512]
    static func getBlockSize(algorithm: DigestAlgorithm) -> Int {
        switch algorithm {
        case .SHA256:
            return SHA256Round.chunkSize
        case .SHA512:
            return SHA512Round.chunkSize
        }
    }
}
