//
//  User.swift
//  App
//
//  Created by 陈旭珂 on 2020/1/6.
//

import Vapor
import FluentSQLite

struct User: SQLiteModel {
    
    var id: Int?
    
    var username: String
    var passwordHash: String
    var email: String?
    var phone: String?
    
    var registDate:Date
    
    init(_ userName:String,password:String) {
        
        self.username = userName
        self.passwordHash = password.md5
        self.registDate = Date()
        
    }
    
    var tokens: Children<User,Token> {
        return children(\.userId)
    }
    
//    static func queryLogin(_ username:String,on:DatabaseConnectable ,password:String) -> Future<User?> {
//        return User.query(on: on).filter(\.username, .equal, username).filter(\.passwordHash, .equal, password.md5).first()
//    }
    
    static func passwdHash(_ passwd:String,isSuper:Bool = false) -> String {
        if isSuper {
            return passwd.bcrypt
        } else {
            return passwd.md5
        }
    }
}

extension User: Migration {}

extension User: Content {}

extension User: Parameter {}

