package com.cleaning

import com.cleaning.database.DatabaseFactory
import com.cleaning.plugins.configureKoin
import com.cleaning.plugins.configureRouting
import io.ktor.server.application.*
import io.ktor.server.engine.embeddedServer
import io.ktor.server.netty.Netty

fun main() {
    // データベース初期化
    DatabaseFactory.init()

    // 環境変数PORTを取得（Cloud Runでは自動設定される）
    val port = System.getenv("PORT")?.toInt() ?: 8080

    embeddedServer(Netty, port, host = "0.0.0.0", module = Application::module)
        .start(wait = true)
}

fun Application.module() {
    DatabaseFactory.init() // EngineMain から起動された場合のためにここでも呼ぶ
    configureKoin()
    configureSerialization()
    configureRouting()
}
