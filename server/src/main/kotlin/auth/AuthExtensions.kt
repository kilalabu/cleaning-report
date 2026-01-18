package com.cleaning.auth

import io.ktor.server.application.ApplicationCall
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.principal
import java.util.UUID

/**
 * 認証済みリクエストからユーザーIDを取得
 */
fun ApplicationCall.getUserId(): UUID {
    val principal = principal<JWTPrincipal>()
        ?: throw IllegalStateException("No JWT principal found")

    val userId = principal.payload.subject
        ?: throw IllegalStateException("No user ID in token")

    return UUID.fromString(userId)
}

/**
 * ユーザーロールを取得
 */
fun ApplicationCall.getUserRole(): String {
    val principal = principal<JWTPrincipal>()
        ?: throw IllegalStateException("No JWT principal found")

    // Supabase JWTのapp_metadataからロールを取得
    val appMetadata = principal.payload.getClaim("app_metadata").asMap()
    return appMetadata?.get("role")?.toString() ?: "staff"
}

/**
 * 管理者かどうかチェック
 */
fun ApplicationCall.isAdmin(): Boolean {
    return getUserRole() == "admin"
}