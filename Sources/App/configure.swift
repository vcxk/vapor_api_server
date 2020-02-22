import FluentSQLite
import Vapor

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    // Register providers first
    try services.register(FluentSQLiteProvider())

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    // middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)

//    // Configure a SQLite database
//    let sqlite = try SQLiteDatabase(storage: .memory)
//
//    // Register the configured SQLite database to the database config.
//    var databases = DatabasesConfig()
//    databases.add(database: sqlite, as: .sqlite)
//    services.register(databases)
    
    try makeDatabase(&services)

    // Configure migrations
    var migrations = MigrationConfig()
    registSqliteModels(&migrations)
    services.register(migrations)
}

private func makeDatabase(_ services: inout Services) throws {
    
    let sqlite = try SQLiteDatabase(storage: .file(path: DirectoryConfig.detect().workDir + "data.sqlite"), threadPool: nil)
    print("db path: \(sqlite.storage)")
    var database = DatabasesConfig()
    database.add(database: sqlite, as: .sqlite)
    services.register(database)
    
}

private func registSqliteModels(_ m:inout MigrationConfig) {
    
    m.add(model: Todo.self, database: .sqlite)
    m.add(model: User.self, database: .sqlite)
    m.add(model: Token.self, database: .sqlite)
    
    m.add(model: ArticleGroup.self, database: .sqlite)
    m.add(model: Article.self, database: .sqlite)
    
}

