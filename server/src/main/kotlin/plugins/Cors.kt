package com.cleaning.plugins

import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.plugins.cors.routing.*

fun Application.configureCors() {
    install(CORS) {
        // 開発用: localhost を許可
        anyHost() // ローカル開発時のフロントエンド（Flutter Webなど）を許可
        
        // 許可するヘッダー
        allowHeader(HttpHeaders.ContentType)
        allowHeader(HttpHeaders.Authorization)
        
        // 許可するメソッド
        allowMethod(HttpMethod.Get)
        allowMethod(HttpMethod.Post)
        allowMethod(HttpMethod.Put)
        allowMethod(HttpMethod.Delete)
        allowMethod(HttpMethod.Options)
        
        // 認証情報を含める
        allowCredentials = true
        
        // クライアントに公開するヘッダー
        exposeHeader(HttpHeaders.Authorization)
    }
}
