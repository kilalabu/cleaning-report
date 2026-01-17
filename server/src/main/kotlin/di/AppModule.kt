package com.cleaning.di

import com.cleaning.repositories.ReportRepository
import com.cleaning.repositories.ReportRepositoryImpl
import org.koin.dsl.module

/**
 * アプリケーションのDIモジュール
 */
val appModule = module {
    single<ReportRepository> { ReportRepositoryImpl() }
}