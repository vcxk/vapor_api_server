//
//  ArticleController.swift
//  App
//
//  Created by 陈旭珂 on 2020/2/20.
//

import Vapor
import FluentSQLite

fileprivate struct ArticleCreate: Content {
    var groupId:ArticleGroup.ID
    var title:String
    var tags:[String]?
    var content:String
}

fileprivate struct ArticleCreateResult:Content {
    var isSuccess:Bool
    var title:String
    var tags:String
    var id:Article.ID
}

fileprivate struct GroupCreate: Content {
    var name:String
}

fileprivate struct GroupDelete: Content {
    var id:ArticleGroup.ID
}


final class ArticleController {
    
}

fileprivate extension ArticleController {
    
    func groupCreate(_ req:Request) throws -> Future <ArticleGroup> {
         return try req.assertUser().flatMap { ut in
            let uid = ut.user.id!
            return try req.content.decode(GroupCreate.self).flatMap { g in
                let group = ArticleGroup(name: g.name, userId: uid, createAt: Date())
                return group.save(on: req).flatMap { sg in
                    return req.future(sg)
                }
            }
        }
    }
    
    func groupList(_ req:Request) throws -> Future<[ArticleGroup]> {
        return try req.assertUser().flatMap { ut in
            let uid = ut.user.id!
            return ArticleGroup.query(on: req).filter(\.userId, .equal, uid).all().flatMap {
                return req.future($0)
            }
        }
    }
    
    func groupDelete(_ req:Request) throws -> Future<ResponseResult<Int>>{
        return try req.assertUser().flatMap { ut in
            let uid = ut.user.id!
            return try req.content.decode(GroupDelete.self).flatMap { d in
                return ArticleGroup.query(on: req).filter(\.id, .equal, d.id).first().flatMap {
                    g in
                    guard let sg = g, sg.userId == uid else {
                        return req.future(ResponseResult(isSuccess: false, msg: "", content: nil))
                    }
                    return Article.query(on: req).filter(\.groupId, .equal, sg.id!).count().flatMap { count in
                        guard count == 0 else {
                            return req.future(ResponseResult(isSuccess: false, msg: "组下有文章", content: nil))
                        }
                        return sg.delete(on: req).flatMap {
                            return req.future(ResponseResult(isSuccess: true, msg: "", content: nil))
                        }
                    }
                    
                }
            }
        }
    }
    
    func create(_ req:Request) throws -> Future<ArticleCreateResult> {
        return try req.assertUser().flatMap({ ut  in
            
            let uid = ut.user.id!
            
            return try req.content.decode(ArticleCreate.self).flatMap { (c)  in
                
                return ArticleGroup.find(c.groupId, on: req).flatMap { g  in
                    if let group = g, group.userId == uid {
                        let article = Article(userId: ut.user.id!, groupId: c.groupId, title: c.title, tags: c.tags?.joined(separator: ",") ?? "", content: c.content, createAt: Date(), modifyDate: Date())
                        return article.save(on: req).flatMap { (a)  in
                            let result = ArticleCreateResult(isSuccess: true, title: a.title, tags: a.tags, id: a.id!)
                            return req.future(result)
                        }
                    } else {
                        let result = ArticleCreateResult(isSuccess: false, title: c.title, tags: c.tags?.joined(separator: ",") ?? "", id: 0)
                        return req.future(result)
                    }
                }
            }
        })
    }
    
    struct Modify: Content {
        var id:Article.ID
        var title:String
        var tags:String
        var content:String
    }
    
    func modify(_ req:Request) throws -> Future<ResponseResult<Int>> {
        let p = req.eventLoop.newPromise(ResponseResult<Int>.self)
        DispatchQueue.global().async {
            do {
                
                let ut = try req.assertUser().wait()
                let uid = ut.user.id!
                let m = try req.content.decode(Modify.self).wait()
                
                guard var a = try Article.query(on: req).filter(\.id, .equal, m.id).first().wait() else {
                    let result = ResponseResult<Int>.init(isSuccess: false, msg: "未找到文章", content: nil)
                    p.succeed(result: result)
                    return
                }
                guard a.userId == uid else {
                    let result = ResponseResult<Int>.init(isSuccess: false, msg: "非法修改", content: nil)
                    p.succeed(result: result)
                    return
                }
                
                a.title = m.title
                a.content = m.content
                a.tags = m.tags
                
                _ = try a.save(on: req).wait()
                
                let result = ResponseResult<Int>.init(isSuccess: true, msg: "", content: nil)
                p.succeed(result: result)
                
            } catch let err {
                p.fail(error: err)
            }
        }
        return p.futureResult
    }
    
    struct Delete: Content {
        var id:Article.ID
    }
    
    func delete(_ req:Request) throws -> Future<ResponseResult<Int>>{
        
        return try req.assertUser().flatMap { ut in
            let uid = ut.user.id!
            return try req.content.decode(Delete.self).flatMap { d in
                return Article.query(on: req).filter(\.id, .equal, d.id).first().flatMap { a in
                    guard let article = a else {
                        let result = ResponseResult<Int>.init(isSuccess: false, msg: "不存在该文章", content: nil)
                        return req.future(result)
                    }
                    guard article.userId == uid else {
                        let result = ResponseResult<Int>.init(isSuccess: false, msg: "非法操作", content: nil)
                        return req.future(result)
                    }
                    
                    return article.delete(on: req).flatMap {
                        let result = ResponseResult<Int>.init(isSuccess: true, msg: "", content: nil)
                        return req.future(result)
                    }
                }
            }
        }
        
        
    }
    
    struct ListPara: Content {
        var groupId:ArticleGroup.ID?
        
    }
    
    struct List:Content {
        struct GroupList:Content {
            var list:[ListArtile]
            var group:ArticleGroup
        }
        var list:[GroupList]
    }
    
    struct ListArtile : SQLiteModel,Migration,Content,Parameter {
        
        var id: Article.ID?
        static var entity: String { return Article.entity }
        
        var userId:User.ID
        var groupId:ArticleGroup.ID
        
        var title:String
        var tags:String
        
        var createAt:Date
        var modifyDate:Date
        var modifyCount:Int = 0
        
    }
    
    
    func list(_ req:Request) throws -> Future<ResponseResult<List>> {
        return try req.assertUser().flatMap { ut in
            let uid = ut.user.id!
            return try req.content.decode(ListPara.self).flatMap { lp in
                if let groupId = lp.groupId {
                    return ArticleGroup.query(on: req).filter(\.id, .equal, groupId).first().flatMap {
                        g in
                        guard let sg = g ,sg.userId == uid else {
                            let result = ResponseResult<List>.init(isSuccess: false, msg: "无该文章组", content: nil)
                            return req.future(result)
                        }
                        guard sg.userId == uid else {
                            let result = ResponseResult<List>.init(isSuccess: false, msg: "非法操作", content: nil)
                            return req.future(result)
                        }
                        
                        return ListArtile.query(on: req).filter(\.groupId, .equal, groupId).all().flatMap { articles in
                            let list = List.GroupList.init(list: articles, group: sg)
                            let result = ResponseResult<List>.init(isSuccess: true, msg: "", content: List(list: [list]))
                            return req.future(result)
                        }
                    }
                } else {
                    return ArticleGroup.query(on: req).filter(\.userId, .equal, uid).all().flatMap {
                        groups in
                        let p = req.eventLoop.newPromise(ResponseResult<List>.self)
                        
                        DispatchQueue.global().async {
                            do {
                                var list = List(list: [])
                                for g in groups {
                                    let articles = try ListArtile.query(on: req).all().wait()
                                    let gl = List.GroupList.init(list: articles, group: g)
                                    list.list.append(gl)
                                }
                                
                                p.succeed(result: ResponseResult<List>.init(isSuccess: true, msg: "", content: list))
                            } catch let err {
                                p.fail(error: err)
                            }
                        }
                        
                        return p.futureResult
                    }
                }
            }
        }
    }
    
    struct ContentPara:Content {
        var articleId:Article.ID
    }
    
    func content(_ req:Request) throws -> Future<ResponseResult<Article>> {
        return try req.assertUser().flatMap { ut in
            let uid = ut.user.id!
            
            return try req.content.decode(ContentPara.self).flatMap { cp in
                return Article.query(on: req).filter(\.id, .equal, cp.articleId).first().flatMap {
                    a in
                    guard let article = a else {
                        let result = ResponseResult<Article>.init(isSuccess: false, msg: "不存在该文章", content: nil)
                        return req.future(result)
                    }
                    guard article.userId == uid else {
                        let result = ResponseResult<Article>.init(isSuccess: false, msg: "非法操作", content: nil)
                        return req.future(result)
                    }
                    let result = ResponseResult<Article>.init(isSuccess: true, msg: "", content: article)
                    return req.future(result)
                }
            }
        }
    }
    
}

extension ArticleController {
    class func makeRoute(_ router:Router) {
        let controller = ArticleController()
        let g = router.grouped("article")
        g.post("group","create", use: controller.groupCreate)
        g.post("group","list",use: controller.groupList)
        g.post("group","delete", use: controller.groupDelete)
        
        ListArtile.defaultDatabase = .sqlite
        
        g.post("create", use: controller.create)
        g.post("modify", use: controller.modify)
        g.post("list", use: controller.list)
        g.post("delete", use: controller.delete)
        g.post("content", use: controller.content)
    }
}
