package com.cleaning.repositories

import com.cleaning.database.tables.ReportsTable
import com.cleaning.models.Report
import com.cleaning.models.ReportType
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import org.jetbrains.exposed.sql.transactions.transaction
import java.time.LocalDateTime
import java.util.UUID

/**
 * 💡 Android的に言うと: Room の @Dao インターフェースに相当
 */
interface ReportRepository {
    fun findByMonth(month: String, userId: UUID): List<Report>
    fun findById(id: UUID): Report?
    fun create(report: Report): Report
    fun update(report: Report): Report
    fun delete(id: UUID): Boolean
}

class ReportRepositoryImpl : ReportRepository {

    override fun findByMonth(
        month: String,
        userId: UUID
    ): List<Report> = transaction {
        ReportsTable
            .selectAll()
            .where { (ReportsTable.month eq month) and (ReportsTable.userId eq userId) }
            .orderBy(ReportsTable.date, SortOrder.DESC)
            .map { it.toReport() }
    }

    override fun findById(id: UUID): Report? = transaction {
        ReportsTable
            .selectAll()
            .where { ReportsTable.id eq id }
            .map { it.toReport() }
            .singleOrNull()
    }

    override fun create(report: Report): Report = transaction {
        val newId = UUID.randomUUID()
        val now = LocalDateTime.now()

        ReportsTable.insert {
            it[id] = newId
            it[userId] = report.userId
            it[date] = report.date
            it[type] = report.type.name
            it[item] = report.item
            it[unitPrice] = report.unitPrice
            it[duration] = report.duration
            it[amount] = report.amount
            it[note] = report.note
            it[month] = report.month
            it[createdAt] = now
            it[updatedAt] = now
        }

        report.copy(id = newId, createdAt = now, updatedAt = now)
    }

    override fun update(report: Report): Report = transaction {
        val now = LocalDateTime.now()

        ReportsTable.update(where = { ReportsTable.id eq report.id }) {
            it[date] = report.date
            it[type] = report.type.name
            it[item] = report.item
            it[unitPrice] = report.unitPrice
            it[duration] = report.duration
            it[amount] = report.amount
            it[note] = report.note
            it[month] = report.month
            it[updatedAt] = now
        }

        report.copy(updatedAt = now)
    }

    override fun delete(id: UUID): Boolean = transaction {
        ReportsTable.deleteWhere { ReportsTable.id eq id } > 0
    }

    private fun ResultRow.toReport(): Report = Report(
        id = this[ReportsTable.id],
        userId = this[ReportsTable.userId],
        date = this[ReportsTable.date],
        type = ReportType.valueOf(this[ReportsTable.type]),
        item = this[ReportsTable.item],
        unitPrice = this[ReportsTable.unitPrice],
        duration = this[ReportsTable.duration],
        amount = this[ReportsTable.amount],
        note = this[ReportsTable.note],
        month = this[ReportsTable.month],
        createdAt = this[ReportsTable.createdAt],
        updatedAt = this[ReportsTable.updatedAt]
    )
}