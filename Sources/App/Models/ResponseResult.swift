//
//  ResponseResult.swift
//  App
//
//  Created by 陈旭珂 on 2020/1/7.
//

import Foundation
import FluentSQLite
import Vapor

struct ResponseResult<T:Content>:Content {
    var isSuccess:Bool
    var msg:String
    var content:T?
}



