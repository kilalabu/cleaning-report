package com.cleaning

import io.ktor.server.application.*
import io.ktor.server.engine.embeddedServer
import io.ktor.server.netty.Netty

fun main() {
    // 環境変数PORTを取得（Cloud Runでは自動設定される）
    val port = System.getenv("PORT")?.toInt() ?: 8080

    embeddedServer(Netty, port, host = "0.0.0.0", module = Application::module)
        .start(wait = true)
}

fun Application.module() {
    configureSerialization()
    configureRouting()
}
