//
//  Token.swift
//  App
//
//  Created by 陈旭珂 on 2020/1/6.
//

import Vapor
import FluentSQLite
import Random

struct Token : SQLiteModel {
    
    var id: Int?
    let token:String
    let userId:User.ID
    var createdDate:Date = Date()
    var invalidDate:Date?
    var isValid:Bool = true {
        didSet {
            if self.isValid == false {
                self.invalidDate = Date()
            }
        }
    }
    
    var user: Parent<Token,User> {
        return parent(\.userId)
    }
    
    init(_ u:User) throws {
        guard let uid = u.id else {
            throw BasicValidationError("no user id")
        }
        let tokenString = try URandom().generateData(count: 32).base64EncodedString()
        self.token = tokenString
        self.userId = uid
    }
    
}

extension Token: Migration {}

extension Token: Content {}

extension Token: Parameter {}

