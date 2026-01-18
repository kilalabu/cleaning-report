package com.cleaning.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName

// DTO (Data Transfer Object)
// 外部（JSON）とのやり取り専用のクラス
@Serializable
data class ReportDto(
    val id: String,
    @SerialName("user_id") val userId: String,
    val date: String,  // "yyyy-MM-dd"
    val type: String,
    val item: String,
    @SerialName("unit_price") val unitPrice: Int? = null,
    val duration: Int? = null,
    val amount: Int,
    val note: String? = null,
    val month: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String? = null
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
