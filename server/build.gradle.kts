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
    implementation("ch.qos.logback:logback-classic:$logback_version")
    implementation("io.ktor:ktor-server-config-yaml")
    testImplementation("io.ktor:ktor-server-test-host")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit:$kotlin_version")
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
