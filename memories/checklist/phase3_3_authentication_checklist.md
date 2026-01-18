# Phase 3.3: 認証実装 理解度チェックリスト

Phase 3.3（Supabase Auth JWT検証、認証・認可の実装）に関する本質的な理解を確認するための問題集です。

---

## 📚 セクション1: 認証の基礎理解（4択問題）

### Q1. Supabase Authでログイン後、KtorでJWT検証が必要な理由は？

- A) Supabase Authでログインが通った時点でJWTは本物と証明されているため不要
- B) Supabase Authはログイン時にJWTを発行するだけで、その後のAPIリクエストの検証はKtor側で行う必要がある
- C) Cloud Runが自動的に検証してくれる
- D) FlutterがJWTを検証するため、サーバー側では不要

<details>
<summary>答えを見る</summary>

**正解: B**

```
ログイン時（1回だけ）:
  Flutter ──(email/password)──▶ Supabase Auth ──(JWT発行)──▶ Flutter

その後のAPIリクエスト（毎回）:
  Flutter ──(JWT)──▶ Ktor API
                       ↑
              Supabase Authはここに介在しない！
              JWTが本物かはKtor側で判断する必要がある
```

もしKtorで検証しなければ、悪意のある人が偽のJWTを作って他人のデータにアクセスできてしまいます。

</details>

---

### Q2. 認証（Authentication）と認可（Authorization）の違いは？

- A) 認証は「あなたは誰ですか？」、認可は「あなたは何ができますか？」
- B) 両者は同じ意味
- C) 認証はサーバー側、認可はクライアント側の処理
- D) 認証はパスワード、認可はメールアドレスを確認する

<details>
<summary>答えを見る</summary>

**正解: A**

```
認証（Authentication）- 「あなたは誰ですか？」
  例: ログインID/パスワード、指紋認証、顔認証
  → 本人確認

認可（Authorization）- 「あなたは何ができますか？」
  例: 管理者のみ削除可能、自分のデータのみ編集可能
  → 権限チェック
```

**Androidでの類似概念:**
- 認証 = `FirebaseAuth.signInWithEmailAndPassword()`
- 認可 = Firestoreのセキュリティルール

</details>

---

### Q3. JWT（JSON Web Token）の構造について正しいのはどれ？

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.
eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6..
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_a..
```

- A) 暗号化されているため解読できない
- B) ヘッダー、ペイロード、署名の3つの部分から構成され、ペイロードにユーザー情報が含まれる
- C) データベースに保存する必要がある
- D) 一度発行されると内容を変更できる

<details>
<summary>答えを見る</summary>

**正解: B**

**JWTの構造:**
```
ヘッダー (Header)
  → アルゴリズム情報（ES256等）

ペイロード (Payload) ← ここにユーザー情報が入っている
  → ユーザーID（sub）
  → メールアドレス
  → 有効期限（exp）
  → etc

署名 (Signature)
  → 改ざん検知用（シークレットキーまたは秘密鍵で作成）
```

**JWTの特徴:**
- 🔏 改ざん不可: 署名により内容の改ざんを検知できる
- 📦 自己完結: DBに問い合わせなくてもユーザー情報がわかる
- ⚡ 高速: 毎リクエストでDBアクセス不要

**注意:**
- ペイロードは**暗号化されていない**（Base64エンコード）
- 機密情報（パスワード等）を含めてはいけない

</details>

---

### Q4. ES256（ECC P-256）認証方式について正しいのはどれ？

- A) 対称鍵暗号方式で、シークレットキーが必要
- B) 非対称鍵暗号方式で、公開鍵のみで検証可能、シークレット管理不要
- C) HS256より安全性が低い
- D) Supabaseでは非推奨

<details>
<summary>答えを見る</summary>

**正解: B**

| 方式 | 説明 | シークレット管理 |
|:---|:---|:---|
| **HS256（旧）** | 対称鍵暗号 | 必要（漏れると危険） |
| **ES256（新）** | 非対称鍵暗号 | 不要（公開鍵のみ） |

**ES256のメリット:**
- ✅ 公開鍵は漏れても問題なし（検証専用）
- ✅ シークレット管理のリスクがゼロ
- ✅ Supabase推奨

**仕組み:**
```
[Supabase Auth]
  秘密鍵（非公開）でJWTに署名
       ↓
[JWKsエンドポイント]
  公開鍵を配布（誰でもアクセス可能）
       ↓
[Ktorサーバー]
  公開鍵でJWTの署名を検証
```

</details>

---

## 📚 セクション2: JWKsとKtor認証実装

### Q5. JWKs（JSON Web Key Set）の役割として正しいのはどれ？

- A) JWTを暗号化するための鍵
- B) サーバーがJWT検証に使う公開鍵を配布するエンドポイント
- C) ユーザーのパスワードを保存する場所
- D) データベースの接続情報

<details>
<summary>答えを見る</summary>

**正解: B**

Supabaseは各プロジェクトに**公開鍵を配布するエンドポイント**を提供しています：

```
GET https://{project-id}.supabase.co/auth/v1/.well-known/jwks.json
```

**レスポンス例:**
```json
{
  "keys": [
    {
      "kid": "key-id-here",
      "alg": "ES256",
      "kty": "EC",
      "x": "...",
      "y": "..."
    }
  ]
}
```

**JWKsの仕組み:**
- Ktorサーバーがこのエンドポイントから公開鍵を取得
- その公開鍵でJWTの署名を検証
- 署名が正しければSupabase Authが発行した本物のJWT

</details>

---

### Q6. `JwkProviderBuilder` のキャッシュ設定の理由は？

```kotlin
val jwkProvider = JwkProviderBuilder(URL(...))
    .cached(10, 5, TimeUnit.MINUTES)
    .rateLimited(10, 1, TimeUnit.MINUTES)
    .build()
```

- A) セキュリティを高めるため
- B) 毎リクエストでJWKsエンドポイントにアクセスすると遅いため、公開鍵をキャッシュして高速化
- C) Supabaseの料金を削減するため
- D) 公開鍵を暗号化するため

<details>
<summary>答えを見る</summary>

**正解: B**

**キャッシュの重要性:**
```
キャッシュなし:
  リクエスト1 → JWKsエンドポイントにアクセス（遅い）
  リクエスト2 → JWKsエンドポイントにアクセス（遅い）
  リクエスト3 → JWKsエンドポイントにアクセス（遅い）

キャッシュあり:
  リクエスト1 → JWKsエンドポイントにアクセス → キャッシュに保存
  リクエスト2 → キャッシュから取得（高速！）
  リクエスト3 → キャッシュから取得（高速！）
```

**設定の意味:**
```kotlin
.cached(10, 5, TimeUnit.MINUTES)
  // 最大10個のキーを5分間キャッシュ

.rateLimited(10, 1, TimeUnit.MINUTES)
  // 1分間に最大10回までJWKsエンドポイントにアクセス
  // DoS攻撃からSupabaseを守る
```

**Android（OkHttp）での類似概念:**
```kotlin
OkHttpClient.Builder()
    .cache(Cache(cacheDir, cacheSize))
```

</details>

---

### Q7. `verifier(jwkProvider, issuer)` の第2引数 `issuer` の役割は？

```kotlin
verifier(jwkProvider, "$supabaseUrl/auth/v1") {
    acceptLeeway(3)
}
```

- A) JWTの発行者URLをチェックし、Supabase以外からのJWTを拒否
- B) ユーザーIDを取得する
- C) 有効期限を設定する
- D) 公開鍵を暗号化する

<details>
<summary>答えを見る</summary>

**正解: A**

**issuer（発行者）チェック:**

JWTのペイロードに含まれる `iss`（issuer）クレームを検証します：

```json
{
  "iss": "https://xxx.supabase.co/auth/v1",
  "sub": "user-uuid",
  "exp": 1736693456,
  ...
}
```

```kotlin
verifier(jwkProvider, "$supabaseUrl/auth/v1")
  // ↑ JWTの iss が このURLと一致するかチェック
```

**なぜ必要？**
- 他のサービスが発行したJWTを誤って受け入れるのを防ぐ
- セキュリティ強化

**acceptLeeway(3) の意味:**
- サーバー間の時計のずれを3秒まで許容
- 有効期限チェックで誤検知を防ぐ

</details>

---

### Q8. `validate { credential -> }` ブロックが呼ばれるタイミングは？

```kotlin
validate { credential ->
    val userId = credential.payload.subject
    if (userId != null) {
        JWTPrincipal(credential.payload)
    } else {
        null
    }
}
```

- A) リクエスト受信直後
- B) verifierで署名検証が成功した後
- C) レスポンスを返す直前
- D) データベースにアクセスする前

<details>
<summary>答えを見る</summary>

**正解: B**

**認証の全体フロー:**
```
リクエスト受信
     ↓
[verifier] JWT署名を公開鍵で検証
     ↓ ✅ 署名OK
[validate] ← ここで呼ばれる
     │
     ├─ JWTPrincipal を返す → 認証成功 → ルートハンドラへ
     └─ null を返す → 認証失敗 → challenge へ
```

**verifierとvalidateの役割分担:**
- **verifier**: 署名が正しいか（改ざんされていないか）
- **validate**: 内容が正しいか（有効期限、必須クレーム等）

**validate での追加チェック例:**
```kotlin
validate { credential ->
    // 有効期限の独自チェック
    val expiresAt = credential.payload.expiresAt
    if (expiresAt?.time < System.currentTimeMillis()) {
        return@validate null
    }
    
    // 特定のロールを持っているかチェック
    val role = credential.payload.getClaim("role").asString()
    if (role == "banned") {
        return@validate null
    }
    
    JWTPrincipal(credential.payload)
}
```

</details>

---

### Q9. `challenge { _, _ -> }` ブロックの役割は？

```kotlin
challenge { _, _ ->
    call.respond(
        HttpStatusCode.Unauthorized,
        mapOf("error" to "Token is invalid or expired")
    )
}
```

- A) 認証成功時の処理
- B) 認証失敗時にクライアントに返すレスポンスをカスタマイズ
- C) データベース接続エラー時の処理
- D) ログを出力する処理

<details>
<summary>答えを見る</summary>

**正解: B**

**challengeが呼ばれる3つのケース:**

```
1. Authorizationヘッダーがない
   → 「トークンを送ってください」

2. verifierで署名検証に失敗
   → 「トークンが無効です」

3. validateでnullを返した
   → 「トークンは正しいが条件を満たさない」
```

**デフォルト vs カスタム:**
```kotlin
// デフォルト（challenge未定義の場合）
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer realm="cleaning-report-api"

// カスタム（JSON形式）
HTTP/1.1 401 Unauthorized
Content-Type: application/json
{
  "error": "Token is invalid or expired"
}
```

**なぜカスタマイズ？**
- クライアント（Flutter）側でパースしやすい
- エラーメッセージを詳細にできる

</details>

---

## 📚 セクション3: 認可とセキュリティ

### Q10. ログイン中ユーザーIDの取得方法として正しいのはどれ？

**A)**
```kotlin
authenticate("supabase-jwt") {
    get("/api/reports") {
        val userId = call.parameters["user_id"]
        // ...
    }
}
```

**B)**
```kotlin
authenticate("supabase-jwt") {
    get("/api/reports") {
        val principal = call.principal<JWTPrincipal>()
        val userId = principal?.payload?.subject
        // ...
    }
}
```

**C)**
```kotlin
authenticate("supabase-jwt") {
    get("/api/reports") {
        val userId = call.request.headers["User-Id"]
        // ...
    }
}
```

**D)**
```kotlin
authenticate("supabase-jwt") {
    get("/api/reports") {
        val userId = System.getenv("USER_ID")
        // ...
    }
}
```

<details>
<summary>答えを見る</summary>

**正解: B**

```kotlin
authenticate("supabase-jwt") {
    get("/api/reports") {
        val principal = call.principal<JWTPrincipal>()
        val userId = UUID.fromString(principal?.payload?.subject)
        
        // ← これが現在ログイン中のユーザーID
        val reports = reportRepository.findByMonth(month, userId)
        call.respond(reports.map { it.toDto() })
    }
}
```

**JWTPrincipalの中身:**
```
principal.payload.subject      // "sub" = ユーザーID
principal.payload.issuer       // "iss" = 発行者
principal.payload.expiresAt    // "exp" = 有効期限
principal.payload.getClaim("email")  // カスタムクレーム
```

**なぜクライアントからの値を信用しない？**
- ❌ `call.parameters["user_id"]` - クライアントが改ざん可能
- ❌ `call.request.headers["User-Id"]` - クライアントが改ざん可能
- ✅ `principal.payload.subject` - JWTから取得（改ざん不可）

</details>

---

### Q11. 「自分のレポートのみ編集可能」を実現する実装として正しいのはどれ？

**A)**
```kotlin
put("/api/v1/reports/{id}") {
    val id = UUID.fromString(call.parameters["id"])
    val report = reportRepository.findById(id)
    // チェックなしで更新
    reportRepository.update(report)
}
```

**B)**
```kotlin
authenticate("supabase-jwt") {
    put("/api/v1/reports/{id}") {
        val id = UUID.fromString(call.parameters["id"])
        val principal = call.principal<JWTPrincipal>()
        val userId = UUID.fromString(principal?.payload?.subject)
        
        val report = reportRepository.findById(id)
        
        // 認可チェック: 自分のデータかどうか
        if (report?.userId != userId) {
            call.respond(HttpStatusCode.Forbidden, mapOf("error" to "Access denied"))
            return@put
        }
        
        // OK: 自分のデータなので更新可能
        reportRepository.update(report)
    }
}
```

**C)**
```kotlin
put("/api/v1/reports/{id}") {
    val userId = call.parameters["user_id"]
    if (userId == "admin") {
        // 更新処理
    }
}
```

<details>
<summary>答えを見る</summary>

**正解: B**

**認可（Authorization）の実装:**

```kotlin
// 1. 認証（誰か判定）
val principal = call.principal<JWTPrincipal>()
val userId = UUID.fromString(principal?.payload?.subject)

// 2. 対象データ取得
val report = reportRepository.findById(id)

// 3. 認可チェック（権限判定）
if (report?.userId != userId) {
    call.respond(HttpStatusCode.Forbidden, ...)
    return@put
}

// 4. 権限OK → 処理実行
reportRepository.update(report)
```

**HTTPステータスコード:**
- `401 Unauthorized`: 認証されていない（ログインしてない）
- `403 Forbidden`: 認証済みだが権限がない（他人のデータ編集）

</details>

---

### Q12. RLS（Row Level Security）とKtor JWT認証の使い分けは？

- A) どちらか一方を選ぶべき
- B) Ktorで認証し、RLSは無効化する
- C) Ktorで認証してユーザーIDを取得し、RLSでさらにDB層で防御する（二重の防御）
- D) RLSだけで十分なのでKtorの認証は不要

<details>
<summary>答えを見る</summary>

**正解: C**

**多層防御（Defense in Depth）:**

```
[Flutter App]
     ↓ JWT付きリクエスト
[Ktor - JWT検証]  ← 第1の防御
     ↓ ユーザーID確定
[Ktor - 認可チェック]  ← 第2の防御
     ↓ OK
[Database - RLS]  ← 第3の防御（最終防御）
     ↓
[データ取得]
```

**それぞれの役割:**

| 層 | 役割 | 例 |
|:---|:---|:---|
| Ktorの認証 | JWTが本物か検証 | 偽JWTを弾く |
| Ktorの認可 | ビジネスロジックでの権限チェック | 「過去2ヶ月以外は編集不可」 |
| RLS | DB層での最終防御 | 「自分のデータのみアクセス可」 |

**なぜ多層防御？**
- KtorのコードにバグがあってもRLSが守る
- 直接DBアクセスされてもRLSが守る
- セキュリティの「最後の砦」

**Flutter + Supabase PostgRESTのみの場合:**
- KtorがないのでJWT検証はPostgRESTが担当
- RLSだけで十分（PostgRESTが自動検証）

**Flutter + Ktor + Supabase DBの場合:**
- Ktorで認証・認可
- RLSでさらに防御

</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 完全に理解している |
| 9-10問 | 👍 概ね理解している。復習推奨箇所あり |
| 6-8問 | 📖 基礎は理解しているが、深い理解が必要 |
| 5問以下 | 📚 Phase3.3_認証実装.md を再度読み込むことを推奨 |

---

## 📝 復習用キーワード

- **認証 vs 認可**: 本人確認 vs 権限チェック
- **JWT**: JSON Web Token（改ざん検知可能なトークン）
- **ES256**: 非対称鍵暗号（公開鍵で検証、シークレット管理不要）
- **JWKs**: JSON Web Key Set（公開鍵配布エンドポイント）
- **JwkProviderBuilder**: 公開鍵取得とキャッシュ
- **verifier**: JWT署名の検証
- **validate**: JWTの内容チェック（カスタムロジック）
- **challenge**: 認証失敗時のレスポンス
- **JWTPrincipal**: 認証済みユーザー情報
- **call.principal<JWTPrincipal>()**: ログイン中ユーザー取得
- **401 vs 403**: 未認証 vs 権限なし
- **多層防御**: Ktor認証 + RLS
