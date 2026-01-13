# Phase 3.1: Ktorプロジェクトセットアップ 実装手順書

## 概要

このドキュメントでは、IntelliJ IDEAを使ってKtorプロジェクトを作成し、Cloud Runへデプロイするまでの手順を解説します。

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

### プロジェクト名について
ディレクトリ名は `server` とし、シンプルに保ちます。Ktorを使っていることはビルドファイルで明示されるため、ディレクトリ名に含める必要はありません。

---

## 前提条件

- **IntelliJ IDEA** がインストール済み（Community版でOK）
- **Ktorプラグイン** がインストール済み（後述）
- **JDK 17以上** がインストール済み

---

## 実装手順

### Step 1: Ktorプラグインのインストール

IntelliJ IDEAでKtorプロジェクトを作成するには、Ktorプラグインが必要です。

1. IntelliJ IDEAを開く
2. **Preferences** (macOS) または **Settings** (Windows/Linux) を開く
3. **Plugins** → **Marketplace** タブ
4. 「**Ktor**」で検索
5. **Ktor** プラグインをインストール
6. IDEを再起動

---

### Step 2: IntelliJ IDEAでプロジェクト作成

1. **File** → **New** → **Project** を選択

2. 左側のリストから **Ktor** を選択

3. 以下の設定で作成:

| 項目 | 設定値 |
|:---|:---|
| **Name** | `server` |
| **Location** | `/Users/kuwa/Develop/studio/cleaning-report/server` |
| **Build System** | Gradle Kotlin |
| **Website** | `com.cleaning` |
| **Artifact** | `server` |
| **Ktor Version** | 最新（2.3.x以上推奨） |
| **Engine** | Netty |
| **Configuration in** | HOCON file |
| **Add sample code** | ✅ チェック |

4. **Next** をクリック

5. **Plugins（プラグイン）** 選択画面で以下を追加:

   - **Routing** (必須)
   - **Content Negotiation** (必須)
   - **kotlinx.serialization** (必須)

6. **Create** をクリック

---

### Step 3: プロジェクト構成の確認

IntelliJ IDEAが自動生成したプロジェクト構成:

```
server/
├── build.gradle.kts          # ビルド設定（自動生成）
├── settings.gradle.kts       # プロジェクト設定（自動生成）
├── gradle.properties         # Gradle設定（自動生成）
├── gradle/
│   └── wrapper/              # Gradle Wrapper（自動生成）
├── gradlew                   # Unix用ビルドスクリプト（自動生成）
├── gradlew.bat               # Windows用（自動生成）
└── src/
    └── main/
        ├── kotlin/
        │   └── com/
        │       └── cleaning/
        │           ├── Application.kt       # 自動生成
        │           └── plugins/
        │               ├── Routing.kt       # 自動生成
        │               └── Serialization.kt # 自動生成
        └── resources/
            ├── application.conf             # Ktor設定（自動生成）
            └── logback.xml                  # ログ設定（自動生成）
```

> **Note**: ほとんどのファイルが自動生成されます！手動で作る必要はありません。

---

### Step 4: Application.ktの確認・修正

自動生成された `Application.kt` を確認し、Cloud Run対応の修正を加えます。

#### `src/main/kotlin/com/cleaning/Application.kt`

```kotlin
package com.cleaning

import com.cleaning.plugins.*
import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*

fun main() {
    // 環境変数PORTを取得（Cloud Runでは自動設定される）
    val port = System.getenv("PORT")?.toInt() ?: 8080
    
    embeddedServer(Netty, port = port, host = "0.0.0.0", module = Application::module)
        .start(wait = true)
}

fun Application.module() {
    configureSerialization()
    configureRouting()
}
```

**解説**:
- `host = "0.0.0.0"`: Cloud Run必須（全インターフェースでリッスン）
- `System.getenv("PORT")`: Cloud Runはこの環境変数でポートを指定

---

### Step 5: ヘルスチェックルート追加

自動生成された `Routing.kt` にヘルスチェックを追加します。

#### `src/main/kotlin/com/cleaning/plugins/Routing.kt`

```kotlin
package com.cleaning.plugins

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

fun Application.configureRouting() {
    routing {
        // ヘルスチェックエンドポイント
        get("/health") {
            call.respond(
                HttpStatusCode.OK,
                HealthResponse(
                    status = "ok",
                    timestamp = System.currentTimeMillis()
                )
            )
        }
        
        // 自動生成されたサンプルルート（削除してもOK）
        get("/") {
            call.respondText("Hello World!")
        }
    }
}
```

**解説**:
- `/health`: サーバーの死活監視用エンドポイント
- Cloud Runはこのエンドポイントでヘルスチェックを行う

---

### Step 6: Serialization.ktの確認

自動生成された `Serialization.kt` はそのままでOKです。

#### `src/main/kotlin/com/cleaning/plugins/Serialization.kt`

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

---

### Step 7: ローカルで起動確認

#### IntelliJ IDEAから起動

1. `Application.kt` を開く
2. `fun main()` の左にある ▶️ ボタンをクリック
3. **Run 'ApplicationKt'** を選択

または、ターミナルから:

```bash
cd /Users/kuwa/Develop/studio/cleaning-report/server
./gradlew run
```

#### 動作確認

別ターミナルで:

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

### Step 8: .gitignore確認

IntelliJ IDEAが `.gitignore` を自動生成しますが、以下を追加しておくと良いでしょう:

#### `server/.gitignore` に追加

```
# 既存の内容に追加
.env
*.env.local
```

---

### Step 9: Dockerfile作成

Dockerfileは手動で作成します。

#### `server/Dockerfile`

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
- `buildFatJar`: 全依存を含む単一JAR生成

---

### Step 10: Fat JAR設定確認

`build.gradle.kts` に以下の設定があるか確認（Ktorプラグインで自動追加されている場合もある）:

```kotlin
ktor {
    fatJar {
        archiveFileName.set("app.jar")
    }
}
```

もしなければ追加:

```kotlin
// build.gradle.kts の末尾に追加
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

### Step 11: Dockerイメージビルド確認

```bash
cd /Users/kuwa/Develop/studio/cleaning-report/server
docker build -t cleaning-report-api .
docker run -p 8080:8080 cleaning-report-api

# 別ターミナルで確認
curl http://localhost:8080/health
```

---

### Step 12: Cloud Runへデプロイ

#### 12-1. Google Cloud CLIセットアップ

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

#### 12-2. Artifact Registry設定

```bash
# リポジトリ作成
gcloud artifacts repositories create cleaning-report \
    --repository-format=docker \
    --location=asia-northeast1 \
    --description="Cleaning Report Docker images"

# Docker認証設定
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
```

#### 12-3. イメージをプッシュ

```bash
cd /Users/kuwa/Develop/studio/cleaning-report/server

# タグ付け
docker tag cleaning-report-api \
    asia-northeast1-docker.pkg.dev/cleaning-report-api/cleaning-report/api:latest

# プッシュ
docker push asia-northeast1-docker.pkg.dev/cleaning-report-api/cleaning-report/api:latest
```

#### 12-4. Cloud Runにデプロイ

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

#### 12-5. デプロイ確認

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
server/
├── build.gradle.kts          # 自動生成
├── settings.gradle.kts       # 自動生成
├── gradle.properties         # 自動生成
├── Dockerfile                # 手動作成
├── .gitignore                # 自動生成 + 追記
├── gradle/                   # 自動生成
│   └── wrapper/
├── gradlew                   # 自動生成
├── gradlew.bat               # 自動生成
└── src/
    └── main/
        ├── kotlin/
        │   └── com/cleaning/
        │       ├── Application.kt    # 自動生成 + 修正
        │       └── plugins/
        │           ├── Routing.kt    # 自動生成 + 修正
        │           └── Serialization.kt  # 自動生成
        └── resources/
            ├── application.conf      # 自動生成
            └── logback.xml           # 自動生成
```

---

## 成功基準チェックリスト

- [ ] IntelliJ IDEAでKtorプロジェクト作成成功
- [ ] `./gradlew run` でローカル起動成功
- [ ] `curl http://localhost:8080/health` が200 OKを返す
- [ ] `docker build` 成功
- [ ] `docker run` でコンテナ起動成功
- [ ] Cloud Runへデプロイ成功
- [ ] デプロイURLで`/health`が動作

---

## トラブルシューティング

### Q: Ktorプラグインが見つからない

**A**: IntelliJ IDEA Ultimate版のみKtorプラグインが利用可能です。Community版の場合は[Ktor Project Generator](https://start.ktor.io/)を使用してください。

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

## Ktor Project Generator（代替手段）

IntelliJ IDEAのKtorプラグインが使えない場合は、Webベースのジェネレータを使用できます:

1. https://start.ktor.io/ にアクセス
2. 同様の設定でプロジェクトを生成
3. ZIPをダウンロードして展開
4. `/Users/kuwa/Develop/studio/cleaning-report/server` に配置

---

## 次のステップ

Phase 3.1が完了したら、[Phase 3.2: データベース接続 & CRUD + DI導入](./Phase3.2_DB接続_CRUD_DI.md)に進んでください。
