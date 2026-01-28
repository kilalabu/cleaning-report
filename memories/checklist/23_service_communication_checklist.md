# サービス間通信 理解度チェックリスト

マイクロサービス環境での**サービス間通信の仕組み**と**トラブルシューティング**ができるようになることを目指します。
「なぜ他のサービスへの呼び出しが失敗したのか」「どう設定すれば良いか」が判断できるようになることがゴールです。

---

## 📚 セクション1: マイクロサービスの基礎

### Q1. マイクロサービスアーキテクチャで「サービス間通信」が発生する典型的なケースは？

- A) 1つのサービス内でDBにクエリを投げる
- B) フロントエンドがバックエンドAPIを呼ぶ
- C) Report Service が User Service にユーザー情報を問い合わせる
- D) B と C の両方

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**
マイクロサービスでは、機能ごとにサービスが分かれているため、**サービス間の通信**が頻繁に発生します。

```
[Mobile App]
    ↓ (1) REST/gRPC
[BFF (Backend for Frontend)]
    ↓ (2) gRPC
[Report Service] ──gRPC──> [User Service]
                 ──gRPC──> [Notification Service]
```

**(1) フロントエンド → BFF**
- 外部向け API（REST または gRPC-Web）

**(2) BFF → 各マイクロサービス**
- 内部向け API（通常 gRPC）

**(3) サービス → サービス**
- 内部向け API（gRPC）

**この構成のメリット:**
- 各サービスを独立してデプロイ可能
- チームごとにサービスを担当
- スケーリングを個別に調整

</details>

---

### Q2. gRPC でサービス間通信を行う際、接続先を指定する方法は？

- A) IPアドレスをハードコード
- B) 環境変数でホスト名/URLを指定
- C) サービスディスカバリ（Kubernetes Service 等）を使用
- D) BとCの両方が一般的で、環境によって使い分ける

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**

**方法1: 環境変数（シンプル）**
```kotlin
val userServiceHost = System.getenv("USER_SERVICE_HOST") ?: "localhost"
val userServicePort = System.getenv("USER_SERVICE_PORT")?.toInt() ?: 50051

val channel = ManagedChannelBuilder
    .forAddress(userServiceHost, userServicePort)
    .usePlaintext()  // 開発時のみ
    .build()
```

**方法2: サービスディスカバリ（Kubernetes）**
```kotlin
// Kubernetes 内では Service 名で解決される
val channel = ManagedChannelBuilder
    .forTarget("dns:///user-service.default.svc.cluster.local:50051")
    .build()
```

**環境ごとの設定例:**
```bash
# 開発環境（ローカル）
USER_SERVICE_HOST=localhost
USER_SERVICE_PORT=50051

# 本番環境（Kubernetes）
USER_SERVICE_HOST=user-service.production.svc.cluster.local
USER_SERVICE_PORT=50051

# Cloud Run
USER_SERVICE_HOST=user-service-xxxxx-uc.a.run.app
USER_SERVICE_PORT=443
```

</details>

---

### Q3. サービス間通信で「環境変数の設定ミス」が起きやすい原因は？

- A) 環境変数は自動で設定されるため
- B) 環境変数は1つしか設定できないため
- C) 開発/ステージング/本番で接続先が異なるため、設定漏れや誤設定が起きやすい
- D) 環境変数は暗号化されないため

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
環境ごとに接続先が異なるため、**設定漏れや誤設定**が起きやすいです。

**よくあるミス:**
1. **開発環境の値を本番にデプロイ**
   ```bash
   # 開発で動いてたコードをそのまま本番に
   USER_SERVICE_HOST=localhost  # ← 本番では動かない
   ```

2. **新しい環境変数の追加忘れ**
   ```bash
   # 新しいサービスを追加したが、呼び出し元に設定忘れ
   NOTIFICATION_SERVICE_HOST=???  # ← 未設定
   ```

3. **タイポ**
   ```bash
   USER_SERIVCE_HOST=...  # ← SERVICE のスペルミス
   ```

**ベストプラクティス:**
- 起動時に必須の環境変数をチェック
- 設定ファイルを環境ごとに分離（.env.dev, .env.prod）
- CI/CD で環境変数を自動設定

</details>

---

## 📚 セクション2: gRPC クライアント設定

### Q4. gRPC クライアントで「タイムアウト」を設定する理由は？

- A) サーバーの処理を高速化するため
- B) セキュリティを向上させるため
- C) ログを出力するため
- D) 応答がない場合に無限に待ち続けることを防ぎ、リソースを解放するため

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**
タイムアウトがないと、サーバーが応答しない場合に**リソースを無限に消費**します。

```kotlin
// タイムアウト設定
val stub = UserServiceGrpc.newBlockingStub(channel)
    .withDeadlineAfter(5, TimeUnit.SECONDS)  // 5秒でタイムアウト

try {
    val user = stub.getUser(request)
} catch (e: StatusRuntimeException) {
    if (e.status.code == Status.Code.DEADLINE_EXCEEDED) {
        // タイムアウト発生
        log.error("User service timed out")
    }
}
```

**タイムアウトの伝播:**
```
Client(5s) → BFF(4s) → UserService(3s)
                    → ReportService(3s)
```
- 各サービスは呼び出し元より短いタイムアウトを設定
- そうしないと、呼び出し元がタイムアウトしても処理が続く

**デフォルトを設定しておく:**
```kotlin
val channel = ManagedChannelBuilder
    .forAddress(host, port)
    .defaultLoadBalancingPolicy("round_robin")
    .idleTimeout(60, TimeUnit.SECONDS)
    .build()
```

</details>

---

### Q5. gRPC でのリトライ設定として正しいのは？

- A) 全てのエラーでリトライすべき
- B) 一時的なエラー（UNAVAILABLE, DEADLINE_EXCEEDED等）のみリトライすべき
- C) リトライは不要
- D) サーバー側で実装すべき

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
**リトライすべきエラー（一時的）:**
- `UNAVAILABLE`: サーバーに到達できない（再起動中など）
- `DEADLINE_EXCEEDED`: タイムアウト（負荷が高かっただけかも）
- `RESOURCE_EXHAUSTED`: レート制限（後で再試行すれば通るかも）

**リトライすべきでないエラー（永続的）:**
- `NOT_FOUND`: リソースが存在しない
- `INVALID_ARGUMENT`: リクエストが不正
- `PERMISSION_DENIED`: 権限がない
- `ALREADY_EXISTS`: 重複

**gRPC のビルトインリトライ:**
```kotlin
val retryPolicy = mapOf(
    "methodConfig" to listOf(
        mapOf(
            "name" to listOf(mapOf("service" to "myapp.UserService")),
            "retryPolicy" to mapOf(
                "maxAttempts" to 3.0,
                "initialBackoff" to "0.1s",
                "maxBackoff" to "1s",
                "backoffMultiplier" to 2.0,
                "retryableStatusCodes" to listOf("UNAVAILABLE")
            )
        )
    )
)
```

</details>

---

### Q6. gRPC 通信で TLS（暗号化）が必要な場面は？

- A) 常に必要
- B) ローカル開発でも必要
- C) 本番環境でインターネット経由の場合
- D) Cloud Run 間の通信では不要

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**

| 環境 | TLS |
|---|---|
| ローカル開発 | 不要（`usePlaintext()`） |
| Kubernetes 内（同一クラスタ） | 推奨だが必須ではない |
| インターネット経由（Cloud Run等） | **必須** |

**設定例:**
```kotlin
// ローカル開発
val channel = ManagedChannelBuilder
    .forAddress("localhost", 50051)
    .usePlaintext()  // TLS なし
    .build()

// 本番（Cloud Run など）
val channel = ManagedChannelBuilder
    .forAddress("user-service.example.com", 443)
    .useTransportSecurity()  // TLS あり
    .build()
```

**Cloud Run 特有:**
- Cloud Run は自動で TLS を終端してくれる
- サービス間通信も自動で認証・暗号化される（IAM + TLS）

</details>

---

## 📚 セクション3: エラーハンドリング

### Q7. サービス間通信でエラーが発生した場合の対処として正しいのは？

```kotlin
try {
    val user = userServiceClient.getUser(userId)
} catch (e: StatusRuntimeException) {
    // どうする？
}
```

- A) 全て 500 エラーとしてクライアントに返す
- B) 例外を無視する
- C) サーバーを再起動する
- D) gRPC ステータスに応じて適切な HTTP ステータスに変換して返す

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**
gRPC のステータスコードを適切にハンドリングし、**意味のあるエラーをクライアントに返す**べきです。

```kotlin
try {
    val user = userServiceClient.getUser(userId)
} catch (e: StatusRuntimeException) {
    when (e.status.code) {
        Status.Code.NOT_FOUND -> {
            // ユーザーが見つからない → 404
            throw NotFoundException("User not found: $userId")
        }
        Status.Code.UNAVAILABLE -> {
            // サービス一時停止 → 503
            log.error("User service unavailable", e)
            throw ServiceUnavailableException("User service is temporarily unavailable")
        }
        Status.Code.DEADLINE_EXCEEDED -> {
            // タイムアウト → 504
            log.error("User service timeout", e)
            throw GatewayTimeoutException("User service timed out")
        }
        else -> {
            // 予期しないエラー → 500
            log.error("User service error", e)
            throw InternalServerErrorException("Internal error")
        }
    }
}
```

**マッピング例:**
| gRPC Status | HTTP Status |
|---|---|
| NOT_FOUND | 404 |
| INVALID_ARGUMENT | 400 |
| PERMISSION_DENIED | 403 |
| UNAUTHENTICATED | 401 |
| UNAVAILABLE | 503 |
| DEADLINE_EXCEEDED | 504 |
| INTERNAL | 500 |

</details>

---

### Q8. サーキットブレーカー（Circuit Breaker）パターンの目的は？

- A) 電気回路を保護する
- B) 障害が発生したサービスへの呼び出しを一時的に遮断し、復旧を待つ
- C) パスワードを暗号化する
- D) データベースを高速化する

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
サーキットブレーカーは、**連続してエラーが発生したサービスへの呼び出しを遮断**します。

```
状態遷移:
[Closed] ──エラー連続──> [Open] ──一定時間経過──> [Half-Open]
    ↑                              ↓ 成功
    └──────────────────────────────┘
```

**なぜ必要？**
- 障害サービスに呼び続けると、タイムアウト待ちでリソース消費
- 雪崩式に他のサービスも遅延（カスケード障害）

**実装例（Resilience4j）:**
```kotlin
val circuitBreaker = CircuitBreaker.ofDefaults("userService")

val result = circuitBreaker.executeSupplier {
    userServiceClient.getUser(userId)
}
```

**設定項目:**
- `failureRateThreshold`: 何%のエラーで Open にするか
- `waitDurationInOpenState`: Open 状態を維持する時間
- `permittedNumberOfCallsInHalfOpenState`: Half-Open で試行する回数

</details>

---

## 📚 セクション4: デバッグ

### Q9. サービス間通信が失敗した場合、最初に確認すべきことは？

- A) コードを修正する
- B) サーバーを再起動する
- C) ログを確認し、エラーメッセージと Request ID で問題箇所を特定する
- D) タイムアウトを長くする

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
**デバッグ手順:**

1. **エラーログを確認**
   ```
   ERROR - gRPC call failed: UNAVAILABLE: io exception
   ```

2. **Request ID で全サービスのログを追跡**
   ```bash
   # Cloud Logging
   jsonPayload.requestId="abc123"
   ```

3. **接続設定を確認**
   ```bash
   # 環境変数をチェック
   echo $USER_SERVICE_HOST
   echo $USER_SERVICE_PORT
   ```

4. **接続テスト**
   ```bash
   # grpcurl で直接叩く
   grpcurl -plaintext $USER_SERVICE_HOST:$USER_SERVICE_PORT list
   ```

5. **ネットワーク疎通確認**
   ```bash
   # DNS 解決
   nslookup $USER_SERVICE_HOST
   
   # Port 到達確認
   nc -zv $USER_SERVICE_HOST $USER_SERVICE_PORT
   ```

</details>

---

### Q10. 「Connection refused」エラーの原因として考えられるのは？

```
io.grpc.StatusRuntimeException: UNAVAILABLE: io exception
Channel Pipeline: [WriteBufferingAndExceptionHandler#0, DefaultChannelPipeline$TailContext#0]
Caused by: io.netty.channel.AbstractChannel$AnnotatedConnectException: Connection refused
```

- A) リクエストの形式が間違っている
- B) 対象サービスが起動していない、またはホスト/ポートが間違っている
- C) 認証に失敗した
- D) タイムアウトが短すぎる

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
「Connection refused」は**TCP接続自体が確立できない**ことを意味します。

**原因の切り分け:**

| チェック項目 | コマンド |
|---|---|
| サービスが起動しているか | `kubectl get pods` / Cloud Run Console |
| ホスト名が正しいか | `echo $USER_SERVICE_HOST` |
| ポート番号が正しいか | `echo $USER_SERVICE_PORT` |
| DNS 解決できるか | `nslookup $USER_SERVICE_HOST` |
| ポートに到達できるか | `nc -zv $HOST $PORT` |
| ファイアウォールで遮断されていないか | VPC / Security Group 設定確認 |

**よくあるミス:**
- 本番用 URL をローカルで使おうとした
- サービスが別のポートで起動している
- Kubernetes の Service が作成されていない

</details>

---

### Q11. 「DEADLINE_EXCEEDED」エラーの原因として考えられるのは？

- A) 対象サービスが存在しない
- B) 認証トークンが期限切れ
- C) リクエストのサイズが大きすぎる
- D) 対象サービスの処理が遅い、または呼び出し元のタイムアウト設定が短すぎる

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**
「DEADLINE_EXCEEDED」は**設定したタイムアウトを超過した**ことを意味します。

**原因:**
1. 対象サービスの処理が実際に遅い（DBクエリ、外部API等）
2. 呼び出し元のタイムアウト設定が短すぎる
3. ネットワーク遅延が大きい
4. サービスが高負荷で応答が遅い

**対処法:**
1. **対象サービスのログを確認**
   - 処理時間を確認
   - ボトルネック（遅いクエリ等）を特定

2. **タイムアウト設定を調整**
   ```kotlin
   // 5秒 → 10秒に延長
   stub.withDeadlineAfter(10, TimeUnit.SECONDS)
   ```

3. **サービスの性能改善**
   - インデックス追加
   - キャッシュ導入
   - 非同期処理化

</details>

---

### Q12. メタデータ（Metadata）を使った認証情報の受け渡し方法は？

- A) リクエストボディに含める
- B) gRPC Metadata（HTTP ヘッダー相当）に認証トークンを含める
- C) 環境変数で渡す
- D) 別の認証専用 RPC を呼ぶ

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
gRPC の **Metadata** は HTTP ヘッダーに相当し、認証トークンを渡すのに使用します。

**クライアント側:**
```kotlin
val metadata = Metadata()
val key = Metadata.Key.of("authorization", Metadata.ASCII_STRING_MARSHALLER)
metadata.put(key, "Bearer $token")

val stub = UserServiceGrpc.newBlockingStub(channel)
val stubWithAuth = MetadataUtils.attachHeaders(stub, metadata)

val user = stubWithAuth.getUser(request)
```

**サーバー側:**
```kotlin
override fun getUser(request: GetUserRequest): User {
    val token = context.request.metadata
        .get(Metadata.Key.of("authorization", Metadata.ASCII_STRING_MARSHALLER))
    
    // トークン検証...
}
```

**Ktor + gRPC の場合:**
Interceptor を使って全リクエストに自動付与することも可能

```kotlin
class AuthInterceptor(private val tokenProvider: () -> String) : ClientInterceptor {
    override fun <ReqT, RespT> interceptCall(
        method: MethodDescriptor<ReqT, RespT>,
        callOptions: CallOptions,
        next: Channel
    ): ClientCall<ReqT, RespT> {
        return object : ForwardingClientCall.SimpleForwardingClientCall<ReqT, RespT>(
            next.newCall(method, callOptions)
        ) {
            override fun start(responseListener: Listener<RespT>, headers: Metadata) {
                headers.put(AUTH_KEY, "Bearer ${tokenProvider()}")
                super.start(responseListener, headers)
            }
        }
    }
}
```

</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 サービス間通信を十分に理解している |
| 8-10問 | 👍 基礎はOK。エラーハンドリングを復習 |
| 5-7問 | 📖 gRPC クライアント設定を復習 |
| 4問以下 | 📚 マイクロサービスの基礎から学び直し |

---

## 📝 復習用キーワード

- **サービスディスカバリ**: DNS / Kubernetes Service / 環境変数
- **タイムアウト**: 無限待ちを防ぐ、伝播に注意
- **リトライ**: 一時的なエラー（UNAVAILABLE, DEADLINE_EXCEEDED）のみ
- **TLS**: インターネット経由では必須
- **エラーマッピング**: gRPC Status → HTTP Status
- **サーキットブレーカー**: 障害サービスへの呼び出しを遮断
- **Connection refused**: サービス未起動 or ホスト/ポート誤り
- **DEADLINE_EXCEEDED**: タイムアウト超過
- **Metadata**: 認証トークンの受け渡し
