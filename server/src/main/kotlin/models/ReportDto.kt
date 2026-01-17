package com.cleaning.models

import kotlinx.serialization.Serializable

// DTO (Data Transfer Object)
// 外部（JSON）とのやり取り専用のクラス
// JSONに変換しやすいよう、UUIDや日付も String として保持
@Serializable
data class ReportDto(
    val id: String,
    val userId: String,
    val date: String,  // "yyyy-MM-dd"
    val type: String,
    val item: String,
    val unitPrice: Int? = null,
    val duration: Int? = null,
    val amount: Int,
    val note: String? = null,
    val month: String,
    val createdAt: String,
    val updatedAt: String? = null
)

/**
 * 型変換: Entity → DTO
 */
fun Report.toDto(): ReportDto = ReportDto(
    id = id.toString(),
    userId = userId.toString(),
    date = date.toString(),
    type = type.name,
    item = item,
    unitPrice = unitPrice,
    duration = duration,
    amount = amount,
    note = note,
    month = month,
    createdAt = createdAt.toString(),
    updatedAt = updatedAt?.toString()
)