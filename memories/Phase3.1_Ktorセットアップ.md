# Phase 3.1: Ktorプロジェクトセットアップ 実装手順書

## 概要

このドキュメントでは、IntelliJ IDEAを使ってKtorプロジェクトを作成し、Cloud Runへデプロイするまでの手順を解説します。

**ゴール**: `/health` エンドポイントが動作するKtorサーバーをCloud Runで稼働させる

> 💡 **始める前に**
> Ktor, Cloud Run, Dockerを選んだ理由や、システム全体のアーキテクチャについては、まず以下のドキュメントをご覧ください：
> [📖 Phase 3: バックエンド技術選定とアーキテクチャ概要](./Phase3_Architecture_Overview.md)

---

## 前提知識

### サーバーサイド開発とは？（Android開発者向け）

Androidアプリ開発では「画面を作る」ことが中心ですが、サーバーサイド開発では「**リクエストを受けてレスポンスを返す**」ことが中心です。

```
┌─────────────┐      HTTP Request       ┌─────────────┐
│   Android   │  ─────────────────────▶ │   Server    │
│     App     │                         │   (Ktor)    │
│             │  ◀───────────────────── │             │
└─────────────┘      HTTP Response      └─────────────┘

例：
Request:  GET /api/reports?month=2026-01
Response: { "reports": [...] }
```

#### Androidアプリとの役割比較

```
【Androidアプリの役割】
- UIを表示する
- ユーザー入力を受け付ける
- サーバーにデータを要求する（Retrofit等で）
- 受け取ったデータを画面に表示する

【サーバーの役割】
- リクエストを受け付ける
- データベースからデータを取得/保存する
- ビジネスロジックを実行する
- レスポンスを返す
```

### HTTPリクエスト/レスポンスの基礎

Androidで `Retrofit` を使うとき、こんなコードを書きますよね：

```kotlin
// Android側（Retrofit）
interface ReportApi {
    @GET("api/reports")
    suspend fun getReports(@Query("month") month: String): List<Report>
    
    @POST("api/reports")
    suspend fun createReport(@Body report: Report): Report
}
```

これに対応するサーバー側（Ktor）のコードはこうなります：

```kotlin
// サーバー側（Ktor）
routing {
    get("/api/reports") {
        val month = call.request.queryParameters["month"]
        val reports = reportRepository.findByMonth(month)
        call.respond(reports)  // JSONで返す
    }
    
    post("/api/reports") {
        val report = call.receive<Report>()  // JSONを受け取る
        val saved = reportRepository.save(report)
        call.respond(saved)
    }
}
```

**ポイント**: Androidで書いていたAPIの「呼び出し側」を、今度は「受け取る側」として実装します。

### ルーティングとは？

「どのURLにアクセスしたら、どの処理を実行するか」を定義することです。

```kotlin
// AndroidのNavigation Componentとの比較
// Android: 画面遷移のルート定義
NavHost(navController, startDestination = "home") {
    composable("home") { HomeScreen() }
    composable("detail/{id}") { DetailScreen(it.arguments?.getString("id")) }
}

// Ktor: APIエンドポイントのルート定義
routing {
    get("/") { call.respondText("Home") }
    get("/detail/{id}") { 
        val id = call.parameters["id"]
        call.respond(getDetail(id))
    }
}
```

### Ktorとは？

KtorはJetBrains社が開発したKotlin製の非同期Webフレームワークです。
Androidと同じKotlinで書けるため、言語の学習コストがありません。

**なぜKtorを選ぶのか？**
- ✅ Kotlinで書ける（Androidエンジニアなら馴染みやすい）
- ✅ Coroutine標準対応（`suspend fun`がそのまま使える）
- ✅ 軽量・高速（Spring Bootより起動が速い）
- ✅ JetBrains製（Kotlin/IntelliJと親和性が高い）

**Android開発との比較で理解する**:

| 概念 | Android | Ktor |
|:---|:---|:---|
| エントリポイント | `Application.onCreate()` | `Application.module()` |
| ルーティング | Navigation Component | Routing Plugin |
| HTTP通信 | Retrofit（クライアント） | Ktor（サーバー） |
| JSONパース | Gson/Moshi | kotlinx.serialization |
| DI | Hilt/Dagger | Koin (Phase 3.2で導入) |
| 非同期処理 | Coroutine/Flow | Coroutine（同じ！） |
| ビルドツール | Gradle | Gradle（同じ！） |

### プラグイン（Plugins）とは？

Ktorの「プラグイン」は、Androidの「ライブラリ依存」に近い概念です。
必要な機能だけを追加していく設計思想です。

```kotlin
// Ktorのプラグイン = 機能の追加
fun Application.module() {
    install(ContentNegotiation) { json() }  // JSONサポート追加
    install(Authentication) { ... }          // 認証機能追加
    install(CORS) { ... }                    // CORS設定追加
}

// Android的に言うと...
// build.gradle.kts に implementation(...) を追加するようなもの
```

### プロジェクト名について

ディレクトリ名は `server` とし、シンプルに保ちます。Ktorを使っていることはビルドファイルで明示されるため、ディレクトリ名に含める必要はありません。

---

## 前提条件

- **IntelliJ IDEA** がインストール済み（Community版でOK）
- **Ktorプラグイン** がインストール済み（後述）
- **JDK 17以上** がインストール済み
- **Google Cloud 請求先アカウント**: API有効化のために必須（無料枠内でも登録が必要）

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

// ───────────────────────────────────────────────────────────────
// 🔍 import文の解説
// ───────────────────────────────────────────────────────────────
import com.cleaning.plugins.*          // 自分で作ったプラグイン（Routing, Serialization等）
import io.ktor.server.application.*    // Applicationクラス（サーバーの中核）
import io.ktor.server.engine.*         // サーバーエンジン起動用
import io.ktor.server.netty.*          // Nettyエンジン（高性能HTTPサーバー）

// ───────────────────────────────────────────────────────────────
// 🚀 main関数 - サーバーのエントリーポイント
// ───────────────────────────────────────────────────────────────
// 💡 Android的に言うと Application.onCreate() のようなもの
//    ただし、UIを起動する代わりにHTTPサーバーを起動します
fun main() {
    // 📌 Cloud Runは自動的にPORT環境変数を設定する
    //    ローカル開発時はPORTが未設定なので8080をデフォルトに使用
    val port = System.getenv("PORT")?.toInt() ?: 8080
    
    // 📌 embeddedServer: Ktorサーバーを起動するメイン関数
    //    - Netty: 使用するHTTPサーバーエンジン（高性能・非同期）
    //    - port: リッスンするポート番号
    //    - host: どのネットワークインターフェースで待ち受けるか
    //    - module: サーバーの設定を行う関数への参照
    embeddedServer(
        Netty,                          // HTTPサーバーエンジン
        port = port,                    // ポート番号
        host = "0.0.0.0",               // 全IPアドレスで待ち受け ⚠️ Cloud Run必須
        module = Application::module    // 設定モジュール
    ).start(wait = true)                // サーバー起動（waitでプロセスを維持）
}

// ───────────────────────────────────────────────────────────────
// 📦 Application.module() - サーバーの設定を定義
// ───────────────────────────────────────────────────────────────
// 💡 Android的に言うと MainActivity.onCreate() でUIをセットアップするような役割
//    ここでは「どんな機能（プラグイン）を使うか」を設定します
fun Application.module() {
    // 👇 JSON変換機能を有効化（Moshi/Gsonの設定に相当）
    configureSerialization()
    
    // 👇 ルーティング（URL→処理のマッピング）を設定
    //    AndroidのNavigation Componentに相当
    configureRouting()
}
```

**コード解説（Android開発者向け）**:

| Ktorのコード | Androidで例えると |
|:---|:---|
| `fun main()` | `Application.onCreate()` |
| `embeddedServer(...)` | アプリを起動する処理 |
| `Application.module()` | `MainActivity.onCreate()` でUIを設定 |
| `configureSerialization()` | `Retrofit.Builder().addConverterFactory(MoshiConverterFactory.create())` |
| `configureRouting()` | `NavHost` でルートを定義 |

**重要ポイント**:

- **`host = "0.0.0.0"`について**:
  - ローカル開発では `127.0.0.1`（localhost）でも動きます
  - しかしCloud Runのコンテナ内で動かす場合、`0.0.0.0`でないと外部からアクセスできません
  - これは「全てのネットワークインターフェースで待ち受ける」という意味です

- **`System.getenv("PORT")`について**:
  - Cloud Runは、コンテナ起動時に `PORT` 環境変数を自動設定します
  - ポート番号はCloud Runが動的に決めるため、ハードコードは❌
  - `?: 8080` はローカル開発用のデフォルト値です

---

### Step 5: ヘルスチェックルート追加

自動生成された `Routing.kt` にヘルスチェックを追加します。

#### `src/main/kotlin/com/cleaning/plugins/Routing.kt`

```kotlin
package com.cleaning.plugins

// ───────────────────────────────────────────────────────────────
// 🔍 import文の解説
// ───────────────────────────────────────────────────────────────
import io.ktor.http.*                   // HTTPステータスコード（200 OK, 404 Not Found等）
import io.ktor.server.application.*     // Applicationクラス
import io.ktor.server.response.*        // レスポンスを返すための拡張関数
import io.ktor.server.routing.*         // ルーティングDSL
import kotlinx.serialization.Serializable  // JSON変換用アノテーション

// ───────────────────────────────────────────────────────────────
// 📦 レスポンス用データクラス
// ───────────────────────────────────────────────────────────────
// 💡 @Serializableアノテーション
//    - Android: Moshi の @JsonClass(generateAdapter = true) に相当
//    - このアノテーションがあると、自動的にJSON変換が可能になります
//    - 例: { "status": "ok", "timestamp": 1736693456789 }
@Serializable
data class HealthResponse(
    val status: String,    // サーバーの状態（"ok"など）
    val timestamp: Long    // レスポンス生成時刻（ミリ秒）
)

// ───────────────────────────────────────────────────────────────
// 🛣️ ルーティング設定
// ───────────────────────────────────────────────────────────────
// 💡 Application.configureRouting() は「拡張関数」
//    Applicationクラスにメソッドを追加するKotlinの機能です
//    Android的には、ActivityにUtilメソッドを追加するようなイメージ
fun Application.configureRouting() {
    
    // 📌 routing { } ブロック = ルートを定義するDSL
    //    Android的には NavHost { } でルートを定義するのに似ています
    routing {
        
        // ─────────────────────────────────────────────────────
        // 🏥 ヘルスチェックエンドポイント
        // ─────────────────────────────────────────────────────
        // 💡 get("/health") = GETメソッドで /health にアクセスしたとき
        //    
        //    HTTPメソッドとは？
        //    - GET:    データを取得する（読み取り専用）
        //    - POST:   データを作成する
        //    - PUT:    データを更新する
        //    - DELETE: データを削除する
        //
        //    Androidからは Retrofit で @GET("health") として呼び出します
        get("/health") {
            
            // 📌 call = 現在のHTTPリクエスト/レスポンスのコンテキスト
            //    Android的には Intent のようなもの（情報を運ぶもの）
            //
            // 📌 call.respond() = レスポンスをクライアントに返す
            //    - 第1引数: HTTPステータスコード（200 OK）
            //    - 第2引数: レスポンスボディ（自動でJSONに変換される）
            call.respond(
                HttpStatusCode.OK,           // HTTP 200 OK
                HealthResponse(              // 👇 このオブジェクトがJSONになる
                    status = "ok",
                    timestamp = System.currentTimeMillis()
                )
            )
        }
        
        // ─────────────────────────────────────────────────────
        // 🏠 ルートパス
        // ─────────────────────────────────────────────────────
        // 自動生成されたサンプルルート（削除してもOK）
        get("/") {
            // 📌 call.respondText() = プレーンテキストを返す
            //    JSONではなくシンプルな文字列を返したい場合に使用
            call.respondText("Hello World!")
        }
    }
}
```

**コード解説（Android開発者向け）**:

| Ktorのコード | Androidで例えると |
|:---|:---|
| `@Serializable` | `@JsonClass(generateAdapter = true)` (Moshi) |
| `routing { }` | `NavHost { }` でルート定義 |
| `get("/health")` | Retrofitの `@GET("health")` |
| `call` | `Intent` や `Bundle`（リクエスト情報を持つ） |
| `call.respond(...)` | Retrofitの戻り値として `Response<T>` を返す |

**ヘルスチェックエンドポイントとは？**

サーバーが「生きているか」を確認するための最小限のAPIです。

```
┌───────────────────────────────────────────────────────────────┐
│  🏥 ヘルスチェックの役割                                        │
├───────────────────────────────────────────────────────────────┤
│  1. Cloud Run/ロードバランサーがサーバー死活監視に使用          │
│  2. デプロイ後の動作確認に使用                                  │
│  3. 監視ツール（Datadog等）がサーバー状態をモニタリング          │
└───────────────────────────────────────────────────────────────┘
```

---

### Step 6: Serialization.ktの確認

自動生成された `Serialization.kt` はそのままでOKです。
この設定により、**Kotlinオブジェクト ↔ JSON** の自動変換が有効になります。

#### `src/main/kotlin/com/cleaning/plugins/Serialization.kt`

```kotlin
package com.cleaning.plugins

// ───────────────────────────────────────────────────────────────
// 🔍 import文の解説
// ───────────────────────────────────────────────────────────────
import io.ktor.serialization.kotlinx.json.*        // kotlinx.serialization用アダプター
import io.ktor.server.application.*                 // Applicationクラス
import io.ktor.server.plugins.contentnegotiation.*  // Content Negotiationプラグイン
import kotlinx.serialization.json.Json              // JSONエンコーダー/デコーダー

// ───────────────────────────────────────────────────────────────
// 📦 JSON変換設定
// ───────────────────────────────────────────────────────────────
// 💡 この設定は、Android側でRetrofitにMoshiを設定するのと同じ役割
//
//    Android側のコード（参考）:
//    val moshi = Moshi.Builder()
//        .add(KotlinJsonAdapterFactory())
//        .build()
//    
//    Retrofit.Builder()
//        .addConverterFactory(MoshiConverterFactory.create(moshi))
//        .build()
//
fun Application.configureSerialization() {
    
    // 📌 install() = Ktorにプラグイン（機能）を追加
    //    Android的には、build.gradle に implementation を追加するイメージ
    install(ContentNegotiation) {
        
        // 📌 json() = このサーバーはJSONでデータをやり取りする
        //    Content-Type: application/json で送受信
        json(Json {
            // 👇 prettyPrint = trueにすると、JSONが見やすくフォーマットされる
            //    デバッグ時に便利（本番では false が推奨）
            //    true:  { "status": "ok", "timestamp": 123 }
            //    false: {"status":"ok","timestamp":123}
            prettyPrint = true
            
            // 👇 isLenient = trueにすると、少し緩いJSONも受け入れる
            //    例: シングルクォートで囲まれた文字列など
            isLenient = true
            
            // 👇 よく使う他のオプション（必要に応じて追加）
            // ignoreUnknownKeys = true   // 知らないキーがあっても無視
            // encodeDefaults = true      // デフォルト値もJSONに含める
        })
    }
}
```

**コード解説（Android開発者向け）**:

| Ktorのコード | Androidで例えると |
|:---|:---|
| `install(ContentNegotiation)` | `Retrofit.Builder().addConverterFactory(...)` |
| `json(Json { ... })` | `MoshiConverterFactory.create(moshi)` |
| `prettyPrint` | Logcatで見やすい出力（開発用） |
| `isLenient` | 緩いパース設定 |

**Content Negotiationとは？**

```
┌───────────────────────────────────────────────────────────────┐
│  📝 Content Negotiation（コンテンツネゴシエーション）          │
├───────────────────────────────────────────────────────────────┤
│  クライアントとサーバーの間で「どの形式でデータをやり取りするか」 │
│  を決めるHTTPの仕組み                                          │
│                                                                 │
│  例：                                                           │
│  リクエスト:  Content-Type: application/json                    │
│  レスポンス: Content-Type: application/json                     │
│                                                                 │
│  Ktorはこのヘッダーを見て、自動的にJSON変換を行います           │
└───────────────────────────────────────────────────────────────┘
```

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

> 💡 **Dockerとは？** 
> アプリケーションを「コンテナ」という隔離された環境で動かす技術です。
> Android的に言うと、「どのデバイスでも同じように動くAPK」のようなイメージです。

#### `server/Dockerfile`

```dockerfile
# ═══════════════════════════════════════════════════════════════
# 🏗️ マルチステージビルド
# ════════════════════════════════════════───────────────────────

# ───────────────────────────────────────────────────────────────
# 📦 ステージ1: ビルド
# ───────────────────────────────────────────────────────────────
# 💡 Ktorプラグイン 3.3.2 は Gradle 8.11+ を必要とするため、最新版を使用
FROM gradle:8.12-jdk17 AS build

# 作業ディレクトリを /app に設定
WORKDIR /app

# ローカルの全ファイルをコンテナ内にコピー
COPY . .

# Fat JARをビルド（全依存を含む単一JARファイル）
RUN gradle buildFatJar --no-daemon

# ───────────────────────────────────────────────────────────────
# 🚀 ステージ2: 実行
# ───────────────────────────────────────────────────────────────
# 💡 eclipse-temurin:17-jre を使用（Alpine版はApple Silicon非対応のため）
FROM eclipse-temurin:17-jre

# 作業ディレクトリを設定
WORKDIR /app

# ステージ1（build）で生成したJARを、現在のステージにコピー
# 💡 build.gradle.kts で archiveFileName を "app.jar" に設定した名前に合わせる
COPY --from=build /app/build/libs/app.jar app.jar

# ポート開放（ドキュメント目的）
EXPOSE 8080

# コンテナ起動時に実行するコマンド
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**コード解説（Android開発者向け）**:

| Dockerの概念 | Androidで例えると |
|:---|:---|
| Dockerfile | `build.gradle` でビルド設定を定義 |
| `docker build` | `./gradlew assembleRelease` でAPK生成 |
| Dockerイメージ | 署名済みAPKファイル |
| Dockerコンテナ | APKがインストールされて動いている状態 |

**ビルドの流れ**:

```
┌───────────────────────────────────────────────────────────────┐
│  📦 マルチステージビルドの流れ                                  │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  [ステージ1: build]                                            │
│    gradle:8.12-jdk17 イメージ (約1GB)                          │
│         ↓                                                       │
│    ソースコード + Gradle = ビルド実行                          │
│         ↓                                                       │
│    Fat JAR 生成 (app.jar, 約50MB)                               │
│                                                                 │
│  [ステージ2: 実行用]                                           │
│    eclipse-temurin:17-jre イメージ (約200MB)                   │
│         ↓                                                       │
│    Fat JAR だけをコピー                                         │
│         ↓                                                       │
│    最終イメージ ← これだけがCloud Runにデプロイ                │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

---

### Step 10: Fat JAR設定確認

`build.gradle.kts` に以下の設定があるか確認します。

> ⚠️ **重要**: Ktorプラグイン（`io.ktor.plugin`）は自動的に `buildFatJar` タスクを提供します。
> 手動で `tasks.register<Jar>("buildFatJar")` を追加すると **タスク名重複エラー** になるので注意！

```kotlin
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
```

**コード解説**:

| 設定 | 説明 |
|:---|:---|
| `ktor { }` | Ktorプラグイン専用の設定ブロック |
| `fatJar { }` | Fat JAR（全依存込みJAR）の設定 |
| `archiveFileName.set("app.jar")` | 出力ファイル名を `app.jar` に固定 |

**Fat JARをビルドするコマンド**:

```bash
./gradlew buildFatJar

# 出力先: build/libs/app.jar
```

---

### Step 11: Dockerイメージビルド確認

```bash
cd /Users/kuwa/Develop/studio/cleaning-report/server

# 💡 Apple Silicon Mac (M1/M2/M3) の場合は --platform linux/amd64 が必須
# これを指定しないと、Cloud Run (AMD64) で動作しません
docker build --platform linux/amd64 -t cleaning-report-api .

# ローカルでの実行確認
# ポート 8080 が使用中の場合は事前に終了させるか、別のポート（-p 8081:8080等）を指定してください
docker run -p 8080:8080 cleaning-report-api

# 別ターミナルで確認
curl http://localhost:8080/health
```

---

### Step 12: Cloud Runへデプロイ

> 💡 **Cloud Runとは？**
> Googleが提供する「サーバーレス」のコンテナ実行環境です。
> 
> Android的に言うと:
> - Firebase Hosting = 静的サイトのホスティング
> - Cloud Run = 動的なサーバーアプリのホスティング
> 
> **特徴**:
> - リクエストが来たときだけ起動 → 使った分だけ課金
> - 自動スケール（アクセス増→インスタンス増）
> - HTTPSも自動設定

#### 12-1. Google Cloud CLIセットアップ

```bash
# ───────────────────────────────────────────────────────────────
# 📦 gcloud CLIインストール（Homebrewを使用）
# ───────────────────────────────────────────────────────────────
# 💡 gcloud CLI = Android開発でいう adb のようなコマンドラインツール
#    Google Cloudのサービスを操作するために必要
brew install --cask google-cloud-sdk

# ───────────────────────────────────────────────────────────────
# 🔐 Googleアカウントでログイン
# ───────────────────────────────────────────────────────────────
# ブラウザが開くので、Googleアカウントでログイン
gcloud auth login

# ───────────────────────────────────────────────────────────────
# 📁 プロジェクト作成・選択
# ───────────────────────────────────────────────────────────────
# 💡 プロジェクト = Firebaseプロジェクトと同じ概念
#    リソース（サーバー、DB等）をグループ化する単位
#
# 新規プロジェクト作成
gcloud projects create cleaning-report-api --name="Cleaning Report API"

# 使用するプロジェクトを設定（以降のコマンドは全てこのプロジェクトに対して実行）
gcloud config set project cleaning-report-api

# ───────────────────────────────────────────────────────────────
# 🔧 必要なAPIを有効化
# ───────────────────────────────────────────────────────────────
# 💡 APIを有効化 = Firebaseで各サービスを有効化するのと同じ
#    使いたいサービスは明示的に有効化が必要

# Cloud Run API（サーバー実行環境）
gcloud services enable run.googleapis.com

# Artifact Registry API（Dockerイメージ保存場所）
gcloud services enable artifactregistry.googleapis.com
```

#### 12-2. Artifact Registry設定

```bash
# ───────────────────────────────────────────────────────────────
# 📦 Dockerイメージ保存場所の作成
# ───────────────────────────────────────────────────────────────
# 💡 Artifact Registry = Google Playストアのようなもの
#    ただしAPKではなくDockerイメージを保存する場所
#
# --repository-format=docker : Docker形式
# --location=asia-northeast1 : 東京リージョン（日本から近い）
gcloud artifacts repositories create cleaning-report \
    --repository-format=docker \
    --location=asia-northeast1 \
    --description="Cleaning Report Docker images"

# ───────────────────────────────────────────────────────────────
# 🔐 Docker認証設定
# ───────────────────────────────────────────────────────────────
# DockerコマンドがArtifact Registryにプッシュできるよう認証設定
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
```

#### 12-3. イメージをプッシュ

```bash
cd /Users/kuwa/Develop/studio/cleaning-report/server

# ───────────────────────────────────────────────────────────────
# 🏷️ イメージにタグを付ける
# ───────────────────────────────────────────────────────────────
# 💡 タグ = イメージの保存先アドレス
#    形式: [リージョン]-docker.pkg.dev/[プロジェクトID]/[リポジトリ名]/[イメージ名]:[バージョン]
#
#    Android的に例えると:
#    applicationId = "com.cleaning.server"
#    versionName = "latest"
docker tag cleaning-report-api \
    asia-northeast1-docker.pkg.dev/cleaning-report-api/cleaning-report/api:latest

# ───────────────────────────────────────────────────────────────
# ⬆️ イメージをプッシュ
# ───────────────────────────────────────────────────────────────
# 💡 Google PlayにAPKをアップロードするのと同じ
docker push asia-northeast1-docker.pkg.dev/cleaning-report-api/cleaning-report/api:latest
```

#### 12-4. Cloud Runにデプロイ

```bash
# ───────────────────────────────────────────────────────────────
# 🚀 Cloud Runにデプロイ
# ───────────────────────────────────────────────────────────────
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

**各オプションの詳細解説**:

| オプション | 値 | 説明 |
|:---|:---|:---|
| `--image` | `asia-...` | 使用するDockerイメージのアドレス |
| `--platform` | `managed` | フルマネージド版（Googleが全て管理） |
| `--region` | `asia-northeast1` | 東京リージョン（レイテンシ最小） |
| `--allow-unauthenticated` | - | 認証なしでアクセス可能（公開API用） |
| `--memory` | `256Mi` | 使用メモリ上限（無料枠: 月2GB-秒） |
| `--cpu` | `1` | 使用CPU数（無料枠: 月180,000 vCPU-秒） |
| `--min-instances` | `0` | 最小インスタンス数（**0=コールドスタート許容**） |
| `--max-instances` | `1` | 最大インスタンス数（スケール上限） |

**💡 コールドスタートとは？**

```
┌───────────────────────────────────────────────────────────────┐
│  🧊 コールドスタート（Cold Start）                              │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  min-instances = 0 の場合:                                      │
│                                                                 │
│  [リクエストなし] → インスタンスなし（課金なし）                │
│                           ↓                                      │
│  [リクエスト来た!] → インスタンス起動（10-30秒かかる）          │
│                           ↓                                      │
│  [起動完了] → レスポンス返却                                    │
│                                                                 │
│  ⚠️ 初回アクセスは10-30秒待たされる（無料枠運用のトレードオフ） │
│                                                                 │
│  min-instances = 1 の場合:                                      │
│  常に1台待機 → 即座にレスポンス（ただし常時課金）               │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

**💰 無料枠について**:

| リソース | 無料枠（月あたり） | 今回の設定で |
|:---|:---|:---|
| CPU | 180,000 vCPU-秒 | 1 CPU × 最大1インスタンス |
| メモリ | 360,000 GB-秒 | 256MB × 最大1インスタンス |
| リクエスト | 200万リクエスト | 余裕あり |
| ネットワーク | 1GB送信/月 | 余裕あり |

> 💡 個人プロジェクトで `min-instances=0`, `max-instances=1` なら
> ほぼ確実に無料枠内に収まります。

#### 12-5. デプロイ確認

```bash
# ───────────────────────────────────────────────────────────────
# 🔗 デプロイされたURLを取得
# ───────────────────────────────────────────────────────────────
# Cloud Runは自動でHTTPS URLを発行してくれます
gcloud run services describe cleaning-report-api \
    --platform managed \
    --region asia-northeast1 \
    --format 'value(status.url)'

# 出力例: https://cleaning-report-api-abcdef123-an.a.run.app

# ───────────────────────────────────────────────────────────────
# ✅ 動作確認
# ───────────────────────────────────────────────────────────────
# 💡 初回アクセスはコールドスタートで10-30秒かかる可能性あり
curl https://cleaning-report-api-xxxxx-an.a.run.app/health

# 期待レスポンス:
# { "status": "ok", "timestamp": 1736693456789 }
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

**A**: Docker Desktopのメモリ制限を増やす（4GB推奨）。

### Q: Docker buildで "operation not permitted" エラー

**A**: macOSの「フルディスクアクセス」権限が必要です。
1. システム設定 → プライバシーとセキュリティ → フルディスクアクセス
2. Docker Desktop をオンにする
3. Docker Desktop を再起動

### Q: Docker buildで "no match for platform in manifest" エラー

**A**: Apple Silicon (M1/M2/M3) を使用している場合、Alpine版などの一部のイメージが対応していないことがあります。
`eclipse-temurin:17-jre-alpine` の代わりに `eclipse-temurin:17-jre` を使用してください。

### Q: Docker buildで Gradle バージョンエラー

**A**: Ktorプラグイン 3.3.x は Gradle 8.11以上を要求します。
Dockerfileのビルドステージで `gradle:8.12-jdk17` などの最新イメージを使用してください。

### Q: docker run で "address already in use" エラー

**A**: ポート 8080 が既に他のプロセスで使用されています。
1. `lsof -i :8080` でプロセスID(PID)を確認
2. `kill -9 <PID>` で終了させる
3. または `docker run -p 8081:8080 ...` のようにホスト側のポートを変えて実行する

### Q: `FAILED_PRECONDITION: Billing account ... is not found` エラー

**A**: Google Cloudプロジェクトに請求先アカウントが紐付いていません。
1. [Google Cloud コンソール（お支払い）](https://console.cloud.google.com/billing/projects)にアクセス
2. 対象プロジェクトの「お支払いを変更」から請求先アカウントをリンクする
※ 無料枠内での利用であっても、API有効化のためにこの設定は必須です。

### Q: Cloud Runデプロイ時に "must support amd64/linux" エラー

**A**: Apple Silicon Mac (ARM64) でビルドしたイメージがCloud Run (AMD64) と互換性がないために発生します。
ビルド時に `--platform linux/amd64` を指定してください：
`docker build --platform linux/amd64 -t cleaning-report-api .`

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
