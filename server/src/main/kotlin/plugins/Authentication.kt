package com.cleaning.plugins

import com.auth0.jwk.JwkProviderBuilder
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.auth.Authentication
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.jwt.jwt
import io.ktor.server.response.respond
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * JWT認証設定 (ES256/ECC P-256 対応)
 *
 * JWKsエンドポイントから公開鍵を取得してJWTを検証する
 */
fun Application.configureAuthentication() {
    val supabaseUrl = System.getenv("SUPABASE_URL")
        ?: throw IllegalStateException("SUPABASE_URL is not set")

    //  JWKsエンドポイントから公開鍵を取得し、キャッシュする仕組み
    //  毎回ネットワークアクセスするのは遅いので、キャッシュが重要
    val jwkProvider = JwkProviderBuilder(
        URL("$supabaseUrl/auth/v1/.well-known/jwks.json")
    )
        // キャッシュ設定: 最大10件、5分間保持
        // Supabaseはエッジで10分間キャッシュするため、5分は安全なマージン
        .cached(10, 5, TimeUnit.MINUTES)
        // レート制限: 1分間に最大10リクエスト（JWKsエンドポイントへの過剰アクセス防止）
        .rateLimited(10, 1, TimeUnit.MINUTES)
        .build()

    install(Authentication) {
        jwt("supabase-jwt") {
            realm = "cleaning-report-api"

            // JWT検証器の設定（JwkProviderを使用）
            verifier(jwkProvider, "$supabaseUrl/auth/v1") {
                // ES256アルゴリズムを受け入れる
                acceptLeeway(3)  // 時刻のずれを3秒まで許容
            }

            // JWTの内容を検証
            validate { credential ->
                // 有効期限チェック
                val expiresAt = credential.payload.expiresAt
                if (expiresAt != null && expiresAt.time < System.currentTimeMillis()) {
                    null  // 期限切れ → 認証失敗
                } else {
                    // subクレームからuser_idを取得
                    val userId = credential.payload.subject
                    if (userId != null) {
                        JWTPrincipal(credential.payload)
                    } else {
                        null  // user_idがない → 認証失敗
                    }
                }
            }

            // 認証失敗時のレスポンス
            challenge { _, _ ->
                call.respond(
                    HttpStatusCode.Unauthorized,
                    mapOf("error" to "Token is invalid or expired")
                )
            }
        }
    }
}
