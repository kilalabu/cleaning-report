package com.cleaning.routes

import com.cleaning.auth.isAdmin
import com.cleaning.repositories.ReportRepository
import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.authenticate
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.get
import io.ktor.server.routing.route
import org.koin.ktor.ext.inject

fun Route.adminRoutes() {
    val reportRepository by inject<ReportRepository>()

    authenticate("supabase-jwt") {
        route("/api/v1/admin") {

            // 全ユーザーのレポート取得（管理者のみ）
            get("/reports") {
                if (!call.isAdmin()) {
                    call.respond(HttpStatusCode.Forbidden, mapOf("error" to "Admin only"))
                    return@get
                }

                val month = call.parameters["month"]
                if (month == null) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "month is required"))
                    return@get
                }

                // TODO: 全ユーザーのレポート取得メソッドをリポジトリに追加
                call.respond(mapOf("message" to "Not implemented yet"))
            }
        }
    }
}