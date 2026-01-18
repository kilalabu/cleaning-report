package com.cleaning.routes

import com.cleaning.auth.getUserId
import com.cleaning.auth.isAdmin
import com.cleaning.models.*
import com.cleaning.repositories.ReportRepository
import io.ktor.http.*
import io.ktor.server.auth.authenticate
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import org.koin.ktor.ext.inject
import java.time.LocalDate
import java.util.UUID

fun Route.reportRoutes() {
    val reportRepository: ReportRepository by inject()

    authenticate("supabase-jwt") {
        route("/api/v1/reports") {
            // GET /api/v1/reports?month=2026-01
            get {
                val month = call.parameters["month"]
                if (month == null) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "month is required"))
                    return@get
                }

                // JWTからユーザーIDを取得
                val userId = call.getUserId()
                val reports = reportRepository.findByMonth(month, userId)
                call.respond(reports.map { it.toDto() })
            }

            // POST /api/v1/reports
            post {
                val request = call.receive<CreateReportRequest>()

                val userId = call.getUserId()

                val date = LocalDate.parse(request.date)
                val month = "${date.year}-${date.monthValue.toString().padStart(2, '0')}"

                val report = Report(
                    id = UUID.randomUUID(),
                    userId = userId,
                    date = date,
                    type = ReportType.valueOf(request.type),
                    item = request.item,
                    unitPrice = request.unitPrice,
                    duration = request.duration,
                    amount = request.amount,
                    note = request.note,
                    month = month,
                    createdAt = java.time.LocalDateTime.now(),
                    updatedAt = null
                )

                val created = reportRepository.create(report)
                call.respond(HttpStatusCode.Created, created.toDto())
            }

            // PUT /api/v1/reports/{id}
            put("/{id}") {
                val id = call.parameters["id"]?.let { UUID.fromString(it) }
                if (id == null) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Invalid ID"))
                    return@put
                }

                // 存在チェック
                val existing = reportRepository.findById(id)
                if (existing == null) {
                    call.respond(HttpStatusCode.NotFound, mapOf("error" to "Report not found"))
                    return@put
                }

                // 権限チェック: 自分のレポートまたは管理者のみ編集可能
                val userId = call.getUserId()
                if (existing.userId != userId && !call.isAdmin()) {
                    call.respond(HttpStatusCode.Forbidden, mapOf("error" to "Not authorized"))
                    return@put
                }

                val request = call.receive<CreateReportRequest>()
                val date = LocalDate.parse(request.date)
                val month = "${date.year}-${date.monthValue.toString().padStart(2, '0')}"

                // 既存のデータを上書きして更新
                val updated = reportRepository.update(
                    existing.copy(
                        date = date,
                        type = ReportType.valueOf(request.type),
                        item = request.item,
                        unitPrice = request.unitPrice,
                        duration = request.duration,
                        amount = request.amount,
                        note = request.note,
                        month = month
                    )
                )
                call.respond(updated.toDto())
            }

            // Delete /api/v1/reports/{id}
            delete("/{id}") {
                val id = call.parameters["id"]?.let { UUID.fromString(it) }
                if (id == null) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Invalid ID"))
                    return@delete
                }

                val existing = reportRepository.findById(id)
                if (existing == null) {
                    call.respond(HttpStatusCode.NotFound, mapOf("error" to "Report not found"))
                    return@delete
                }

                // 権限チェック
                val userId = call.getUserId()
                if (existing.userId != userId && !call.isAdmin()) {
                    call.respond(HttpStatusCode.Forbidden, mapOf("error" to "Not authorized"))
                    return@delete
                }

                val deleted = reportRepository.delete(id)
                if (deleted) {
                    // 204
                    call.respond(HttpStatusCode.NoContent)
                } else {
                    call.respond(HttpStatusCode.NotFound, mapOf("error" to "Report not found"))
                }
            }
        }
    }
}