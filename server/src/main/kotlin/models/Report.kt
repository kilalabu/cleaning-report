package com.cleaning.models

import java.time.LocalDate
import java.time.LocalDateTime
import java.util.UUID

data class Report(
    val id: UUID,
    val userId: UUID,
    val date: LocalDate,
    val type: ReportType,
    val item: String,
    val unitPrice: Int?,
    val duration: Int?,
    val amount: Int,
    val note: String?,
    val month: String,
    val createdAt: LocalDateTime,
    val updatedAt: LocalDateTime?
)

enum class ReportType {
    work, expense
}