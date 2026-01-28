# Ktor 動作原理 理解度チェックリスト

Ktor フレームワークの**「なぜ動くか」**を理解し、コードを読んだときに処理の流れが追えるようになることを目指します。

---

## 📚 セクション1: アプリケーション起動

### Q1. `Application.module()` 拡張関数の役割として正しいのは？

```kotlin
fun Application.module() {
    configureCors()
    configureKoin()
    configureAuthentication()
    configureSerialization()
    configureRouting()
}
```

- A) データベースのテーブルを作成する関数
- B) アプリケーション起動時に呼ばれ、プラグインやルーティングを構成する初期化関数
- C) HTTPリクエストを受け取るたびに呼ばれるハンドラ
- D) テスト専用のセットアップ関数

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
`Application.module()` は Ktor アプリの**エントリポイント**です。

**Androidとの比較:**
```kotlin
// Android
class MyApplication : Application() {
    override fun onCreate() {
        // DIの初期化、ログ設定など
    }
}

// Ktor
fun Application.module() {
    // プラグインの install、ルーティングの設定など
}
```

**呼び出しタイミング:**
- サーバー起動時に **1回だけ** 呼ばれる
- リクエストごとに呼ばれるわけではない

**処理順序が重要:**
認証（`configureAuthentication`）は、ルーティング（`configureRouting`）より先に設定しないと認証が効かない

</details>

---

### Q2. `install()` 関数は何をしている？

```kotlin
fun Application.configureSerialization() {
    install(ContentNegotiation) {
        json(Json {
            prettyPrint = true
            ignoreUnknownKeys = true
        })
    }
}
```

- A) npm パッケージをインストールする
- B) Gradle の依存関係を追加する
- C) Ktor にプラグイン（機能拡張）を追加・設定する
- D) Docker イメージをダウンロードする

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
`install()` は Ktor の**プラグインシステム**です。

**Ktorはマイクロフレームワーク:**
- 最初は何もできないシンプルな状態
- 必要な機能を `install()` で後付けする

**代表的なプラグイン:**
| プラグイン | 役割 |
|---|---|
| `ContentNegotiation` | JSON ↔ Kotlin オブジェクト変換 |
| `Authentication` | JWT/Basic 認証 |
| `CORS` | クロスオリジン許可 |
| `StatusPages` | エラーハンドリング |
| `CallLogging` | リクエストログ |

**Androidとの比較:**
```kotlin
// Android: Retrofit の設定
Retrofit.Builder()
    .addConverterFactory(MoshiConverterFactory.create())  // ← これに相当
    .build()

// Ktor: ContentNegotiation の設定
install(ContentNegotiation) {
    json()  // ← JSON 変換を有効化
}
```

</details>

---

### Q3. `routing { }` ブロックの中で何を定義する？

```kotlin
fun Application.configureRouting() {
    routing {
        get("/health") {
            call.respondText("OK")
        }
        reportRoutes()  // 別ファイルのルート定義
    }
}
```

- A) データベースのスキーマ
- B) 環境変数
- C) URLパスとHTTPメソッドに対応するハンドラ（処理）
- D) フロントエンドのHTML

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
`routing` は**URLとハンドラのマッピング**を定義します。

**Androidとの比較（Jetpack Navigation）:**
```kotlin
// Android Navigation
NavHost(navController, startDestination = "home") {
    composable("home") { HomeScreen() }
    composable("detail/{id}") { DetailScreen() }
}

// Ktor Routing
routing {
    get("/") { call.respondText("Home") }
    get("/reports/{id}") { /* レポート詳細 */ }
}
```

**ルート定義のパターン:**
```kotlin
routing {
    // 基本
    get("/path") { /* GET リクエスト */ }
    post("/path") { /* POST リクエスト */ }
    
    // パスパラメータ
    get("/reports/{id}") {
        val id = call.parameters["id"]
    }
    
    // グループ化
    route("/api/v1") {
        get("/users") { /* GET /api/v1/users */ }
        get("/reports") { /* GET /api/v1/reports */ }
    }
}
```

</details>

---

## 📚 セクション2: リクエスト処理の流れ

### Q4. リクエストが来たときの処理順序として正しいのは？

```
クライアント → [?] → [?] → [?] → レスポンス
```

- A) Routing → Plugin → Handler
- B) Plugin（認証、ログ等の前処理）→ Routing（パスマッチ）→ Handler（ビジネスロジック）
- C) Handler → Plugin → Routing
- D) 並列に全て同時実行

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
Ktor はパイプラインアーキテクチャで、リクエストを段階的に処理します。

```
リクエスト
    ↓
[Plugin: CORS] ← オリジンチェック
    ↓
[Plugin: Authentication] ← JWT検証
    ↓
[Plugin: CallLogging] ← ログ出力
    ↓
[Routing] ← パスマッチング
    ↓
[Handler] ← ビジネスロジック（あなたのコード）
    ↓
レスポンス
```

**Androidとの比較（OkHttp Interceptor）:**
```kotlin
// OkHttp
OkHttpClient.Builder()
    .addInterceptor(LoggingInterceptor())      // ① ログ
    .addInterceptor(AuthInterceptor(token))    // ② 認証ヘッダー追加
    .build()

// Ktor プラグインも同じ発想
install(CallLogging)       // ① ログ
install(Authentication)    // ② 認証
```

</details>

---

### Q5. `call` オブジェクトの役割は？

```kotlin
get("/reports/{id}") {
    val id = call.parameters["id"]
    val report = repository.findById(id)
    call.respond(report)
}
```

- A) データベース接続オブジェクト
- B) ログ出力用のオブジェクト
- C) 設定ファイルを読み込むオブジェクト
- D) 現在のHTTPリクエスト/レスポンスを表すコンテキストオブジェクト

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**
`call` は `ApplicationCall` の略で、**1つのHTTPリクエストに対するすべての情報**を持っています。

**`call` でできること:**

| メソッド/プロパティ | 用途 |
|---|---|
| `call.parameters["id"]` | パスパラメータ取得 |
| `call.request.queryParameters["q"]` | クエリパラメータ取得 |
| `call.receive<MyData>()` | リクエストボディをデシリアライズ |
| `call.respond(data)` | レスポンスを返す |
| `call.respondText("OK")` | テキストレスポンス |
| `call.principal<JWTPrincipal>()` | 認証情報取得 |
| `call.request.headers["Authorization"]` | ヘッダー取得 |

**Androidとの比較:**
```kotlin
// Retrofit のリクエスト情報 + レスポンス送信 を1つにしたようなもの
interface ReportApi {
    @GET("/reports/{id}")
    suspend fun getReport(@Path("id") id: String): Report
    //                     ↑ これが call.parameters
    //                                          ↑ これが call.respond
}
```

</details>

---

### Q6. `call.receive<T>()` と `call.respond()` の違いは？

```kotlin
post("/reports") {
    val request = call.receive<CreateReportRequest>()  // ①
    val report = repository.create(request)
    call.respond(HttpStatusCode.Created, report)       // ②
}
```

- A) ① はリクエストボディを Kotlin オブジェクトに変換、② は Kotlin オブジェクトをレスポンスとして送信
- B) どちらも同じ機能で、名前が違うだけ
- C) ① はヘッダーを読み込み、② はヘッダーを送信
- D) ① は同期処理、② は非同期処理

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**

```kotlin
post("/reports") {
    // リクエストボディ (JSON) → Kotlin オブジェクト
    val request = call.receive<CreateReportRequest>()
    
    // ビジネスロジック
    val report = repository.create(request)
    
    // Kotlin オブジェクト → レスポンスボディ (JSON)
    call.respond(HttpStatusCode.Created, report)
}
```

**裏で何が起きている？**
`ContentNegotiation` プラグインが JSON ↔ Kotlin 変換を担当

```
リクエスト: {"title": "Report", "user_id": "abc"}
     ↓ call.receive<T>()
     ↓ ContentNegotiation が JSON をパース
Kotlin: CreateReportRequest(title = "Report", userId = "abc")

     ↓ ビジネスロジック

Kotlin: Report(id = "123", title = "Report", ...)
     ↓ call.respond()
     ↓ ContentNegotiation が JSON に変換
レスポンス: {"id": "123", "title": "Report", ...}
```

</details>

---

## 📚 セクション3: プラグイン詳細

### Q7. `ContentNegotiation` プラグインで `ignoreUnknownKeys = true` を設定する理由は？

```kotlin
install(ContentNegotiation) {
    json(Json {
        ignoreUnknownKeys = true
    })
}
```

- A) パフォーマンスを向上させるため
- B) セキュリティを強化するため
- C) クライアントが送ってきた余分なフィールドを無視し、デシリアライズエラーを防ぐため
- D) レスポンスサイズを小さくするため

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
APIのバージョン違いや、クライアント側の追加フィールドに対応するための設定です。

```kotlin
// サーバー側の想定
data class CreateReportRequest(
    val title: String,
    val userId: String
)

// クライアントが送ってきた JSON
{
    "title": "Report",
    "userId": "abc",
    "extraField": "something"  // ← サーバーが知らないフィールド
}
```

**ignoreUnknownKeys = false の場合:**
→ `SerializationException` でエラー

**ignoreUnknownKeys = true の場合:**
→ `extraField` を無視して正常にパース

**他の便利なオプション:**
| オプション | 用途 |
|---|---|
| `prettyPrint = true` | 整形して出力（開発時） |
| `isLenient = true` | 緩いパース（引用符なし等を許容） |
| `coerceInputValues = true` | null を デフォルト値に置換 |

</details>

---

### Q8. 認証が必要なルートと不要なルートを分ける方法は？

```kotlin
routing {
    get("/health") { call.respondText("OK") }  // 認証不要
    
    authenticate("jwt") {
        get("/reports") { /* 認証必要 */ }
        post("/reports") { /* 認証必要 */ }
    }
}
```

- A) `authenticate("jwt") { }` ブロック内のルートだけが認証を要求する
- B) 全てのルートが自動的に認証される
- C) `authenticate` は認証を無効化する
- D) 認証はルーティングと無関係

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
`authenticate("jwt") { }` ブロックで囲んだルートだけが認証を要求します。

```kotlin
routing {
    // 認証不要エリア
    get("/health") { ... }
    get("/public") { ... }
    
    // 認証必要エリア
    authenticate("jwt") {
        get("/reports") {
            // ここでは call.principal が使える
            val principal = call.principal<JWTPrincipal>()
            val userId = principal?.payload?.getClaim("sub")?.asString()
        }
        post("/reports") { ... }
    }
}
```

**認証失敗時の動作:**
`authenticate` ブロック外からアクセス → 401 Unauthorized を返す

**Androidとの比較:**
Navigation の `NavGraph` でログイン画面とメイン画面を分けるのに似ている

</details>

---

## 📚 セクション4: DI (Koin) との連携

### Q9. Ktor のルートハンドラで Repository を取得する方法として正しいのは？

```kotlin
// Koin モジュール定義
val appModule = module {
    single<ReportRepository> { ReportRepositoryImpl() }
}

// ルートでの使用
get("/reports") {
    val repository: ReportRepository = ???
    val reports = repository.findAll()
    call.respond(reports)
}
```

- A) `val repository = ReportRepositoryImpl()` ← 直接インスタンス化
- B) `val repository = call.repository` ← call から取得
- C) `val repository = Application.get()` ← Application から取得
- D) `val repository: ReportRepository by inject()` ← Koin のDI

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**
Koin の `inject()` を使うと、DIコンテナから依存を取得できます。

```kotlin
// 方法1: by inject()（推奨）
get("/reports") {
    val repository: ReportRepository by inject()
    val reports = repository.findAll()
    call.respond(reports)
}

// 方法2: get()（直接取得）
get("/reports") {
    val repository = get<ReportRepository>()
    val reports = repository.findAll()
    call.respond(reports)
}
```

**なぜ直接インスタンス化しない？**
```kotlin
// ❌ アンチパターン
val repository = ReportRepositoryImpl()  // テスト時にモックに差し替えられない

// ✅ DIを使う
val repository: ReportRepository by inject()  // テスト時は別の実装に差し替え可能
```

**Androidとの比較:**
```kotlin
// Android (Hilt)
@Inject lateinit var repository: ReportRepository

// Ktor (Koin)
val repository: ReportRepository by inject()
```

</details>

---

### Q10. `single` と `factory` の違いは？

```kotlin
val appModule = module {
    single<ReportRepository> { ReportRepositoryImpl() }  // ①
    factory<SomeService> { SomeServiceImpl() }           // ②
}
```

- A) `single` は毎回新しいインスタンス、`factory` は使い回し
- B) `single` は1つのインスタンスを使い回し、`factory` は毎回新しいインスタンス
- C) どちらも同じで、名前が違うだけ
- D) `single` はプリミティブ型用、`factory` はオブジェクト用

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**

| スコープ | 動作 | 使用例 |
|---|---|---|
| `single` | Singleton（1つを共有） | Repository, DataSource |
| `factory` | 毎回新規作成 | リクエスト固有のオブジェクト |

```kotlin
val appModule = module {
    // Repository: ステートレスなので1つで十分
    single<ReportRepository> { ReportRepositoryImpl(get()) }
    
    // UseCase: リクエストごとに新しいインスタンスが必要な場合
    factory { CreateReportUseCase(get()) }
}
```

**Androidとの比較:**
- `single` ≒ Hilt の `@Singleton`
- `factory` ≒ Hilt の デフォルト（スコープなし）

</details>

---

## 📚 セクション5: エラーハンドリング

### Q11. グローバルなエラーハンドリングを設定するプラグインは？

- A) `ContentNegotiation`
- B) `CallLogging`
- C) `StatusPages`
- D) `Routing`

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
`StatusPages` プラグインで例外をキャッチしてエラーレスポンスを返せます。

```kotlin
install(StatusPages) {
    exception<NotFoundException> { call, cause ->
        call.respond(HttpStatusCode.NotFound, ErrorResponse(cause.message))
    }
    exception<ValidationException> { call, cause ->
        call.respond(HttpStatusCode.BadRequest, ErrorResponse(cause.message))
    }
    exception<Throwable> { call, cause ->
        // 予期しないエラー
        call.application.log.error("Unhandled exception", cause)
        call.respond(
            HttpStatusCode.InternalServerError,
            ErrorResponse("Internal Server Error")
        )
    }
}
```

**なぜ重要？**
- ハンドラごとに try-catch を書かなくて済む
- エラーレスポンスのフォーマットを統一できる
- 本番環境でスタックトレースを隠せる

</details>

---

### Q12. 認証失敗時のレスポンスをカスタマイズする方法は？

```kotlin
install(Authentication) {
    jwt("jwt") {
        verifier(jwkProvider)
        validate { credential -> /* ... */ }
        challenge { defaultScheme, realm ->
            // ① ここでカスタムレスポンスを返す
        }
    }
}
```

- A) `validate` ブロックで `null` を返す
- B) `challenge` ブロックで `call.respond()` を呼ぶ
- C) `StatusPages` でのみ可能
- D) カスタマイズはできない

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
`challenge` ブロックは**認証失敗時**に呼ばれ、カスタムレスポンスを返せます。

```kotlin
install(Authentication) {
    jwt("jwt") {
        verifier(jwkProvider)
        validate { credential ->
            // JWT の検証ロジック
            if (credential.payload.getClaim("sub") != null) {
                JWTPrincipal(credential.payload)
            } else {
                null  // 認証失敗
            }
        }
        challenge { defaultScheme, realm ->
            // カスタムエラーレスポンス
            call.respond(
                HttpStatusCode.Unauthorized,
                mapOf(
                    "error" to "invalid_token",
                    "message" to "Token is missing or invalid"
                )
            )
        }
    }
}
```

**デフォルトの動作:**
`challenge` を書かないと、シンプルな 401 レスポンスが返る

</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 Ktor の仕組みを十分理解している |
| 8-10問 | 👍 基礎はOK。リクエスト処理の流れを復習 |
| 5-7問 | 📖 Plugin と Routing の関係を復習 |
| 4問以下 | 📚 サンプルコードを動かしながら基礎から |

---

## 📝 復習用キーワード

- **Application.module()**: アプリ起動時の初期化関数
- **install()**: プラグイン（機能）の追加
- **routing**: URL とハンドラのマッピング
- **call**: リクエスト/レスポンスのコンテキスト
- **receive / respond**: デシリアライズ / シリアライズ
- **ContentNegotiation**: JSON 変換プラグイン
- **authenticate**: 認証が必要なルートを囲むブロック
- **inject() / get()**: Koin からの依存取得
- **single / factory**: Singleton か 毎回生成 か
- **StatusPages**: グローバルエラーハンドリング
- **challenge**: 認証失敗時のカスタムレスポンス
