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
