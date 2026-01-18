# Phase 3.1: Ktorセットアップ 理解度チェックリスト

Phase 3.1（Ktorプロジェクトセットアップ）に関する本質的な理解を確認するための問題集です。

---

## 📚 セクション1: 基礎理解（4択問題）

### Q1. Ktorの役割について正しいのはどれ？

- A) データベースを管理するORM
- B) HTTPリクエストを受けてレスポンスを返すWebフレームワーク
- C) UIを構築するフレームワーク
- D) モバイルアプリのテストフレームワーク

<details>
<summary>答えを見る</summary>

**正解: B**

Ktorは「HTTPリクエストを受けてレスポンスを返す」ことを中心としたWebフレームワークです。

```
Android App → HTTP Request → Ktor Server → HTTP Response → Android App
```

- データベース管理はExposed（ORM）の役割
- UIはFlutter/Composeの役割
- テストはKtor Test Moduleなど別のツールを使用

</details>

---

### Q2. `embeddedServer()` の `host = "0.0.0.0"` について正しいのはどれ？

- A) ローカル開発専用の設定
- B) 外部からのアクセスを拒否する設定
- C) すべてのネットワークインターフェースで待ち受ける設定（Cloud Run必須）
- D) IPv6のみを有効化する設定

<details>
<summary>答えを見る</summary>

**正解: C**

`host = "0.0.0.0"` は「すべてのネットワークインターフェースで待ち受ける」という意味です。

| 設定 | 意味 | 用途 |
|:---|:---|:---|
| `0.0.0.0` | すべてのインターフェース | Cloud Run/Docker必須 |
| `127.0.0.1` (localhost) | ローカルのみ | ローカル開発のみOK |

**Cloud Runでは外部からアクセスされるため `0.0.0.0` が必須です。**

</details>

---

### Q3. Cloud Runが `PORT` 環境変数を設定する理由は？

```kotlin
val port = System.getenv("PORT")?.toInt() ?: 8080
```

- A) セキュリティを高めるため
- B) Cloud Runが動的にポート番号を決めるため、ハードコード禁止
- C) コンテナを複数起動する際の識別用
- D) デバッグを容易にするため

<details>
<summary>答えを見る</summary>

**正解: B**

Cloud Runはコンテナ起動時にポート番号を動的に決めます。そのため：

- ❌ `port = 8080` とハードコードしてはいけない
- ✅ `System.getenv("PORT")` で環境変数から取得する必要がある
- `?: 8080` はローカル開発用のデフォルト値

**Cloud Runの仕様に従わないとコンテナが起動してもリクエストを受け付けられません。**

</details>

---

### Q4. Ktorのプラグイン（Plugin）について正しいのはどれ？

- A) 必要な機能を後から追加していく仕組み（Androidのライブラリ依存に近い）
- B) プロジェクト作成時に全て自動でインストールされる
- C) データベースへの接続機能
- D) UIコンポーネントのライブラリ

<details>
<summary>答えを見る</summary>

**正解: A**

Ktorのプラグインは「必要な機能だけを追加していく」設計思想です。

```kotlin
fun Application.module() {
    install(ContentNegotiation) { json() }  // JSONサポート追加
    install(Authentication) { ... }          // 認証機能追加
    install(CORS) { ... }                    // CORS設定追加
}
```

**Android的に言うと:**
- `build.gradle.kts` に `implementation(...)` を追加するのに似ている
- 必要な機能を選んで追加する

</details>

---

## 📚 セクション2: 実装パターン選択問題

### Q5. ヘルスチェックエンドポイントの実装として正しいのはどれ？

**A)**
```kotlin
get("/health") {
    call.respondText("OK")
}
```

**B)**
```kotlin
post("/health") {
    call.respond(HttpStatusCode.OK, HealthResponse("ok", System.currentTimeMillis()))
}
```

**C)**
```kotlin
get("/health") {
    call.respond(HttpStatusCode.OK, HealthResponse("ok", System.currentTimeMillis()))
}
```

**D)**
```kotlin
get("/health") {
    println("Health check")
}
```

<details>
<summary>答えを見る</summary>

**正解: C**

ヘルスチェックは：
- **GETメソッド**で実装（読み取り専用）
- **HTTPステータスコード**を明示的に返す
- **構造化されたレスポンス**（JSON）を返す

```kotlin
get("/health") {
    call.respond(
        HttpStatusCode.OK,
        HealthResponse(
            status = "ok",
            timestamp = System.currentTimeMillis()
        )
    )
}
```

POSTは不適切（データ作成の意味になる）、printlnだけではクライアントにレスポンスが返らない。

</details>

---

### Q6. `@Serializable` アノテーションの役割は？

```kotlin
@Serializable
data class HealthResponse(
    val status: String,
    val timestamp: Long
)
```

- A) データベースのテーブル定義
- B) Kotlinオブジェクト ↔ JSON の自動変換を有効化（Moshiの@JsonClassに相当）
- C) スレッドセーフなクラスにする
- D) Android側でのみ使用可能

<details>
<summary>答えを見る</summary>

**正解: B**

`@Serializable` は `kotlinx.serialization` のアノテーションで、自動的にJSON変換が可能になります。

**Android（Moshi）との比較:**
```kotlin
// Android
@JsonClass(generateAdapter = true)
data class User(val name: String)

// Ktor
@Serializable
data class User(val name: String)
```

どちらも「コンパイル時にシリアライザーを自動生成する」という点で同じ仕組みです。

</details>

---

### Q7. ContentNegotiation プラグインの役割として正しいのはどれ？

```kotlin
install(ContentNegotiation) {
    json(Json {
        prettyPrint = true
        isLenient = true
    })
}
```

- A) データベースとの通信形式を決める
- B) クライアントとサーバー間でどの形式（JSON等）でデータをやり取りするかを設定
- C) HTTPメソッド（GET/POST等）を定義する
- D) CORSポリシーを設定する

<details>
<summary>答えを見る</summary>

**正解: B**

ContentNegotiation（コンテンツネゴシエーション）は、クライアントとサーバーの間でデータのやり取り形式を決める仕組みです。

```
リクエスト:   Content-Type: application/json
レスポンス:  Content-Type: application/json
```

**Android的に言うと:**
- `Retrofit.Builder().addConverterFactory(MoshiConverterFactory.create())` に相当
- JSONでデータをやり取りする設定

</details>

---

## 📚 セクション3: Docker/Cloud Run の理解

### Q8. Dockerfileの「マルチステージビルド」の利点は？

```dockerfile
FROM gradle:8.12-jdk17 AS build
# ... ビルド処理 ...

FROM eclipse-temurin:17-jre
# ... 実行用 ...
```

- A) 複数のプログラミング言語を同時に使える
- B) 最終イメージサイズを小さくできる（ビルド用ツールを含めない）
- C) ビルド時間を短縮できる
- D) セキュリティが自動的に強化される

<details>
<summary>答えを見る</summary>

**正解: B**

マルチステージビルドでは：

```
[ステージ1: build]  (約1GB)
  ソースコード + Gradle → Fat JAR生成

[ステージ2: 実行用]  (約200MB)
  Fat JARのみをコピー → 最終イメージ
```

**メリット:**
- ビルドツール（Gradle等）を最終イメージに含めない
- 実行に必要な最小限のファイルだけを含む
- デプロイ時のイメージサイズが小さくなり高速化

**Android的に言うと:**
- APKに不要なビルドツールを含めないのと同じ

</details>

---

### Q9. Apple Silicon Mac (M1/M2/M3) でDockerビルド時に `--platform linux/amd64` を指定する理由は？

```bash
docker build --platform linux/amd64 -t cleaning-report-api .
```

- A) ビルド速度を上げるため
- B) Cloud Runは AMD64アーキテクチャで動作するため、ARM64イメージでは動かない
- C) セキュリティを高めるため
- D) Macでのみ必要な設定

<details>
<summary>答えを見る</summary>

**正解: B**

**アーキテクチャの違い:**
- Apple Silicon Mac: ARM64アーキテクチャ
- Cloud Run: AMD64（x86_64）アーキテクチャ

`--platform linux/amd64` を指定しないと、Mac上でARM64用のイメージがビルドされ、Cloud Runでは動作しません。

**クロスプラットフォームビルド:**
```bash
# ARM64の Mac で AMD64 用のイメージをビルド
docker build --platform linux/amd64 -t my-app .
```

</details>

---

### Q10. Fat JAR（buildFatJar）とは何か？

```kotlin
ktor {
    fatJar {
        archiveFileName.set("app.jar")
    }
}
```

- A) サイズの大きいJARファイルのこと
- B) すべての依存ライブラリを含む単一のJARファイル
- C) 圧縮されていないJARファイル
- D) デバッグ情報が含まれるJARファイル

<details>
<summary>答えを見る</summary>

**正解: B**

Fat JAR（またはUber JAR）は「すべての依存ライブラリを含む単一のJARファイル」です。

**通常のJAR:**
```
app.jar  (10MB)
libs/
  ├── ktor-core.jar
  ├── exposed.jar
  └── ...
```

**Fat JAR:**
```
app.jar  (50MB) ← すべて含まれている
```

**メリット:**
- `java -jar app.jar` だけで実行可能
- ライブラリの依存関係を気にしなくて良い
- Dockerイメージに含めるファイルが1つだけ

**Android的に言うと:**
- APKにすべての依存ライブラリが含まれているのと同じ

</details>

---

### Q11. `gcloud services enable run.googleapis.com` の意味は？

- A) Cloud Runのバージョンを最新化する
- B) Cloud Run APIを有効化する（Firebaseで各サービスを有効化するのと同じ）
- C) Cloud Runのインスタンスを起動する
- D) Cloud Runのログを有効化する

<details>
<summary>答えを見る</summary>

**正解: B**

Google Cloudでは使いたいAPIを明示的に有効化する必要があります。

**Android/Firebaseでの類似概念:**
```
Firebase Console → Firestore を有効化
Firebase Console → Functions を有効化

Google Cloud → Cloud Run API を有効化
Google Cloud → Artifact Registry API を有効化
```

有効化しないとそのサービスを使えません（エラーになる）。

</details>

---

### Q12. ルーティングの `get("/health")` と `post("/api/reports")` の違いは？

```kotlin
routing {
    get("/health") { ... }
    post("/api/reports") { ... }
}
```

- A) getは読み取り専用、postはデータ作成
- B) getは高速、postは低速
- C) getは認証不要、postは認証必須
- D) まったく同じ機能（記述方法の違いだけ）

<details>
<summary>答えを見る</summary>

**正解: A**

HTTPメソッドには意味があります：

| メソッド | 用途 | 例 |
|:---|:---|:---|
| GET | データを取得（読み取り専用） | `/api/reports?month=2026-01` |
| POST | データを作成 | `/api/reports` でレポート作成 |
| PUT | データを更新 | `/api/reports/{id}` で更新 |
| DELETE | データを削除 | `/api/reports/{id}` で削除 |

**Androidで例えると:**
```kotlin
@GET("api/reports")
suspend fun getReports(): List<Report>

@POST("api/reports")
suspend fun createReport(@Body report: Report): Report
```

</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 完全に理解している |
| 9-10問 | 👍 概ね理解している。復習推奨箇所あり |
| 6-8問 | 📖 基礎は理解しているが、深い理解が必要 |
| 5問以下 | 📚 Phase3.1_Ktorセットアップ.md を再度読み込むことを推奨 |

---

## 📝 復習用キーワード

- **Ktor**: Kotlin製のWebフレームワーク
- **embeddedServer**: Ktorサーバーの起動
- **host = "0.0.0.0"**: すべてのインターフェースで待ち受け（Cloud Run必須）
- **PORT環境変数**: Cloud Runが動的に設定するポート番号
- **プラグイン（Plugin）**: 必要な機能を追加する仕組み
- **routing**: URLと処理のマッピング
- **ContentNegotiation**: JSON等のやり取り形式の設定
- **@Serializable**: JSON自動変換
- **Fat JAR**: すべての依存を含む単一JAR
- **マルチステージビルド**: Dockerイメージサイズの最適化
- **--platform linux/amd64**: Apple Silicon用の設定
- **gcloud**: Google Cloud CLI
