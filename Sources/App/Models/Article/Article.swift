//
//  Article.swift
//  App
//
//  Created by 陈旭珂 on 2020/2/20.
//

import Vapor
import FluentSQLite



struct ArticleGroup :SQLiteModel {
    var id:Int?
    var name:String
    var userId:User.ID
    var createAt:Date 
}

struct Article: SQLiteModel {
    var id:Int?
    
    var userId:User.ID
    var groupId:ArticleGroup.ID
    
    var title:String
    var tags:String
    var content:String
    var createAt:Date
    var modifyDate:Date
    var modifyCount:Int = 0
}

extension Article : Content {}
extension Article : Migration {}
extension Article : Parameter {}

extension ArticleGroup : Content {}
extension ArticleGroup : Migration {}
extension ArticleGroup : Parameter {}
