package com.cleaning.models

import kotlinx.serialization.Serializable

/**
 * レポート作成リクエスト
 */
@Serializable
data class CreateReportRequest(
    val date: String,
    val type: String,
    val item: String,
    val unitPrice: Int? = null,
    val duration: Int? = null,
    val amount: Int,
    val note: String? = null
)