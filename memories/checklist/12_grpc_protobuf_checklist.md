# gRPC / Protocol Buffers 理解度チェックリスト

gRPC と Protocol Buffers の仕組みを理解し、**自分で `.proto` ファイルを定義し、Ktor サーバーで実装できる**ことを目指します。

---

## 📚 セクション1: Protocol Buffers 基礎

### Q1. Protocol Buffers (protobuf) と JSON の違いとして**正しい**ものは？

- A) protobuf はテキスト形式で人間が読めるが、JSON はバイナリで読めない
- B) protobuf はバイナリ形式でサイズが小さく高速だが、JSON のようにスキーマなしで使うことはできない
- C) protobuf は JavaScript でしか使えない
- D) JSON の方がシリアライズ/デシリアライズが高速

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**

| 特性 | Protocol Buffers | JSON |
|---|---|---|
| 形式 | バイナリ | テキスト |
| サイズ | 小さい | 大きい（キー名が入る） |
| 速度 | 速い | 遅い |
| スキーマ | **必須**（.proto） | **不要**（柔軟） |
| 人間の可読性 | ❌ | ✅ |

**モバイル開発での類似:**
Retrofit で使う `@Serializable` クラス (kotlinx.serialization) や `Moshi` は JSON 用。
gRPC 通信では protobuf がそれに代わります。

**なぜ gRPC は protobuf を使う？**
- マイクロサービス間は大量の通信が発生するため、サイズと速度が重要
- スキーマ（.proto）があることで、サーバー/クライアント間の型安全性が保証される

</details>

---

### Q2. `.proto` ファイルにおける `message` の役割は？

```protobuf
message Report {
  string id = 1;
  string title = 2;
  string user_id = 3;
  int64 created_at = 4;
}
```

- A) データベースのテーブル定義
- B) HTTP リクエストの URL パス定義
- C) データの構造（型とフィールド）を定義する。Kotlin の data class に相当
- D) 関数（API エンドポイント）の定義

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
`message` は protobuf におけるデータ構造の定義です。

```protobuf
message Report {
  string id = 1;        // フィールド番号 1
  string title = 2;     // フィールド番号 2
  string user_id = 3;   // フィールド番号 3
  int64 created_at = 4; // フィールド番号 4
}
```

**Kotlin data class との対応:**
```kotlin
// 生成されるコード（イメージ）
data class Report(
    val id: String,
    val title: String,
    val userId: String,
    val createdAt: Long
)
```

**フィールド番号（= 1, = 2...）とは？**
これは変数名ではなく、**バイナリでの識別子**です。
- JSON: `{"id": "abc"}` ← キー名 "id" がデータに含まれる
- protobuf: `[1: "abc"]` ← 番号だけ。小さくなる

**重要ルール:**
- 一度使った番号は変更・再利用してはいけない（互換性が壊れる）
- 番号は連番でなくてもOK

</details>

---

### Q3. `repeated` キーワードの意味は？

```protobuf
message GetReportsResponse {
  repeated Report reports = 1;
}
```

- A) フィールドを省略可能にする
- B) フィールドを配列（リスト）にする
- C) フィールドを必須にする
- D) フィールドの値を繰り返し送信する（ストリーミング）

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
`repeated` は配列/リストを表します。

```protobuf
message GetReportsResponse {
  repeated Report reports = 1;  // List<Report>
}
```

**Kotlin での対応:**
```kotlin
data class GetReportsResponse(
    val reports: List<Report>
)
```

**proto3 のフィールドルール:**
| キーワード | Kotlin相当 | 説明 |
|---|---|---|
| なし（単数形） | `String` | 単一値。デフォルト値あり |
| `repeated` | `List<T>` | 配列。空リストがデフォルト |
| `optional` | `String?` | 明示的に省略可能（proto3.15+） |
| `map<K,V>` | `Map<K,V>` | マップ |

</details>

---

### Q4. `enum` の定義で注意すべき点は？

```protobuf
enum ReportType {
  REPORT_TYPE_UNSPECIFIED = 0;
  REPORT_TYPE_WORK = 1;
  REPORT_TYPE_EXPENSE = 2;
}
```

- A) 最初の値は必ず 0 にして `UNSPECIFIED` などを入れる
- B) 値は必ず 1 から始めなければならない
- C) enum の値は文字列で定義する
- D) enum は message の中でしか定義できない

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
proto3 では、**enum の最初の値は 0 でなければならない**という制約があります。

**なぜ 0 を UNSPECIFIED にするのか？**
- protobuf はフィールドが設定されていない場合、デフォルト値（0）を使う
- 意味のある値（WORK=0）をデフォルトにすると、「設定されていない」と「WORKを選んだ」の区別がつかない
- `UNSPECIFIED = 0` にすることで、「未設定」を明示できる

**命名規則（Google Style Guide）:**
```protobuf
enum ReportType {
  REPORT_TYPE_UNSPECIFIED = 0;  // 型名_UNSPECIFIED
  REPORT_TYPE_WORK = 1;         // 型名_値名
  REPORT_TYPE_EXPENSE = 2;
}
```

</details>

---

## 📚 セクション2: gRPC Service 定義

### Q5. gRPC の `service` 定義の役割は？

```protobuf
service ReportService {
  rpc GetReport(GetReportRequest) returns (Report);
  rpc ListReports(ListReportsRequest) returns (ListReportsResponse);
  rpc CreateReport(CreateReportRequest) returns (Report);
}
```

- A) データベース接続の設定
- B) API エンドポイント（メソッド）と、その入出力の型を定義
- C) 認証方式の設定
- D) ロードバランサーの設定

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
`service` は API のインターフェース定義です。

```protobuf
service ReportService {
  rpc GetReport(GetReportRequest) returns (Report);
  //  ^^ メソッド名  ^^ リクエスト型       ^^ レスポンス型
}
```

**REST との対応:**
| gRPC | REST 相当 |
|---|---|
| `rpc GetReport(...)` | `GET /reports/{id}` |
| `rpc ListReports(...)` | `GET /reports` |
| `rpc CreateReport(...)` | `POST /reports` |

**Kotlin コード生成後:**
```kotlin
// サーバー側（Ktor）で実装するインターフェース
interface ReportServiceGrpc {
    suspend fun getReport(request: GetReportRequest): Report
    suspend fun listReports(request: ListReportsRequest): ListReportsResponse
    suspend fun createReport(request: CreateReportRequest): Report
}
```

</details>

---

### Q6. gRPC の4つの通信パターンのうち、最も基本的な「Unary RPC」の特徴は？

- A) クライアントがストリームでデータを送り続ける
- B) サーバーがストリームでデータを送り続ける
- C) クライアントが1リクエスト送り、サーバーが1レスポンスを返す（REST APIと同じ）
- D) 双方向でリアルタイムにデータをやり取りする

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**

| パターン | 説明 | 使用例 |
|---|---|---|
| **Unary** | 1リクエスト → 1レスポンス | 通常のCRUD操作 |
| Server Streaming | 1リクエスト → N レスポンス | チャット履歴取得 |
| Client Streaming | N リクエスト → 1レスポンス | ファイルアップロード |
| Bidirectional | N リクエスト ⇔ N レスポンス | リアルタイムチャット |

**proto での定義:**
```protobuf
// Unary（最も基本）
rpc GetReport(GetReportRequest) returns (Report);

// Server Streaming
rpc WatchReports(WatchRequest) returns (stream Report);

// Client Streaming
rpc UploadChunks(stream Chunk) returns (UploadResult);

// Bidirectional
rpc Chat(stream Message) returns (stream Message);
```

**まずは Unary だけ理解すれば OK！**

</details>

---

### Q7. `GetReportRequest` のような Request メッセージを別途定義する理由は？

```protobuf
message GetReportRequest {
  string report_id = 1;
}

rpc GetReport(GetReportRequest) returns (Report);
```

なぜ `rpc GetReport(string) returns (Report)` と書かないのか？

- A) protobuf の文法エラーになるから
- B) 将来的にパラメータを追加しても、後方互換性を保てるから
- C) パフォーマンスが向上するから
- D) 特に理由はなく、どちらでも良い

<details>
<summary>答えを見る</summary>

**正解: A, B（両方正解）**

**解説:**

**A: 文法上の制約**
gRPC の rpc メソッドは `message` 型のみを受け取れます。プリミティブ型（string, int など）は直接使えません。

**B: 設計上のベストプラクティス**
最初は `report_id` だけでも、後で追加できる：
```protobuf
message GetReportRequest {
  string report_id = 1;
  bool include_deleted = 2;  // ← 後から追加しても互換性OK
}
```

**Wrap パターン:**
Google は全てのリクエスト/レスポンスを専用の message でラップすることを推奨しています。

</details>

---

## 📚 セクション3: コード生成と実装

### Q8. `protoc` コマンドの役割は？

- A) .proto ファイルの文法チェックのみ行う
- B) .proto ファイルからプログラム言語（Kotlin, Java等）のソースコードを自動生成する
- C) gRPC サーバーを起動する
- D) データベースのマイグレーションを実行する

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
`protoc` (Protocol Buffers Compiler) は、`.proto` ファイルから各言語のコードを生成するツールです。

**生成フロー:**
```
report.proto  ──[protoc]──>  Report.kt
                             ReportServiceGrpc.kt
                             etc.
```

**build.gradle.kts での設定例:**
```kotlin
protobuf {
    protoc {
        artifact = "com.google.protobuf:protoc:3.25.1"
    }
    plugins {
        id("grpckt") {
            artifact = "io.grpc:protoc-gen-grpc-kotlin:1.4.0:jdk8@jar"
        }
    }
    generateProtoTasks {
        all().forEach {
            it.plugins {
                id("grpckt")
            }
        }
    }
}
```

**Android開発との類似:**
Room の `@Entity` から DAO 実装が自動生成されるのと同じ発想です。

</details>

---

### Q9. 生成されたコードで `suspend fun` になる理由は？

```kotlin
// 生成されるサービス実装のインターフェース
abstract class ReportServiceGrpcKt {
    abstract suspend fun getReport(request: GetReportRequest): Report
}
```

- A) protoc の Kotlin プラグインが Coroutines をサポートしているから
- B) gRPC 通信は必ず非同期で行われるから
- C) Ktor が Coroutines ベースだから
- D) 上記すべて

<details>
<summary>答えを見る</summary>

**正解: D（すべて正解）**

**解説:**

**gRPC + Kotlin + Ktor の組み合わせ:**
- **gRPC-Kotlin**: Coroutines ネイティブサポート（`suspend fun` を生成）
- **Ktor**: Coroutines ベースのフレームワーク
- **gRPC通信**: ネットワークI/Oは本質的に非同期

**実装例:**
```kotlin
class ReportServiceImpl(
    private val repository: ReportRepository
) : ReportServiceGrpcKt.ReportServiceCoroutineImplBase() {
    
    override suspend fun getReport(request: GetReportRequest): Report {
        // ↑ suspend fun なので、repository の非同期処理をそのまま呼べる
        return repository.findById(request.reportId)
            ?: throw StatusException(Status.NOT_FOUND)
    }
}
```

</details>

---

## 📚 セクション4: エラーハンドリング

### Q10. gRPC のエラーを表す `Status` コードで、HTTP 404 に相当するのは？

- A) `Status.INVALID_ARGUMENT`
- B) `Status.NOT_FOUND`
- C) `Status.PERMISSION_DENIED`
- D) `Status.UNAVAILABLE`

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**

| gRPC Status | HTTP相当 | 使用場面 |
|---|---|---|
| `OK` | 200 | 成功 |
| `INVALID_ARGUMENT` | 400 | バリデーションエラー |
| `NOT_FOUND` | 404 | リソースが存在しない |
| `PERMISSION_DENIED` | 403 | 権限がない |
| `UNAUTHENTICATED` | 401 | 認証が必要 |
| `INTERNAL` | 500 | サーバー内部エラー |
| `UNAVAILABLE` | 503 | サービス一時停止 |

**Kotlin での例外スロー:**
```kotlin
override suspend fun getReport(request: GetReportRequest): Report {
    return repository.findById(request.reportId)
        ?: throw StatusException(Status.NOT_FOUND.withDescription("Report not found"))
}
```

</details>

---

### Q11. gRPC でエラーの詳細情報を返すための仕組みは？

- A) レスポンスの message に `error` フィールドを追加する
- B) `Status.withDescription()` や Trailer Metadata を使う
- C) HTTP ヘッダーでエラー情報を返す
- D) 別のエラー専用 RPC メソッドを呼び出す

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**

**基本: Status + Description**
```kotlin
throw StatusException(
    Status.INVALID_ARGUMENT
        .withDescription("report_id is required")
)
```

**詳細: ErrorInfo (Google の標準)**
```kotlin
val errorInfo = ErrorInfo.newBuilder()
    .setReason("INVALID_REPORT_ID")
    .setDomain("myapp.example.com")
    .putMetadata("report_id", request.reportId)
    .build()

throw StatusProto.toStatusException(
    com.google.rpc.Status.newBuilder()
        .setCode(Code.INVALID_ARGUMENT_VALUE)
        .setMessage("Validation failed")
        .addDetails(Any.pack(errorInfo))
        .build()
)
```

**モバイル側での受け取り:**
```kotlin
try {
    val report = stub.getReport(request)
} catch (e: StatusException) {
    when (e.status.code) {
        Status.Code.NOT_FOUND -> // 見つからない
        Status.Code.INVALID_ARGUMENT -> // バリデーションエラー
        else -> // その他
    }
}
```

</details>

---

## 📚 セクション5: ベストプラクティス

### Q12. `.proto` ファイルのパッケージ設計として推奨されるのは？

```protobuf
syntax = "proto3";

package myapp.report.v1;

option java_package = "com.example.myapp.report.v1";
option java_multiple_files = true;
```

上記のような設計にする理由として正しいのは？

- A) `v1` のようにバージョンを含めることで、破壊的変更時に新しい `v2` を作れる
- B) `java_package` でコード生成先のパッケージを明示できる
- C) `java_multiple_files = true` でファイルを分割し、コード管理しやすくなる
- D) 上記すべて

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**

**バージョニング戦略:**
```
proto/
├── myapp/report/v1/
│   ├── report.proto      # 現行版
│   └── report_service.proto
└── myapp/report/v2/      # 破壊的変更が必要になったら
    ├── report.proto      # 新版
    └── report_service.proto
```

**Option の説明:**
| Option | 説明 |
|---|---|
| `java_package` | 生成コードの Java/Kotlin パッケージ |
| `java_multiple_files` | message ごとに別ファイル生成（trueが推奨） |
| `go_package` | Go 用のパッケージ指定 |

**フィールド番号とバージョニング:**
- 既存フィールドの番号変更 → 互換性が壊れる → **禁止**
- 新フィールド追加 → 新しい番号で追加 → **OK**
- フィールド削除 → `reserved` で番号を予約 → **OK**

```protobuf
message Report {
  reserved 4;  // 削除したフィールドの番号を予約
  reserved "old_field_name";  // 名前も予約
  
  string id = 1;
  string title = 2;
  // field 3 was removed
}
```

</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 proto 定義から実装まで問題なし |
| 8-10問 | 👍 基礎はOK。エラーハンドリングを復習 |
| 5-7問 | 📖 message と service の定義を重点復習 |
| 4問以下 | 📚 protobuf 基礎から学び直し |

---

## 📝 復習用キーワード

- **Protocol Buffers**: スキーマ必須のバイナリシリアライゼーション
- **message**: データ構造の定義（data class相当）
- **フィールド番号**: バイナリでの識別子、変更禁止
- **repeated**: 配列/リスト
- **enum**: 最初は UNSPECIFIED = 0
- **service / rpc**: APIエンドポイント定義
- **Unary RPC**: 1リクエスト → 1レスポンス
- **protoc**: コード生成コンパイラ
- **Status**: gRPCのエラーコード（NOT_FOUND, INVALID_ARGUMENT等）
- **バージョニング**: パッケージに v1, v2 を含める
