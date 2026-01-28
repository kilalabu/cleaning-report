# HTTP / REST 深掘り 理解度チェックリスト

Legacy APIのメンテナンス時に必要となる、HTTPプロトコルとRESTful API設計の深い理解を目指します。
「なぜこのステータスコードなのか」「なぜこのヘッダーが必要なのか」を説明できるようになることがゴールです。

---

## 📚 セクション1: HTTPメソッドの意味論

### Q1. HTTPメソッドの「冪等性（Idempotence）」について正しいのは？

- A) 冪等なメソッドは、何回実行しても結果が同じになる
- B) POST は冪等である
- C) GET は冪等ではない
- D) 冪等性はパフォーマンスに関する概念である

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
**冪等性**とは「同じリクエストを何回送っても、サーバーの状態が変わらない」という性質です。

| メソッド | 冪等? | 理由 |
|---|:---:|---|
| **GET** | ✅ | リソースを取得するだけ、状態を変えない |
| **PUT** | ✅ | 同じデータで上書きしても結果は同じ |
| **DELETE** | ✅ | 既に削除されていれば何も起きない |
| **POST** | ❌ | 毎回新しいリソースが作成される可能性 |
| **PATCH** | ❌ | 相対的な変更の場合、結果が変わりうる |

**なぜ重要？**
- ネットワークエラー時のリトライ判断に使う
- PUT/DELETE は安全にリトライできる
- POST のリトライは重複作成のリスクあり

```kotlin
// Ktor でのリトライ時の判断例
if (method in setOf(HttpMethod.Get, HttpMethod.Put, HttpMethod.Delete)) {
    // リトライ可能
}
```

</details>

---

### Q2. PUT と PATCH の違いとして正しいのは？

```json
// 現在のリソース
{ "title": "Report A", "status": "DRAFT", "priority": "HIGH" }
```

- A) PUT も PATCH も部分更新に使う
- B) PUT はリソース全体を置換、PATCH は部分的な変更
- C) PATCH はリソース全体を置換、PUT は部分的な変更
- D) PUT と PATCH は全く同じ動作をする

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**

**PUT（全置換）:**
```http
PUT /reports/123
Content-Type: application/json

{ "title": "Report A Updated", "status": "SUBMITTED", "priority": "HIGH" }
```
→ 全フィールドを送る必要がある。送らないフィールドは消える可能性。

**PATCH（部分更新）:**
```http
PATCH /reports/123
Content-Type: application/json

{ "status": "SUBMITTED" }
```
→ 変更したいフィールドだけ送る。他は変わらない。

**gRPC との対比:**
gRPC（Protocol Buffers）では `FieldMask` を使って更新対象フィールドを指定：
```protobuf
message UpdateReportRequest {
    Report report = 1;
    google.protobuf.FieldMask update_mask = 2;
}
```

**実務での使い分け:**
- **PUT**: リソースの完全な上書き（設定ファイルの更新など）
- **PATCH**: 一部フィールドの更新（status だけ変更など）

</details>

---

### Q3. POST と PUT のリソース作成における違いは？

- A) POST でも PUT でもリソース作成に使える。違いはIDの決定権
- B) PUT はリソース作成には使えない
- C) POST はリソース作成には使えない
- D) POST と PUT は全く同じ目的に使う

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**

**POST でリソース作成（サーバーがIDを決定）:**
```http
POST /reports
Content-Type: application/json

{ "title": "New Report" }

# レスポンス
201 Created
Location: /reports/abc-123  ← サーバーが生成したID
```

**PUT でリソース作成（クライアントがIDを指定）:**
```http
PUT /reports/my-custom-id
Content-Type: application/json

{ "title": "New Report" }

# レスポンス
201 Created  ← 新規作成時
200 OK       ← 既存リソースの更新時
```

**使い分け:**
- **POST**: 通常のリソース作成（サーバーでUUID生成）
- **PUT**: クライアントがIDを持っている場合（分散システム、クライアント生成UUID）

</details>

---

## 📚 セクション2: HTTPステータスコード

### Q4. エラーレスポンスで 400 vs 422 の使い分けとして正しいのは？

- A) 400 はリクエストの構文エラー、422 はビジネスロジックエラー
- B) 400 と 422 は同じ意味で使い分け不要
- C) 422 はサーバーエラーを表す
- D) 400 は認証エラーを表す

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**

| コード | 意味 | 例 |
|---|---|---|
| **400 Bad Request** | リクエストの構文が不正 | JSONのパースエラー、必須パラメータ欠落 |
| **422 Unprocessable Entity** | 構文は正しいが、意味的に処理できない | 在庫が足りない、期間が矛盾 |

```kotlin
// Ktor でのエラーレスポンス例
post("/orders") {
    val request = try {
        call.receive<CreateOrderRequest>()
    } catch (e: ContentTransformationException) {
        call.respond(HttpStatusCode.BadRequest, ErrorResponse("Invalid JSON"))
        return@post
    }
    
    if (request.quantity > inventory.available) {
        // 構文は正しいが、ビジネスルール違反
        call.respond(HttpStatusCode.UnprocessableEntity, 
            ErrorResponse("Insufficient inventory"))
        return@post
    }
}
```

**使い分けの基準:**
- **400**: リクエストを見ただけで間違いがわかる（形式の問題）
- **422**: サーバー側の状態を確認しないとわからない（内容の問題）

</details>

---

### Q5. 404 Not Found と 410 Gone の違いは？

- A) 404 は一時的、410 は永続的にリソースが存在しない
- B) 404 と 410 は同じ意味
- C) 410 は認証エラーを表す
- D) 404 はサーバーエラーを表す

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**

| コード | 意味 | キャッシュ |
|---|---|---|
| **404 Not Found** | リソースが見つからない（存在しない or URLが間違い） | キャッシュ可能だが短期間 |
| **410 Gone** | リソースは恒久的に削除された | 長期間キャッシュ可能 |

**実務での使用例:**
```kotlin
// 論理削除されたリソースへのアクセス
get("/reports/{id}") {
    val report = reportRepository.findById(id)
    when {
        report == null -> call.respond(HttpStatusCode.NotFound)
        report.deletedAt != null -> call.respond(HttpStatusCode.Gone)
        else -> call.respond(HttpStatusCode.OK, report)
    }
}
```

**410 のメリット:**
- 検索エンジンに「もう存在しない」と明確に伝える
- クライアントがリトライを避けられる
- 削除証跡として使える

</details>

---

### Q6. 500番台エラーの使い分けとして正しいのは？

- A) 500, 502, 503, 504 は全て同じ意味
- B) 500 は汎用エラー、502/503/504 はプロキシ・負荷関連のエラー
- C) 500番台はクライアント側のエラー
- D) 503 はリソースが見つからないことを表す

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**

| コード | 意味 | よくある原因 |
|---|---|---|
| **500 Internal Server Error** | サーバー内部エラー（汎用） | 未ハンドルの例外、バグ |
| **502 Bad Gateway** | 上流サーバーから不正なレスポンス | マイクロサービスのエラー |
| **503 Service Unavailable** | 一時的に利用不可 | メンテナンス、過負荷 |
| **504 Gateway Timeout** | 上流サーバーがタイムアウト | DB接続タイムアウト |

**Cloud Run / ロードバランサー環境での例:**
```
クライアント → LB → Cloud Run → DB
                ↑
    ここで504が返る ← DBがタイムアウト（Cloud Runからは502として見える可能性も）
```

**503 の適切な使用:**
```http
503 Service Unavailable
Retry-After: 120  # 120秒後にリトライ推奨

# 計画メンテナンス時など
```

</details>

---

## 📚 セクション3: HTTPヘッダー

### Q7. Content-Type と Accept ヘッダーの違いは？

- A) どちらもリクエストボディの形式を指定する
- B) どちらもレスポンスボディの形式を指定する
- C) Content-Type はボディの形式、Accept は期待するレスポンス形式
- D) これらのヘッダーは現在使われていない

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**

**Content-Type（現在のボディの形式）:**
```http
POST /reports
Content-Type: application/json  ← 私が送るデータはJSON

{ "title": "Report" }
```

**Accept（期待するレスポンス形式）:**
```http
GET /reports/123
Accept: application/json  ← レスポンスはJSONで欲しい
```

**コンテンツネゴシエーション:**
```http
GET /reports/123
Accept: application/pdf, application/json;q=0.9
# PDFを優先、なければJSONでもOK（q=品質係数、優先度）
```

**Ktor での実装:**
```kotlin
get("/reports/{id}") {
    val accept = call.request.accept()
    when {
        accept?.contains("application/pdf") == true -> {
            call.respondBytes(pdfBytes, ContentType.Application.Pdf)
        }
        else -> {
            call.respond(report)  // JSON
        }
    }
}
```

</details>

---

### Q8. Cache-Control ヘッダーの主要なディレクティブは？

```http
Cache-Control: private, max-age=3600, must-revalidate
```

- A) キャッシュ禁止を指定している
- B) 共有キャッシュ（CDN等）に保存可能
- C) 無期限でキャッシュ可能
- D) 1時間プライベートキャッシュ可、期限後は再検証必須

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**

| ディレクティブ | 意味 |
|---|---|
| **private** | ブラウザのみキャッシュ可（CDN不可） |
| **public** | CDN等の共有キャッシュにも保存可 |
| **max-age=N** | N秒間キャッシュ有効 |
| **no-cache** | キャッシュ保存OK、毎回サーバーに再検証 |
| **no-store** | キャッシュ禁止（機密データ用） |
| **must-revalidate** | 期限切れ後は必ず再検証 |

**ユースケース別の設定:**
```http
# 静的アセット（変更されにくい）
Cache-Control: public, max-age=31536000, immutable

# ユーザー固有のデータ
Cache-Control: private, max-age=60, must-revalidate

# 機密データ
Cache-Control: no-store

# 動的だがCDNでキャッシュしたい
Cache-Control: public, max-age=0, s-maxage=300
```

**Ktor での設定:**
```kotlin
get("/reports/{id}") {
    call.response.headers.append(
        HttpHeaders.CacheControl, 
        "private, max-age=300"
    )
    call.respond(report)
}
```

</details>

---

### Q9. ETag と Last-Modified を使った条件付きリクエストの目的は？

- A) 認証に使用する
- B) キャッシュ検証で不要なデータ転送を避ける
- C) リクエストの暗号化に使う
- D) レートリミットに使用する

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**

**ETag（Entity Tag）:**
リソースのバージョンを識別するハッシュ値

```http
# 最初のリクエスト
GET /reports/123
→ ETag: "abc123"
   { ... data ... }

# 2回目（キャッシュ検証）
GET /reports/123
If-None-Match: "abc123"

→ 304 Not Modified  # 変更なし、ボディなし
# または
→ 200 OK, ETag: "def456"  # 変更あり、新データ
```

**Last-Modified:**
```http
GET /reports/123
If-Modified-Since: Mon, 27 Jan 2026 00:00:00 GMT

→ 304 Not Modified  # 変更なし
```

**楽観的ロック（Optimistic Locking）での使用:**
```http
PUT /reports/123
If-Match: "abc123"  # このバージョンなら更新

→ 200 OK  # 成功
→ 412 Precondition Failed  # 誰かが先に更新した
```

**Ktor での実装:**
```kotlin
get("/reports/{id}") {
    val report = findReport(id)
    val etag = report.hashCode().toString()
    
    call.response.etag(etag)
    
    if (call.request.header(HttpHeaders.IfNoneMatch) == etag) {
        call.respond(HttpStatusCode.NotModified)
        return@get
    }
    call.respond(report)
}
```

</details>

---

## 📚 セクション4: RESTful設計原則

### Q10. RESTful API のリソース命名として推奨されるのは？

- A) `/getReport`, `/createReport`, `/updateReport`
- B) `/report/get`, `/report/create`, `/report/update`
- C) `/reports`, `/reports/{id}`, `/reports/{id}/comments`
- D) `/api?action=getReport&id=123`

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**

**REST の原則:**
- URLは「リソース（名詞）」を表す
- 操作は「HTTPメソッド（動詞）」で表す

| 操作 | ❌ 悪い例 | ✅ 良い例 |
|---|---|---|
| 一覧取得 | GET /getReports | GET /reports |
| 詳細取得 | GET /getReport?id=1 | GET /reports/1 |
| 作成 | POST /createReport | POST /reports |
| 更新 | POST /updateReport | PUT /reports/1 |
| 削除 | POST /deleteReport | DELETE /reports/1 |

**ネスト構造:**
```http
# レポートのコメント一覧
GET /reports/{reportId}/comments

# 特定のコメント
GET /reports/{reportId}/comments/{commentId}

# ただし深すぎるネストは避ける（3階層まで）
# ❌ /users/{id}/reports/{id}/comments/{id}/replies/{id}
```

**複数形 vs 単数形:**
- コレクション: 複数形 `/reports`
- 個別リソース: `/reports/{id}`
→ 一貫して複数形を使うのが一般的

</details>

---

### Q11. REST API のバージョニング戦略として正しいのは？

- A) バージョニングは不要
- B) 必ずURLパスでバージョニングすべき
- C) バージョンは1回決めたら変更できない
- D) URLパス、ヘッダー、クエリパラメータなど複数の方法がある

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**

| 方式 | 例 | メリット | デメリット |
|---|---|---|---|
| **URLパス** | `/v1/reports` | 明確、キャッシュしやすい | URLが変わる |
| **ヘッダー** | `Accept: application/vnd.api+json;version=1` | URL不変 | デバッグしづらい |
| **クエリパラメータ** | `/reports?version=1` | 簡単 | 一般的でない |

**URLパス方式（最も一般的）:**
```http
GET /v1/reports
GET /v2/reports  # 破壊的変更があった場合
```

**Ktor での実装:**
```kotlin
routing {
    route("/v1") {
        route("/reports") {
            get { /* v1 の実装 */ }
        }
    }
    route("/v2") {
        route("/reports") {
            get { /* v2 の実装 */ }
        }
    }
}
```

**バージョンアップの基準:**
- 破壊的変更（必須フィールド追加、型変更）: メジャーバージョン更新
- 後方互換な追加: 既存バージョンのまま

</details>

---

### Q12. HATEOAS とは何か？

- A) HTTPの認証方式
- B) レスポンスにリンクを含めてクライアントの遷移を導く設計
- C) APIのパフォーマンス最適化手法  
- D) エラーハンドリングの標準規格

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**

**HATEOAS (Hypermedia As The Engine Of Application State):**
レスポンスに「次にできるアクション」のリンクを含める設計原則。

```json
{
  "id": "report-123",
  "title": "Monthly Report",
  "status": "DRAFT",
  "_links": {
    "self": { "href": "/reports/report-123" },
    "submit": { "href": "/reports/report-123/submit", "method": "POST" },
    "delete": { "href": "/reports/report-123", "method": "DELETE" }
  }
}
```

**メリット:**
- クライアントがURLをハードコードしなくて済む
- APIの変更にクライアントが追従しやすい
- 状態に応じて利用可能なアクションがわかる

```json
// status が SUBMITTED の場合
{
  "status": "SUBMITTED",
  "_links": {
    "self": { "href": "/reports/report-123" },
    "approve": { "href": "/reports/report-123/approve", "method": "POST" },
    "reject": { "href": "/reports/report-123/reject", "method": "POST" }
    // "submit" は表示されない（既に提出済み）
  }
}
```

**現実での採用:**
- 完全なHATEOASは実装コストが高い
- 部分的に採用（ページネーションのnext/prevリンクなど）が多い

</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 HTTP/RESTの設計原則を深く理解している |
| 8-10問 | 👍 基礎はOK。ヘッダーとステータスコードを復習 |
| 5-7問 | 📖 メソッドの意味論とステータスコードを復習 |
| 4問以下 | 📚 HTTPの基礎から学び直し |

---

## 📝 復習用キーワード

- **冪等性**: GET/PUT/DELETE は冪等、POST は非冪等
- **PUT vs PATCH**: 全置換 vs 部分更新
- **400 vs 422**: 構文エラー vs ビジネスロジックエラー
- **404 vs 410**: 見つからない vs 恒久的に削除された
- **500番台**: 500=汎用、502=上流エラー、503=一時利用不可、504=タイムアウト
- **Content-Type vs Accept**: 送るデータの形式 vs 期待する形式
- **Cache-Control**: private/public, max-age, no-cache/no-store
- **ETag / If-None-Match**: キャッシュ検証、楽観的ロック
- **RESTful URL**: リソースは名詞、操作はHTTPメソッド
- **HATEOAS**: レスポンスにリンクを含めて遷移を導く
