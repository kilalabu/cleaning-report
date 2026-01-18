val kotlin_version: String by project
val logback_version: String by project

plugins {
    kotlin("jvm") version "2.2.21"
    id("io.ktor.plugin") version "3.3.2"
    id("org.jetbrains.kotlin.plugin.serialization") version "2.2.21"
}

group = "com.cleaning"
version = "0.0.1"

application {
    mainClass = "io.ktor.server.netty.EngineMain"
}

dependencies {
    implementation("io.ktor:ktor-server-core")
    implementation("io.ktor:ktor-server-content-negotiation")
    implementation("io.ktor:ktor-serialization-kotlinx-json")
    implementation("io.ktor:ktor-server-netty")
    implementation("io.ktor:ktor-server-cors")
    implementation("ch.qos.logback:logback-classic:$logback_version")
    implementation("io.ktor:ktor-server-config-yaml")

    // Koin (DI)
    implementation("io.insert-koin:koin-ktor:4.1.1")
    implementation("io.insert-koin:koin-logger-slf4j:4.1.1")

    // Database
    implementation("org.jetbrains.exposed:exposed-core:0.46.0")
    implementation("org.jetbrains.exposed:exposed-dao:0.46.0")
    implementation("org.jetbrains.exposed:exposed-jdbc:0.46.0")
    implementation("org.jetbrains.exposed:exposed-java-time:0.46.0")
    implementation("org.postgresql:postgresql:42.7.1")
    implementation("com.zaxxer:HikariCP:5.1.0")

    // JWT認証
    implementation("io.ktor:ktor-server-auth")
    implementation("io.ktor:ktor-server-auth-jwt")
    // JWKsから公開鍵を取得するためのライブラリ
    implementation("com.auth0:jwks-rsa:0.22.1")

    // Testing
    testImplementation("io.ktor:ktor-server-test-host")
    testImplementation("io.ktor:server-tests-jvm")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit:${kotlin_version}")
    testImplementation("io.insert-koin:koin-test:3.5.3")
}

// ───────────────────────────────────────────────────────────────
// 📦 Fat JAR設定
// ───────────────────────────────────────────────────────────────
// 💡 Ktorプラグイン（io.ktor.plugin）が自動的に buildFatJar タスクを提供
//    ここでは出力ファイル名だけをカスタマイズ
//
// ビルドコマンド: ./gradlew buildFatJar
// 出力先: build/libs/app.jar
ktor {
    fatJar {
        archiveFileName.set("app.jar")
    }
}
