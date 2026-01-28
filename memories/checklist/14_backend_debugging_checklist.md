# バックエンドデバッグ基礎 理解度チェックリスト

バックエンド開発で発生するエラーの**原因を特定し、解決できる**ようになることを目指します。
「なぜ 500 エラーになったのか」「どこを見ればいいのか」がわかるようになることがゴールです。

---

## 📚 セクション1: ログの見方

### Q1. サーバーログで最初に確認すべき情報は？

サーバーが 500 Internal Server Error を返しているとき、ログで最初に探すべきものは？

- A) CPU使用率
- B) スタックトレース（例外発生箇所）とエラーメッセージ
- C) アクセスしてきたIPアドレス
- D) レスポンスのサイズ

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
500 エラーは「サーバー内部で例外が発生した」ことを意味します。
**スタックトレース**を見れば、どのファイルの何行目でエラーが起きたかがわかります。

**Ktor のログ例:**
```
2026-01-26 10:00:00.123 [ktor-pool] ERROR - Unhandled exception
java.lang.NullPointerException: Cannot invoke method on null object
    at com.cleaning.routes.ReportRoutesKt$reportRoutes$1.invokeSuspend(ReportRoutes.kt:42)
    at com.cleaning.repositories.ReportRepositoryImpl.findById(ReportRepositoryImpl.kt:28)
    ...
```

**読み方:**
1. `NullPointerException` → 何が null だったか推測
2. `ReportRoutes.kt:42` → この行を確認
3. スタックトレースを下にたどると発生源が見える

</details>

---

### Q2. 構造化ログ（JSON形式）を使うメリットは？

```json
{"timestamp":"2026-01-26T10:00:00Z","level":"ERROR","requestId":"abc123","userId":"user456","message":"Report not found","reportId":"report789"}
```

- A) 人間が読みやすい
- B) ファイルサイズが小さくなる
- C) セキュリティが向上する
- D) ログ検索ツール（Cloud Logging等）でフィールドごとにフィルタ・集計ができる

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**
構造化ログは、ログ集約システムで**フィルタ・検索・集計**が簡単にできます。

**Cloud Logging での検索例:**
```
jsonPayload.requestId="abc123"   ← 特定のリクエストを追跡
jsonPayload.userId="user456"     ← 特定ユーザーの問題を調査
jsonPayload.level="ERROR"        ← エラーだけ抽出
```

**非構造化 vs 構造化:**
```
# 非構造化（パースが大変）
[ERROR] 2026-01-26 10:00:00 - Report not found: report789 for user user456

# 構造化（フィールドで検索可能）
{"level":"ERROR","reportId":"report789","userId":"user456"}
```

**Ktor での設定:**
```kotlin
install(CallLogging) {
    format { call ->
        val requestId = call.request.headers["X-Request-ID"]
        """{"requestId":"$requestId","method":"${call.request.httpMethod}"}"""
    }
}
```

</details>

---

### Q3. Request ID（リクエストID）の目的は？

- A) 課金のためにリクエスト数をカウントする
- B) 同じリクエストが複数回実行されるのを防ぐ（冪等性）
- C) 1つのリクエストに関連するログを、複数サービスにまたがって追跡する
- D) ユーザーを識別する

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
マイクロサービス環境では、1つのリクエストが複数のサービスを経由します。

```
[Mobile App]
    ↓ Request-ID: abc123
[API Gateway / BFF]
    ↓ Request-ID: abc123
[Report Service]
    ↓ Request-ID: abc123
[User Service]
```

**全サービスのログに同じ Request-ID を出力**すれば、問題発生時に全体の流れを追跡できます。

**検索例:**
```
# Cloud Logging で abc123 を検索
→ BFF のログ: "Start processing request abc123"
→ Report Service のログ: "Fetching report for abc123"
→ User Service のログ: "ERROR: User not found for abc123"  ← 原因発見！
```

</details>

---

## 📚 セクション2: CLIデバッグツール

### Q4. REST API をテストする `curl` コマンドの基本形は？

```bash
curl -X POST http://localhost:8080/reports \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbG..." \
  -d '{"title": "Test Report"}'
```

このコマンドの各オプションの意味として正しいのは？

- A) `-X POST`: POSTメソッド、`-H`: ヘッダー、`-d`: ボディ
- B) `-X POST`: ファイル送信、`-H`: ホスト名、`-d`: ダウンロード
- C) `-X POST`: デバッグモード、`-H`: ヘルプ、`-d`: 詳細表示
- D) `-X POST`: プロキシ経由、`-H`: HTTPS強制、`-d`: 遅延設定

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
`curl` は HTTP リクエストを送信するコマンドラインツールです。

| オプション | 意味 | 例 |
|---|---|---|
| `-X` | HTTPメソッド指定 | `-X POST`, `-X PUT`, `-X DELETE` |
| `-H` | ヘッダー追加 | `-H "Content-Type: application/json"` |
| `-d` | リクエストボディ | `-d '{"key": "value"}'` |
| `-v` | 詳細出力（デバッグ用） | ヘッダーの中身も見える |
| `-i` | レスポンスヘッダー表示 | ステータスコード確認 |

**デバッグ用の便利なオプション:**
```bash
# 詳細表示
curl -v http://localhost:8080/health

# レスポンスヘッダー込みで表示
curl -i http://localhost:8080/reports

# JSON を整形して表示
curl http://localhost:8080/reports | jq
```

</details>

---

### Q5. gRPC API をコマンドラインでテストするツールは？

- A) `curl`
- B) `wget`
- C) `grpcurl`
- D) `ssh`

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
gRPC は HTTP/2 + Protocol Buffers を使うため、通常の `curl` では叩けません。
`grpcurl` は gRPC 用の curl 相当ツールです。

**インストール:**
```bash
brew install grpcurl
```

**使い方:**
```bash
# サービス一覧を確認
grpcurl -plaintext localhost:50051 list

# メソッド一覧を確認
grpcurl -plaintext localhost:50051 list myapp.ReportService

# メソッド呼び出し
grpcurl -plaintext \
  -d '{"report_id": "abc123"}' \
  localhost:50051 myapp.ReportService/GetReport
```

**オプション:**
| オプション | 意味 |
|---|---|
| `-plaintext` | TLSなし（開発環境） |
| `-d` | リクエストボディ（JSON形式） |
| `-H` | メタデータ（認証トークン等） |

</details>

---

### Q6. PostgreSQL に直接接続してデバッグする `psql` コマンドは？

- A) `psql "host=localhost dbname=mydb user=admin password=secret"`
- B) `psql -connect localhost:5432`
- C) `psql --database localhost`
- D) `mysql -h localhost -u admin`

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
`psql` は PostgreSQL の公式クライアントです。

**接続方法:**
```bash
# 接続文字列形式
psql "host=localhost port=5432 dbname=mydb user=admin password=secret"

# 環境変数から（より安全）
export DATABASE_URL="postgresql://admin:secret@localhost:5432/mydb"
psql $DATABASE_URL

# Supabase の場合
psql "postgresql://postgres:[PASSWORD]@db.[PROJECT].supabase.co:5432/postgres"
```

**よく使うコマンド:**
| コマンド | 意味 |
|---|---|
| `\dt` | テーブル一覧 |
| `\d tablename` | テーブル構造 |
| `\di` | インデックス一覧 |
| `\q` | 終了 |
| `\x` | 縦表示モード切替 |

**デバッグ例:**
```sql
-- データを直接確認
SELECT * FROM reports WHERE user_id = 'abc123' LIMIT 5;

-- 実行計画を確認
EXPLAIN ANALYZE SELECT * FROM reports WHERE month = '2026-01';
```

</details>

---

## 📚 セクション3: 環境変数とよくある設定ミス

### Q7. 環境変数が正しく設定されているか確認する方法は？

```kotlin
val databaseUrl = System.getenv("DATABASE_URL")
    ?: throw IllegalStateException("DATABASE_URL is not set")
```

このコードで `IllegalStateException` が発生した場合、最初に確認すべきことは？

- A) Kotlin の文法エラーがないか
- B) 環境変数 `DATABASE_URL` が本当に設定されているか
- C) データベースサーバーが起動しているか
- D) ネットワーク接続があるか

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
環境変数が設定されていないと、`System.getenv()` は `null` を返します。

**確認方法:**

```bash
# ローカル環境で確認
echo $DATABASE_URL

# Docker コンテナ内で確認
docker exec -it my-container printenv | grep DATABASE

# Cloud Run のログで確認
gcloud run services describe my-service --format='yaml' | grep env
```

**よくある設定ミス:**
1. `.env` ファイルを作ったが読み込んでいない
2. 環境変数名のタイポ（`DATABASE_URL` vs `DB_URL`）
3. 本番/ステージング/開発で異なる変数名を使っている
4. Docker Compose の `environment:` セクションに追加し忘れ

</details>

---

### Q8. 「IPアドレスが違うから接続できない」エラーの原因として考えられるのは？

開発者A: 「マイクロサービスBへのリクエストが 500 になる」
開発者B: 「サービスBの環境変数に書いてあるIPが古かったから直したよ」

このようなケースで、なぜIPアドレスの設定ミスが起きる？

- A) IPアドレスは毎秒変わるから
- B) 環境（開発/ステージング/本番）ごとに接続先が異なり、設定を間違えたから
- C) IPアドレスはランダムに決まるから
- D) サーバーがハッキングされたから

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
マイクロサービス環境では、サービス間の接続先URLを環境変数で管理することが多いです。

**環境ごとの違い:**
```bash
# 開発環境
USER_SERVICE_URL=http://localhost:8081

# ステージング
USER_SERVICE_URL=http://user-service.staging.internal:8080

# 本番
USER_SERVICE_URL=http://user-service.prod.internal:8080
```

**よくあるミス:**
1. 開発環境の `localhost` を本番にデプロイ
2. 古いIPアドレスのまま更新忘れ
3. 新しいサービスを追加したが、呼び出し元の設定を更新し忘れ

**ベストプラクティス:**
- IPアドレス直書きを避け、サービス名（DNS）を使う
- 環境ごとに設定ファイルを分離する
- CI/CDで環境変数を自動設定する

</details>

---

## 📚 セクション4: エラー原因の切り分け

### Q9. 500 エラーが発生したとき、原因を切り分ける順序として適切なのは？

- A) すぐにコードを変更して再デプロイ
- B) データベースを再起動
- C) ログを見る → 再現手順を確認 → 仮説を立てる → 確認
- D) ユーザーに「しばらくお待ちください」と伝える

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
闇雲にコードを変更すると、別の問題を引き起こす可能性があります。

**デバッグの手順:**

```
1. 【ログを見る】
   - エラーメッセージ、スタックトレースを確認
   - Request ID で全体の流れを追跡

2. 【再現手順を確認】
   - どのリクエストでエラーが発生するか
   - 特定のパラメータや条件があるか

3. 【仮説を立てる】
   - 「このデータが null なのでは」
   - 「環境変数が設定されていないのでは」

4. 【仮説を確認】
   - ログに追加情報を出力
   - curl / grpcurl で直接叩いてみる
   - psql でデータを確認

5. 【修正】
   - 原因が特定できてから修正
```

</details>

---

### Q10. 「DB接続エラー」と「クエリエラー」の違いは？

```
エラー A: Connection refused: localhost:5432
エラー B: ERROR: relation "reports" does not exist
```

- A) どちらも同じ意味
- B) A はSQLエラー、B は接続エラー
- C) A はネットワークエラー、B はディスク容量不足
- D) A はDBサーバーに接続できない、B はSQLが間違っている（テーブルがない）

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**

**エラー A: `Connection refused`**
→ DBサーバーへの**接続自体**ができていない

原因:
- DBサーバーが起動していない
- ホスト名/ポート番号が違う
- ファイアウォールでブロックされている
- VPN接続が必要なのに接続していない

**エラー B: `relation does not exist`**
→ **接続は成功**したが、SQLの実行でエラー

原因:
- テーブル名が違う
- マイグレーションを実行していない
- スキーマが違う（`public.reports` vs `myschema.reports`）

**切り分け方:**
```bash
# 接続できるか確認
psql $DATABASE_URL -c "SELECT 1"

# 接続OK → テーブル確認
psql $DATABASE_URL -c "\dt"
```

</details>

---

### Q11. ステージング環境では動くのに本番で動かない場合、確認すべきことは？

- A) コードの文法エラー
- B) 環境変数、DBの接続先、外部サービスのURL、権限設定など環境固有の設定
- C) プログラミング言語のバージョン
- D) IDEのプラグイン

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
「ステージングでは動く＝コードは正しい」と考えられます。
環境差異が原因である可能性が高いです。

**チェックリスト:**

| カテゴリ | チェック項目 |
|---|---|
| **環境変数** | 本番用の値が正しく設定されているか |
| **DB接続** | 本番DBのURL、ユーザー、パスワード |
| **外部サービス** | APIキー、エンドポイントURL |
| **権限** | サービスアカウントの権限、Secret Manager へのアクセス |
| **ネットワーク** | VPC、ファイアウォール、IPホワイトリスト |
| **データ** | 本番にしか存在しないデータパターン |

**デバッグ方法:**
```bash
# 本番の環境変数を確認
gcloud run services describe my-service --format='yaml'

# 本番のログを確認
gcloud logging read "resource.type=cloud_run_revision"
```

</details>

---

### Q12. デバッグ用にログを追加したいが、本番に出したくない場合の方法は？

- A) ログレベルを使い分ける（DEBUG/INFO/ERROR）
- B) コメントアウトしてデプロイ
- C) 本番用と開発用で別のリポジトリを使う
- D) ログは一切出さない

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
ログレベルを使い分けることで、環境ごとに出力を制御できます。

**Ktor / Logback での設定:**
```kotlin
// コード側: レベルを指定してログ出力
log.debug("Debug info: request=$request")    // 開発時だけ見たい
log.info("Processing report: $reportId")     // 通常運用でも見たい
log.error("Failed to create report", e)      // エラー時は必ず出したい
```

**logback.xml での制御:**
```xml
<!-- 開発環境: DEBUGレベル以上を出力 -->
<root level="DEBUG">
    <appender-ref ref="STDOUT"/>
</root>

<!-- 本番環境: INFOレベル以上を出力（DEBUGは無視） -->
<root level="INFO">
    <appender-ref ref="STDOUT"/>
</root>
```

**環境変数で動的に制御:**
```bash
# 本番
LOG_LEVEL=INFO

# 本番で一時的にデバッグしたい場合
LOG_LEVEL=DEBUG
```

</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 バックエンドのデバッグ手法を理解している |
| 8-10問 | 👍 基礎はOK。実践で慣れていこう |
| 5-7問 | 📖 ログの見方とCLIツールを復習 |
| 4問以下 | 📚 先輩と一緒にデバッグしながら学ぼう |

---

## 📝 復習用キーワード

- **スタックトレース**: エラー発生箇所を特定
- **構造化ログ**: JSON形式でフィルタしやすい
- **Request ID**: サービス間でリクエストを追跡
- **curl**: REST API のデバッグ
- **grpcurl**: gRPC API のデバッグ
- **psql**: PostgreSQL クライアント
- **環境変数**: 環境ごとの設定値
- **Connection refused vs relation does not exist**: 接続エラー vs SQLエラー
- **ログレベル**: DEBUG/INFO/WARN/ERROR による出力制御
