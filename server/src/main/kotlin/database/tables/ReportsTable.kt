package com.cleaning.database.tables

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.javatime.date
import org.jetbrains.exposed.sql.javatime.datetime

object ReportsTable : Table("reports") {
    val id = uuid("id")
    val userId = uuid("user_id")
    val date = date("date")
    val type = varchar("type", 50)
    val item = varchar("item", 255)
    val unitPrice = integer("unit_price").nullable()
    val duration = integer("duration").nullable()
    val amount = integer("amount")
    val note = text("note").nullable()
    val month = varchar("month", 7)
    val createdAt = datetime("created_at")
    val updatedAt = datetime("updated_at").nullable()

    override val primaryKey = PrimaryKey(id)
}