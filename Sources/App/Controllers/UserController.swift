//
//  UserController.swift
//  App
//
//  Created by 陈旭珂 on 2020/1/7.
//

import Vapor

fileprivate struct RegistPara:Content {
    
    let username:String
    let password:String
    let phone:String?
    let email:String?
    
}

fileprivate struct LoginPara: Content {
    let username:String
    let password:String
}

fileprivate struct ModifyPara:Content {
    let id: User.ID
    let phone: String?
    let email: String?
}

fileprivate struct UserInfo:Content {
    let id:User.ID?
    let username:String
    let phone:String?
    let email:String?
    
    init(_ u:User) {
        self.id = u.id
        self.username = u.username
        self.phone = u.phone
        self.email = u.email
    }
}

fileprivate struct PasswdPara:Content {
    let username:String
    let old:String
    let new:String
}

extension Request {
    
    typealias UserAndToken = (user:User,token:Token)
    
    func assertUser() throws -> Future<UserAndToken> {
        if let cookie = self.http.cookies.all["auth"] {
            
            return Token.query(on: self).filter(\.isValid, .equal, true).filter(\.token, .equal, cookie.string).first().flatMap({ (t)  in
                guard let token = t else {
                    throw BasicValidationError("需要登录")
                }
                
                return token.user.query(on: self).first().flatMap { (u) in
                    guard let user = u else {
                        throw BasicValidationError("需要登录")
                    }
                    return self.future((user,token))
                }
            })
        }
        
        throw BasicValidationError("无 cookie")
    }
}


final class UserController {
    
    fileprivate func isExist(_ req:Request) throws -> Future<ResponseResult<Int>> {
        return User.query(on: req).filter(\.username, .equal, "cxk").count().flatMap { (count) -> EventLoopFuture<ResponseResult<Int>> in
            let msg = count > 0 ? "用户已存在" : "用户不存在"
            let r = ResponseResult<Int>.init(isSuccess: true, msg: msg, content: count)
            return req.future(r)
        }
    }
    
    fileprivate func regist(_ req:Request) throws -> Future<ResponseResult<UserInfo>> {
        
        
        return try req.content.decode(RegistPara.self).flatMap({ (para) -> Future<ResponseResult<UserInfo>> in
            
            return User.query(on: req).filter(\.username ,.equal,para.username).count().flatMap { (count) -> Future<ResponseResult<UserInfo>> in
                if count > 0 {
                    let r = ResponseResult<UserInfo>.init(isSuccess: false, msg: "用户已存在", content: nil)
                    return req.future(r)
                } else {
                    var u = User.init(para.username, password: para.password)
                    u.phone = para.phone
                    u.email = para.email
                    return u.save(on: req).flatMap { (savedUser) -> EventLoopFuture<ResponseResult<UserInfo>> in
                        let info = UserInfo.init(savedUser)
                        let r = ResponseResult<UserInfo>.init(isSuccess: true, msg: "注册成功", content: info)
                        return req.future(r)
                    }
                }
            }
        })
    }
    
    fileprivate func login(_ req:Request) throws -> Future<Response> {
        return try req.content.decode(LoginPara.self).flatMap { (para) -> EventLoopFuture<Response> in
            User.query(on: req).filter(\.username, .equal, para.username).first().flatMap { (queryUser) -> EventLoopFuture<Response> in
                guard let user = queryUser else {
                    let r = ResponseResult<UserInfo>.init(isSuccess: false, msg: "用户不存在", content: nil)
                    return try r.encode(for: req)
                }
                guard user.passwordHash == para.password.md5 else {
                    let r = ResponseResult<UserInfo>.init(isSuccess: false, msg: "密码不正确", content: nil)
                    return try r.encode(for: req)
                }
                
                let r = ResponseResult<UserInfo>.init(isSuccess: true, msg: "登录成功", content: UserInfo.init(user))
                
                _ = try user.tokens.query(on: req).filter(\.isValid, .equal, true).all().flatMap { (tks) -> EventLoopFuture<Void> in
                    tks.forEach { (t) in
                        var mt = t
                        mt.isValid = false
                        _ = mt.save(on: req)
                    }
                    return req.future()
                }
                
                let token = try Token(user)
                
                return token.save(on: req).flatMap { (t) -> EventLoopFuture<Response> in
                    let response = try r.encode(for: req)
                    return response.flatMap { (res) -> EventLoopFuture<Response> in
                        res.http.cookies.all["auth"] = HTTPCookieValue(string: t.token, expires: nil, maxAge: nil, domain: nil, path: "/", isSecure: false, isHTTPOnly: false, sameSite: nil)
                        return req.future(res)
                    }
                }
            }
        }
    }
    
    fileprivate func info(_ req:Request) throws -> Future<ResponseResult<UserInfo>> {
        return try req.assertUser().flatMap { (ut) -> EventLoopFuture<ResponseResult<UserInfo>> in
            let info = UserInfo.init(ut.user)
            let r = ResponseResult<UserInfo>.init(isSuccess: true, msg: "", content: info)
            return req.future(r)
        }
    }
    
    func logout(_ req:Request) throws -> Future<ResponseResult<Int>> {
        let fut = try req.assertUser()
        return fut.flatMap { (ut)  in
            var token = ut.token
            token.isValid = false
            _ = token.save(on: req)
            let r = ResponseResult<Int>.init(isSuccess: true, msg: "退出成功", content: nil)
            return req.future(r)
        }
    }
    
    func modify(_ req:Request) throws -> Future<ResponseResult<Int>>{
        let fut = try req.assertUser()
        return fut.flatMap { (ut) in
            return try req.content.decode(ModifyPara.self).flatMap({ (para) in
                var user = ut.user
                let msg:String = ""
                if let phone = para.phone {
                    user.phone = phone
                }
                if let email = para.email {
                    user.email = email
                }
//                var isFail = false
                return user.save(on: req).flatMap{ l in
                    let r = ResponseResult<Int>.init(isSuccess: true, msg: msg, content: nil)
                    return req.future(r)
                }
            })
        }
    }
    
    fileprivate func passwd(_ req:Request) throws -> Future<ResponseResult<Int>>{
        return try req.assertUser().flatMap { ut in
            return try req.content.decode(PasswdPara.self).flatMap { para in
                var user = ut.user
                guard user.username == para.username else {
                    let r = ResponseResult<Int>.init(isSuccess: false, msg: "账户名不正确", content: nil)
                    return req.future(r)
                }
                guard para.new != para.old else {
                    let r = ResponseResult<Int>.init(isSuccess: false, msg: "新旧密码不能相同", content: nil)
                    return req.future(r)
                }
                guard user.passwordHash == para.old.md5 else {
                    let r = ResponseResult<Int>.init(isSuccess: false, msg: "密码不正确", content: nil)
                    return req.future(r)
                }
                
                guard para.new.count >= 6 else {
                    let r = ResponseResult<Int>.init(isSuccess: false, msg: "新密码过短", content: nil)
                    return req.future(r)
                }
                
                user.passwordHash = para.new.md5
                return user.save(on: req).flatMap { su in
                    return try su.tokens.query(on: req).filter(\.isValid, .equal, true).all().flatMap { ts in
                        ts.forEach { (t) in
                            var mt = t
                            mt.isValid = false
                            _ = mt.save(on: req)
                        }
                        let r = ResponseResult<Int>.init(isSuccess: true, msg: "", content: nil)
                        return req.future(r)
                    }
                }
            }
        }
    }
    
}

extension UserController {
    static func makeRoute(router:Router) {
        let userGroup = router.grouped("user")
        let controller = UserController()
        userGroup.post("regist", use: controller.regist)
        userGroup.post("login", use: controller.login)
        userGroup.get("info", use: controller.info)
        userGroup.get("logout", use: controller.logout)
        userGroup.post("modify", use: controller.modify)
        userGroup.post("passwd", use: controller.passwd)
    }
}
