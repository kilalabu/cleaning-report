package com.cleaning.database

import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource
import org.jetbrains.exposed.sql.Database

object DatabaseFactory {

    fun init() {
        // データベース接続の詳細設定
        val config = HikariConfig().apply {
            jdbcUrl = System.getenv("DATABASE_URL")
                ?: throw IllegalStateException("DATABASE_URL is not set")
            username = System.getenv("DATABASE_USER")
                ?: throw IllegalStateException("DATABASE_USER is not set")
            password = System.getenv("DATABASE_PASSWORD")
                ?: throw IllegalStateException("DATABASE_PASSWORD is not set")

            // 使用するDBドライバー
            driverClassName = "org.postgresql.Driver"

            // コネクションプールの設定
            maximumPoolSize = 3       // 最大接続数（Supabase無料枠は同時接続制限があるため少なめに）
            minimumIdle = 1           // 待機させておく最小接続数
            idleTimeout = 60000       // 未使用接続を破棄するまでの時間（1分）
            connectionTimeout = 10000 // 接続待ちのタイムアウト（10秒）
            maxLifetime = 300000      // 接続の寿命（5分）

            // Supabase接続用SSL設定
            addDataSourceProperty("sslmode", "require")
        }

        // DataSourceの作成とExposedへの紐付け
        val dataSource = HikariDataSource(config)
        Database.connect(dataSource)
    }
}