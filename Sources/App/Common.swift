//
//  Common.swift
//  App
//
//  Created by 陈旭珂 on 2020/1/7.
//

import Vapor
import Crypto

extension String {
    
    var md5:String {
        guard let m = try? Digest.init(algorithm: .md5).hash(self).base64EncodedString() else {
            print("md5 hash fail")
            return ""
        }
        return m
    }
    
    var bcrypt:String {
        guard let m = try? BCryptDigest().hash(self) else {
            print("bcrypt hash fail")
            return ""
        }
        return m
    }
    
}

