package com.cleaning.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName

/**
 * レポート作成リクエスト
 */
@Serializable
data class CreateReportRequest(
    val date: String,
    val type: String,
    val item: String,
    @SerialName("unit_price") val unitPrice: Int? = null,
    val duration: Int? = null,
    val amount: Int,
    val note: String? = null
)
