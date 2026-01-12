# Phase 3.1: Ktorプロジェクトセットアップ 実装手順書

## 概要

このドキュメントでは、Ktorを使った最小限のAPIサーバーを構築し、Cloud Runへデプロイするまでの手順を解説します。

**ゴール**: `/health` エンドポイントが動作するKtorサーバーをCloud Runで稼働させる

---

## 前提知識

### Ktorとは？
KtorはJetBrains社が開発したKotlin製の非同期Webフレームワークです。

**Flutterとの比較で理解する**:
| 概念 | Flutter | Ktor |
|:---|:---|:---|
| エントリポイント | `main()` | `Application.kt` |
| UI/ルーティング | Widget Tree | Routing Plugin |
| 状態管理 | Riverpod/Provider | Koin (Phase 3.2で導入) |
| ビルドツール | `flutter build` | `./gradlew build` |

### Gradleとは？
JavaやKotlinプロジェクトのビルドツールです。Flutterでいう`pubspec.yaml` + `flutter`コマンドに相当します。

---

## 実装手順

### Step 1: プロジェクトディレクトリ作成

```bash
cd /Users/kuwa/Develop/studio/cleaning-report
mkdir -p ktor-server/src/main/kotlin/com/cleaning
mkdir -p ktor-server/src/main/resources
cd ktor-server
```

---

### Step 2: Gradleビルドファイル作成

#### `ktor-server/settings.gradle.kts`

```kotlin
rootProject.name = "cleaning-report-api"
```

**解説**: プロジェクト名を定義。Flutterでいう`pubspec.yaml`の`name:`に相当。

---

#### `ktor-server/gradle.properties`

```properties
kotlin.code.style=official
org.gradle.jvmargs=-Xmx1024m
```

**解説**: Gradleの設定。メモリ制限などを指定。

---

#### `ktor-server/build.gradle.kts`

```kotlin
plugins {
    kotlin("jvm") version "1.9.22"
    kotlin("plugin.serialization") version "1.9.22"
    id("io.ktor.plugin") version "2.3.7"
}

group = "com.cleaning"
version = "1.0.0"

application {
    mainClass.set("com.cleaning.ApplicationKt")
}

repositories {
    mavenCentral()
}

dependencies {
    // Ktor Server
    implementation("io.ktor:ktor-server-core-jvm")
    implementation("io.ktor:ktor-server-netty-jvm")
    implementation("io.ktor:ktor-server-content-negotiation-jvm")
    implementation("io.ktor:ktor-serialization-kotlinx-json-jvm")
    
    // Logging
    implementation("ch.qos.logback:logback-classic:1.4.14")
    
    // Testing
    testImplementation("io.ktor:ktor-server-tests-jvm")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit:1.9.22")
}

ktor {
    docker {
        jreVersion.set(JavaVersion.VERSION_17)
        localImageName.set("cleaning-report-api")
    }
}
```

**解説**:
- `plugins`: 使用するGradleプラグイン（Flutter の dependency と似ている）
- `dependencies`: ライブラリ依存関係（pubspec.yaml の dependencies に相当）
- `application.mainClass`: エントリポイント指定
- `ktor.docker`: Docker設定

---

### Step 3: アプリケーションコード作成

#### `ktor-server/src/main/kotlin/com/cleaning/Application.kt`

```kotlin
package com.cleaning

import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import com.cleaning.plugins.*

fun main() {
    // 環境変数PORTを取得（Cloud Runでは自動設定される）
    val port = System.getenv("PORT")?.toInt() ?: 8080
    
    embeddedServer(Netty, port = port, host = "0.0.0.0") {
        configureRouting()
        configureSerialization()
    }.start(wait = true)
}
```

**解説**:
- `embeddedServer`: Nettyサーバーを起動（FlutterでいうrunApp()に相当）
- `port`: Cloud Runは環境変数`PORT`でポートを指定
- `host = "0.0.0.0"`: 全てのインターフェースでリッスン（Cloud Run必須）

---

#### `ktor-server/src/main/kotlin/com/cleaning/plugins/Routing.kt`

```kotlin
package com.cleaning.plugins

import io.ktor.server.application.*
import io.ktor.server.routing.*
import com.cleaning.routes.healthRoutes

fun Application.configureRouting() {
    routing {
        healthRoutes()
    }
}
```

**解説**:
- `routing { }`: ルート定義ブロック（Flutter のGoRouterに相当）
- `Application.configureRouting()`: 拡張関数でApplicationに機能追加

---

#### `ktor-server/src/main/kotlin/com/cleaning/plugins/Serialization.kt`

```kotlin
package com.cleaning.plugins

import io.ktor.serialization.kotlinx.json.*
import io.ktor.server.application.*
import io.ktor.server.plugins.contentnegotiation.*
import kotlinx.serialization.json.Json

fun Application.configureSerialization() {
    install(ContentNegotiation) {
        json(Json {
            prettyPrint = true
            isLenient = true
        })
    }
}
```

**解説**:
- `install()`: プラグインをインストール（FlutterでいうProviderの追加に近い）
- `ContentNegotiation`: リクエスト/レスポンスのJSON変換を自動化

---

#### `ktor-server/src/main/kotlin/com/cleaning/routes/HealthRoute.kt`

```kotlin
package com.cleaning.routes

import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable

@Serializable
data class HealthResponse(
    val status: String,
    val timestamp: Long
)

fun Route.healthRoutes() {
    get("/health") {
        call.respond(
            HttpStatusCode.OK,
            HealthResponse(
                status = "ok",
                timestamp = System.currentTimeMillis()
            )
        )
    }
}
```

**解説**:
- `@Serializable`: kotlinx.serializationでJSON変換対象にする
- `get("/health")`: GETリクエストハンドラ定義
- `call.respond()`: レスポンス返却（Flutterでいうreturn Response）

---

### Step 4: ログ設定

#### `ktor-server/src/main/resources/logback.xml`

```xml
<configuration>
    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{YYYY-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>
    <root level="INFO">
        <appender-ref ref="STDOUT"/>
    </root>
</configuration>
```

---

### Step 5: .gitignore作成

#### `ktor-server/.gitignore`

```
.gradle/
build/
.idea/
*.iml
local.properties
.env
```

---

### Step 6: Gradle Wrapper生成

```bash
cd /Users/kuwa/Develop/studio/cleaning-report/ktor-server

# Gradle Wrapperがない場合は生成（要: Gradle本体をインストール）
# brew install gradle
gradle wrapper --gradle-version 8.5
```

> **Note**: `gradle`コマンドがない場合は `brew install gradle` でインストール

---

### Step 7: ローカルで起動確認

```bash
cd /Users/kuwa/Develop/studio/cleaning-report/ktor-server
./gradlew run
```

別ターミナルで確認:

```bash
curl http://localhost:8080/health
```

期待レスポンス:

```json
{
  "status": "ok",
  "timestamp": 1736693456789
}
```

---

### Step 8: Dockerfile作成

#### `ktor-server/Dockerfile`

```dockerfile
# ビルドステージ
FROM gradle:8.5-jdk17 AS build
WORKDIR /app
COPY . .
RUN gradle buildFatJar --no-daemon

# 実行ステージ
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/build/libs/*-all.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**解説**:
- マルチステージビルド: ビルド用イメージで依存解決→軽量イメージにJARだけコピー
- `buildFatJar`: 全依存を含む単一JARを生成

---

#### Fat JAR設定を追加

`build.gradle.kts` に以下を追加:

```kotlin
// 既存のktor { } ブロックの後に追加
tasks.register<Jar>("buildFatJar") {
    archiveClassifier.set("all")
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    manifest {
        attributes["Main-Class"] = "com.cleaning.ApplicationKt"
    }
    from(configurations.runtimeClasspath.get().map { if (it.isDirectory) it else zipTree(it) })
    with(tasks.jar.get())
}
```

---

### Step 9: Dockerイメージビルド確認

```bash
cd /Users/kuwa/Develop/studio/cleaning-report/ktor-server
docker build -t cleaning-report-api .
docker run -p 8080:8080 cleaning-report-api

# 別ターミナルで確認
curl http://localhost:8080/health
```

---

### Step 10: Cloud Runへデプロイ

#### 10-1. Google Cloud CLIセットアップ

```bash
# gcloud CLIインストール（未インストールの場合）
brew install --cask google-cloud-sdk

# ログイン
gcloud auth login

# プロジェクト作成または選択
gcloud projects create cleaning-report-api --name="Cleaning Report API"
gcloud config set project cleaning-report-api

# 必要なAPIを有効化
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

#### 10-2. Artifact Registry設定

```bash
# リポジトリ作成
gcloud artifacts repositories create cleaning-report \
    --repository-format=docker \
    --location=asia-northeast1 \
    --description="Cleaning Report Docker images"

# Docker認証設定
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
```

#### 10-3. イメージをプッシュ

```bash
cd /Users/kuwa/Develop/studio/cleaning-report/ktor-server

# タグ付け
docker tag cleaning-report-api \
    asia-northeast1-docker.pkg.dev/cleaning-report-api/cleaning-report/api:latest

# プッシュ
docker push asia-northeast1-docker.pkg.dev/cleaning-report-api/cleaning-report/api:latest
```

#### 10-4. Cloud Runにデプロイ

```bash
gcloud run deploy cleaning-report-api \
    --image asia-northeast1-docker.pkg.dev/cleaning-report-api/cleaning-report/api:latest \
    --platform managed \
    --region asia-northeast1 \
    --allow-unauthenticated \
    --memory 256Mi \
    --cpu 1 \
    --min-instances 0 \
    --max-instances 1
```

**解説**:
- `--allow-unauthenticated`: 認証なしアクセス許可（後で変更可能）
- `--min-instances 0`: コールドスタート許容（無料枠節約）
- `--max-instances 1`: スケール上限（無料枠節約）

#### 10-5. デプロイ確認

```bash
# デプロイされたURLを取得
gcloud run services describe cleaning-report-api \
    --platform managed \
    --region asia-northeast1 \
    --format 'value(status.url)'

# 動作確認
curl https://cleaning-report-api-xxxxx-an.a.run.app/health
```

---

## ディレクトリ構成（完成形）

```
ktor-server/
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
├── Dockerfile
├── .gitignore
├── gradle/
│   └── wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
├── gradlew
├── gradlew.bat
└── src/
    └── main/
        ├── kotlin/
        │   └── com/
        │       └── cleaning/
        │           ├── Application.kt
        │           ├── plugins/
        │           │   ├── Routing.kt
        │           │   └── Serialization.kt
        │           └── routes/
        │               └── HealthRoute.kt
        └── resources/
            └── logback.xml
```

---

## 成功基準チェックリスト

- [ ] `./gradlew run` でローカル起動成功
- [ ] `curl http://localhost:8080/health` が200 OKを返す
- [ ] `docker build` 成功
- [ ] `docker run` でコンテナ起動成功
- [ ] Cloud Runへデプロイ成功
- [ ] デプロイURLで`/health`が動作

---

## トラブルシューティング

### Q: `./gradlew run` でエラー

**A**: JDK 17がインストールされているか確認:
```bash
java -version  # 17以上が必要
# なければ: brew install openjdk@17
```

### Q: Docker buildでメモリエラー

**A**: Docker Desktopのメモリ制限を増やす（4GB推奨）

### Q: Cloud Runでコールドスタートが遅い

**A**: 初回アクセスは10-30秒かかる。これは無料枠で運用する上での制約。

---

## 次のステップ

Phase 3.1が完了したら、[Phase 3.2: データベース接続 & CRUD + DI導入](./Phase3.2_DB接続_CRUD_DI.md)に進んでください。
