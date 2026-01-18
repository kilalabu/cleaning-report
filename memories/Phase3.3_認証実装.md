# Phase 3.3: 認証実装 実装手順書

## 概要

このドキュメントでは、KtorでSupabase Auth JWTを検証し、ユーザー認証を実装します。

**ゴール**: Supabase Authで発行されたJWTを検証し、APIを保護する

---

## ❓ なぜKtorでJWT検証が必要なのか？（Q&A）

後日見返したときのために、認証実装の「なぜ」をまとめておきます。

### Q1: Supabase Authでログインが通った時点で、JWTは本物と証明されているのでは？

**A**: いいえ。Supabase Authは**ログイン時にJWTを発行するだけ**です。

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

---

### Q2: Flutter + Supabaseのみ（Ktorなし）の場合はどうなる？

**A**: Flutter側でJWT検証は**不要**です。Supabase PostgRESTが自動的に検証してくれます。

```
Flutter ──(JWT)──▶ Supabase PostgREST ──▶ DB
                          ↑
                   JWT自動検証 + RLSでアクセス制御
```

RLS（Row Level Security）で `auth.uid() = user_id` と書けば、自分のデータのみアクセス可能になります。

---

### Q3: なぜPostgRESTを使わずに自前（Ktor）で検証するのか？

**A**: 正直なところ、**現在の要件だけならPostgRESTで十分**です。

Ktorを選んだ理由：
1. **学習目的** - バックエンド技術（Ktor, DI, JWT検証等）を学ぶため
2. **Edge Functionsからの移行** - TypeScriptからKotlinへ
3. **将来の拡張性** - 複雑なビジネスロジック、PDF生成、外部API連携など

| 構成 | JWT検証の場所 | 向いているケース |
|:---|:---|:---|
| Flutter + Supabase PostgREST | Supabase側が自動検証 | シンプルなCRUD、開発速度優先 |
| Flutter + Ktor + Supabase DB | **Ktorで自前検証** | 複雑なロジック、学習目的、ベンダーロック回避 |

---

### Q4: 認証方式がHS256からES256に変わったのはなぜ？

**A**: Supabaseが新しいJWT Signing Keys（ECC P-256）へ移行を進めているためです。

| 方式 | 説明 |
|:---|:---|
| **HS256（旧）** | 対称鍵暗号。シークレットを安全に管理する必要がある |
| **ES256（新）** | 非対称鍵暗号。公開鍵のみで検証可能、シークレット管理不要 |

ES256のメリット：
- 公開鍵は漏れても問題なし（検証専用）
- シークレット管理のリスクがゼロ
- Supabase推奨

---

## 🤖 Androidエンジニア向け：サーバーサイド認証の基礎知識

Phase 3.3に入る前に、サーバーサイドでの認証がどのような仕組みで動くのかを理解しておきましょう。

### 1. 認証と認可の違い

```
┌───────────────────────────────────────────────────────────────┐
│  🔐 認証（Authentication）                                     │
│  「あなたは誰ですか？」を確認すること                          │
│                                                                 │
│  例: ログインID/パスワード、指紋認証、顔認証                   │
│  → 本人確認                                                    │
├───────────────────────────────────────────────────────────────┤
│  🛡️ 認可（Authorization）                                      │
│  「あなたは何ができますか？」を確認すること                    │
│                                                                 │
│  例: 管理者のみ削除可能、自分のデータのみ編集可能              │
│  → 権限チェック                                                │
└───────────────────────────────────────────────────────────────┘
```

**Androidでの類似概念**:
- 認証 = `FirebaseAuth.signInWithEmailAndPassword()`
- 認可 = Firestoreのセキュリティルール

---

### 2. JWT（JSON Web Token）とは？

**Androidでの類似概念**: SharedPreferencesに保存するセッショントークン

JWTは「改ざん検知機能付きのJSON」です。

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.   ← ヘッダー（アルゴリズム等）
eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6..   ← ペイロード（ユーザー情報）
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_a..   ← 署名（改ざん検知用）
```

```
┌───────────────────────────────────────────────────────────────┐
│  📝 JWTの構造                                                   │
├───────────────────────────────────────────────────────────────┤
│  ヘッダー (Header)                                             │
│  {                                                              │
│    "alg": "HS256",    ← 署名アルゴリズム                       │
│    "typ": "JWT"                                                 │
│  }                                                              │
├───────────────────────────────────────────────────────────────┤
│  ペイロード (Payload) ← ここにユーザー情報が入っている          │
│  {                                                              │
│    "sub": "user-uuid-here",    ← ユーザーID（重要！）          │
│    "email": "user@example.com",                                 │
│    "role": "staff",                                             │
│    "exp": 1736693456,          ← 有効期限（Unix時間）          │
│    "iss": "https://xxx.supabase.co/auth/v1"  ← 発行者          │
│  }                                                              │
├───────────────────────────────────────────────────────────────┤
│  署名 (Signature)                                               │
│  HMAC-SHA256(                                                   │
│    base64(header) + "." + base64(payload),                     │
│    "シークレットキー"    ← これを知っているのはサーバーだけ     │
│  )                                                              │
└───────────────────────────────────────────────────────────────┘
```

**なぜJWTを使うのか？**
- 🔏 改ざん不可: 署名により内容の改ざんを検知できる
- 📦 自己完結: DBに問い合わせなくてもユーザー情報がわかる
- ⚡ 高速: 毎リクエストでDBアクセス不要

---

### 3. クライアントとサーバーの役割分担

```
┌─────────────────────────────────────────────────────────────────────┐
│                        認証フローの全体像                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [Flutter App]                [Supabase Auth]           [Ktor API]  │
│       │                             │                        │      │
│       │  1. ログイン要求            │                        │      │
│       │  (email/password)           │                        │      │
│       │ ─────────────────────────▶ │                        │      │
│       │                             │                        │      │
│       │  2. JWT発行                 │                        │      │
│       │ ◀───────────────────────── │                        │      │
│       │                             │                        │      │
│       │  3. APIリクエスト + JWT                              │      │
│       │  (Authorization: Bearer eyJ...)                      │      │
│       │ ─────────────────────────────────────────────────▶  │      │
│       │                                                      │      │
│       │  4. JWT検証 → OK → ユーザーID取得 → データ返却       │      │
│       │ ◀─────────────────────────────────────────────────  │      │
│       │                                                      │      │
└─────────────────────────────────────────────────────────────────────┘
```

**各コンポーネントの責務**:

| コンポーネント | 責務 |
|:---|:---|
| **Flutter App** | ・ログインUIの提供<br>・JWTの保存・送信<br>・トークン期限切れ時の再ログイン誘導 |
| **Supabase Auth** | ・ユーザー管理（登録、パスワードリセット等）<br>・パスワード検証<br>・JWT発行 |
| **Ktor API** | ・JWTの検証（改ざんチェック、期限チェック）<br>・ユーザーIDの抽出<br>・認可（権限チェック） |

---

### 4. なぜ「トークン検証」だけでセキュアなのか？

```
┌───────────────────────────────────────────────────────────────┐
│  🤔 疑問: JWTはクライアントが持っているのに安全なの？          │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  悪い人がJWTを偽造しようとした場合:                            │
│                                                                 │
│  1. ペイロードを変更（user_idを他人に変える）                  │
│  2. しかし「署名」は「シークレットキー」がないと作れない       │
│  3. シークレットキーはサーバーだけが知っている                 │
│  4. サーバーで署名を検証 → 不一致 → 401 Unauthorized          │
│                                                                 │
│  つまり:                                                        │
│  ✅ 正しいJWT = Supabase Auth でログイン成功した証拠           │
│  ❌ 偽のJWT = 署名検証で弾かれる                                │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

---

### 5. サーバーサイドでの認証実装パターン

**Androidでの類似概念**: OkHttpのInterceptor

KtorではHTTPリクエストの「前処理」としてJWT検証を入れます：

```kotlin
// Android (OkHttp Interceptor)
class AuthInterceptor : Interceptor {
    override fun intercept(chain: Chain): Response {
        val request = chain.request().newBuilder()
            .addHeader("Authorization", "Bearer $token")
            .build()
        return chain.proceed(request)
    }
}

// Ktor (Authentication Plugin)
install(Authentication) {
    jwt("supabase-jwt") {
        // リクエストからトークンを取り出して検証
        verifier(JWT.require(Algorithm.HMAC256(secret)).build())
        validate { credential ->
            // 検証成功 → ユーザー情報を返す
            JWTPrincipal(credential.payload)
        }
    }
}
```

---

### 6. この実装で実現すること

```
┌───────────────────────────────────────────────────────────────┐
│  Phase 3.3 で実装する認証・認可                                 │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  ✅ 認証（JWT検証）                                            │
│    → ログイン済みユーザーのみAPIアクセス可能                   │
│                                                                 │
│  ✅ ユーザー識別                                               │
│    → JWTからuser_idを取得し、「誰のリクエストか」を判別        │
│                                                                 │
│  ✅ 認可（権限チェック）                                       │
│    → 自分のレポートのみ編集・削除可能                          │
│    → 管理者は全レポートにアクセス可能                          │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

---

## 認証方式

### Supabase Auth JWT検証（JWKs方式）

Flutter側は引き続きSupabase Authを使用し、KtorではJWTトークンを**公開鍵**で検証します。

> [!IMPORTANT]
> **Supabaseの新しいJWT Signing Keys（ECC P-256）に対応**
>
> Supabaseは従来のHS256（対称鍵）から非対称鍵暗号（ECC P-256/ES256）へ移行を進めています。
> このドキュメントでは新方式に対応した実装を説明します。

**メリット**:
- ✅ Flutter側のコード変更が**不要**
- ✅ Supabase Authの機能（パスワードリセット等）を継続利用可能
- ✅ **シークレット管理が不要**（公開鍵のみで検証）
- ✅ キーローテーションが容易
- ✅ Supabase推奨の方式

---

## 認証フロー

```
┌─────────────────────────────────────────────────────────────────────┐
│                        認証フローの全体像                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [Flutter App]                [Supabase Auth]           [Ktor API]  │
│       │                             │                        │      │
│       │  1. ログイン要求            │                        │      │
│       │  (email/password)           │                        │      │
│       │ ─────────────────────────▶ │                        │      │
│       │                             │                        │      │
│       │  2. JWT発行 (ES256署名)     │                        │      │
│       │ ◀───────────────────────── │                        │      │
│       │                             │                        │      │
│       │  3. APIリクエスト + JWT                              │      │
│       │  (Authorization: Bearer eyJ...)                      │      │
│       │ ─────────────────────────────────────────────────▶  │      │
│       │                                                      │      │
│       │                            4. JWKsから公開鍵取得     │      │
│       │                            5. 公開鍵でJWT検証        │      │
│       │                            6. user_id抽出           │      │
│       │                            7. 権限チェック           │      │
│       │                                                      │      │
│       │  8. レスポンス                                       │      │
│       │ ◀─────────────────────────────────────────────────  │      │
│       │                                                      │      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## JWKs（JSON Web Key Set）とは？

**Androidでの類似概念**: Google Play App Signingの公開鍵配布

Supabaseは各プロジェクトに**公開鍵を配布するエンドポイント**を提供しています：

```
GET https://{project-id}.supabase.co/auth/v1/.well-known/jwks.json
```

レスポンス例：
```json
{
  "keys": [
    {
      "kid": "key-id-here",    // キーID（JWTヘッダーと照合）
      "alg": "ES256",          // アルゴリズム（楕円曲線暗号）
      "kty": "EC",             // キータイプ
      "key_ops": ["verify"],   // 検証専用
      "crv": "P-256",          // 曲線の種類
      "x": "...",              // 公開鍵のX座標
      "y": "..."               // 公開鍵のY座標
    }
  ]
}
```

```
┌───────────────────────────────────────────────────────────────┐
│  🔐 JWKsの仕組み                                               │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Supabase Auth]                                               │
│    秘密鍵（非公開）でJWTに署名                                 │
│         │                                                      │
│         ▼                                                      │
│  [JWKsエンドポイント]                                          │
│    公開鍵を配布（誰でもアクセス可能）                          │
│         │                                                      │
│         ▼                                                      │
│  [Ktorサーバー]                                                │
│    公開鍵でJWTの署名を検証                                     │
│    → 署名が正しければ、Supabase Authが発行した本物のJWT        │
│                                                                 │
│  ✅ 公開鍵は漏れても問題なし（検証専用、署名能力なし）          │
│  ✅ シークレット管理のリスクがゼロ                              │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

---

## 実装手順

### Step 1: 依存関係追加

#### `server/build.gradle.kts` に追加

```kotlin
dependencies {
    // 既存の依存関係...
    
    // === 新規追加: JWT認証（JWKs対応） ===
    implementation("io.ktor:ktor-server-auth")
    implementation("io.ktor:ktor-server-auth-jwt")
    
    // JWKsから公開鍵を取得するためのライブラリ
    implementation("com.auth0:jwks-rsa:0.22.1")
}
```

**解説**:
- `ktor-server-auth-jwt`: Ktor標準のJWT認証プラグイン
- `jwks-rsa`: Auth0製のJWKs取得ライブラリ（キャッシュ・レート制限機能付き）

> [!NOTE]
> Ktor 3系では `ktor-server-auth` のようにプレフィックスが `ktor-` で始まります。
> 旧形式の `server-auth-jvm` は使用できません。

---

### Step 2: 環境変数設定

#### `server/.env` に追加

```bash
# 既存の設定...

# Supabase設定
SUPABASE_URL=https://xxxx.supabase.co
```

> [!TIP]
> **JWT Secretは不要！**
>
> JWKs方式では公開鍵で検証するため、`SUPABASE_JWT_SECRET`は不要です。
> シークレット管理のリスクがなくなります。

**SUPABASE_URLの確認方法**:
Supabase Dashboard → Project Settings → API → Project URL

---

### Step 3: 認証プラグイン設定 (JWKs方式)

#### `server/src/main/kotlin/com/cleaning/plugins/Authentication.kt`

```kotlin
package com.cleaning.plugins

import com.auth0.jwk.JwkProviderBuilder
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.*
import io.ktor.server.response.*
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * JWT認証設定 (ES256/ECC P-256 対応)
 * 
 * JWKsエンドポイントから公開鍵を取得してJWTを検証する
 * 
 * 💡 Android的に言うと:
 *    - OkHttp Interceptor でリクエスト前に認証を確認するのと同じ役割
 *    - ただし「トークンを付ける」のではなく「トークンを検証する」側
 */
fun Application.configureAuthentication() {
    val supabaseUrl = System.getenv("SUPABASE_URL")
        ?: throw IllegalStateException("SUPABASE_URL is not set")
    
    // ─────────────────────────────────────────────────────────────
    // 📦 JWKsプロバイダーの構築
    // ─────────────────────────────────────────────────────────────
    // 💡 JwkProviderBuilder:
    //    JWKsエンドポイントから公開鍵を取得し、キャッシュする仕組み
    //    毎回ネットワークアクセスするのは遅いので、キャッシュが重要
    val jwkProvider = JwkProviderBuilder(
        URL("$supabaseUrl/auth/v1/.well-known/jwks.json")
    )
        // キャッシュ設定: 最大10件、5分間保持
        // 💡 Supabaseはエッジで10分間キャッシュするため、5分は安全なマージン
        .cached(10, 5, TimeUnit.MINUTES)
        // レート制限: 1分間に最大10リクエスト（JWKsエンドポイントへの過剰アクセス防止）
        .rateLimited(10, 1, TimeUnit.MINUTES)
        .build()
    
    install(Authentication) {
        jwt("supabase-jwt") {
            realm = "cleaning-report-api"
            
            // ─────────────────────────────────────────────────────
            // 🔐 JWT検証器の設定（JwkProviderを使用）
            // ─────────────────────────────────────────────────────
            // 💡 Ktor 3系ではverifierにJwkProviderを直接渡せる
            //    第1引数: JwkProvider（公開鍵取得）
            //    第2引数: issuer（発行者チェック）
            verifier(jwkProvider, "$supabaseUrl/auth/v1") {
                // 時刻のずれを3秒まで許容
                acceptLeeway(3)
            }
            
            // ─────────────────────────────────────────────────────
            // ✅ JWTの内容を検証
            // ─────────────────────────────────────────────────────
            validate { credential ->
                // 有効期限チェック
                val expiresAt = credential.payload.expiresAt
                if (expiresAt != null && expiresAt.time < System.currentTimeMillis()) {
                    null  // 期限切れ → 認証失敗
                } else {
                    // subクレームからuser_idを取得
                    val userId = credential.payload.subject
                    if (userId != null) {
                        // 📌 JWTPrincipal: 認証済みユーザー情報を保持するオブジェクト
                        //    後続の処理でcall.principal<JWTPrincipal>()で取得可能
                        JWTPrincipal(credential.payload)
                    } else {
                        null  // user_idがない → 認証失敗
                    }
                }
            }
            
            // ─────────────────────────────────────────────────────
            // ❌ 認証失敗時のレスポンス
            // ─────────────────────────────────────────────────────
            challenge { _, _ ->
                call.respond(
                    HttpStatusCode.Unauthorized,
                    mapOf("error" to "Token is invalid or expired")
                )
            }
        }
    }
}
```

**コード解説（Android開発者向け）**:

| Ktorのコード | Androidで例えると |
|:---|:---|
| `JwkProviderBuilder` | `OkHttp`のキャッシュ設定 |
| `verifier(jwkProvider, issuer)` | JWTの署名を公開鍵で検証 |
| `acceptLeeway(3)` | 時刻のずれを許容（サーバー間の時計の誤差対策） |
| `JWTPrincipal` | 認証済みユーザー情報（IntentのExtra的な役割） |

**ポイント**:
- **Ktor 3系のAPI**: `verifier(jwkProvider, issuer)` の形式でJwkProviderを直接渡せる
- **キャッシュの重要性**: JWKsエンドポイントへの毎回アクセスは遅いのでキャッシュ必須

---

### 🏗️ 各コンポーネントの内部挙動詳細

#### 1. `install(Authentication) { }` - プラグインのインストール

```kotlin
install(Authentication) {
    // この中で認証方式を定義
}
```

**内部で起きること**:
```
┌───────────────────────────────────────────────────────────────┐
│  install(Authentication) の役割                               │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Ktorアプリケーションに「認証機能」を追加                   │
│     → Androidでいう Application.onCreate() で                  │
│       ライブラリを初期化するイメージ                           │
│                                                                 │
│  2. HTTPリクエストの「前処理パイプライン」に認証チェックを追加 │
│     → OkHttp Interceptor と似た仕組み                          │
│                                                                 │
│  リクエスト → [認証プラグイン] → [ルーティング] → レスポンス  │
│                    ↓                                           │
│              認証失敗なら                                       │
│              ここで401を返す                                    │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

---

#### 2. `jwt("supabase-jwt") { }` - 認証スキームの定義

```kotlin
jwt("supabase-jwt") {
    // JWTベースの認証設定
}
```

**"supabase-jwt" という名前の意味**:
```
┌───────────────────────────────────────────────────────────────┐
│  認証スキーム名の役割                                         │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  1つのアプリで複数の認証方式を持てる:                          │
│                                                                 │
│  install(Authentication) {                                      │
│      jwt("supabase-jwt") { ... }   // ユーザー向けJWT認証      │
│      jwt("admin-jwt") { ... }      // 管理者向け別JWT認証      │
│      basic("legacy-auth") { ... }  // レガシーBasic認証        │
│  }                                                              │
│                                                                 │
│  使い分け:                                                      │
│  authenticate("supabase-jwt") { ... }   // この認証を使う      │
│  authenticate("admin-jwt") { ... }      // こっちを使う        │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

---

#### 3. `realm = "cleaning-report-api"` - レルムの設定

```kotlin
realm = "cleaning-report-api"
```

**realmとは？**:
```
┌───────────────────────────────────────────────────────────────┐
│  realm（レルム）の役割                                        │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  HTTPの「WWW-Authenticate」ヘッダーに含まれる値               │
│                                                                 │
│  認証失敗時のレスポンス:                                       │
│  HTTP/1.1 401 Unauthorized                                      │
│  WWW-Authenticate: Bearer realm="cleaning-report-api"          │
│                                                                 │
│  用途:                                                          │
│  - 「どのサービスの認証か」を示す識別子                        │
│  - ブラウザがパスワード保存時に使う（今回はAPI用なので重要度低）│
│  - デバッグ時に「どの認証で弾かれたか」がわかりやすくなる      │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

---

#### 4. `JwkProviderBuilder` - 公開鍵プロバイダーの構築

```kotlin
val jwkProvider = JwkProviderBuilder(
    URL("$supabaseUrl/auth/v1/.well-known/jwks.json")
)
    .cached(10, 5, TimeUnit.MINUTES)
    .rateLimited(10, 1, TimeUnit.MINUTES)
    .build()
```

**各メソッドの意味**:
```
┌───────────────────────────────────────────────────────────────┐
│  JwkProviderBuilder の構築パターン                            │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  JwkProviderBuilder(URL)                                        │
│    └─ JWKsエンドポイントのURLを指定                            │
│                                                                 │
│  .cached(10, 5, TimeUnit.MINUTES)                               │
│    └─ キャッシュ設定                                           │
│       ・10 = 最大10個のキーをキャッシュ                        │
│       ・5 = 5分間キャッシュを保持                              │
│       ・なぜ必要？ → 毎リクエストでHTTPアクセスは遅すぎる      │
│                                                                 │
│  .rateLimited(10, 1, TimeUnit.MINUTES)                          │
│    └─ レート制限                                                │
│       ・10 = 1分間に最大10回までJWKsエンドポイントにアクセス   │
│       ・なぜ必要？ → キャッシュミス時の連続アクセスを防止      │
│                      DoS攻撃からSupabaseを守る                  │
│                                                                 │
│  .build()                                                       │
│    └─ 設定を確定してJwkProviderインスタンスを生成              │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

---

#### 5. `validate { credential -> }` - カスタム検証ロジック

```kotlin
validate { credential ->
    // JWTPrincipal を返せば認証成功
    // null を返せば認証失敗
}
```

**validateが呼ばれるタイミング**:
```
┌───────────────────────────────────────────────────────────────┐
│  認証の全体フロー                                             │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  リクエスト受信                                                 │
│       ↓                                                        │
│  [verifier] JWT署名を公開鍵で検証                              │
│       ↓ ✅ 署名OK                                              │
│  [validate] ← ここで呼ばれる                                   │
│       │                                                         │
│       ├─ JWTPrincipal を返す → 認証成功 → ルートハンドラへ     │
│       └─ null を返す → 認証失敗 → challenge へ                 │
│                                                                 │
│  💡 verifierは「署名が正しいか」だけを見る                     │
│     validateは「内容が正しいか」を追加でチェックできる         │
│                                                                 │
│  例:                                                            │
│  - 有効期限の独自チェック                                       │
│  - 特定のclaimが存在するかチェック                              │
│  - ユーザーがDBで無効化されていないかチェック                   │
│  - 特定のロールを持っているかチェック                           │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

**credential.payload の中身**:
```kotlin
credential.payload.subject      // "sub" = ユーザーID (UUID)
credential.payload.issuer       // "iss" = 発行者URL
credential.payload.expiresAt    // "exp" = 有効期限
credential.payload.getClaim("email")    // カスタムクレーム
credential.payload.getClaim("role")     // カスタムクレーム
```

---

#### 6. `challenge { _, _ -> }` - 認証失敗時の処理

```kotlin
challenge { defaultScheme, realm ->
    call.respond(
        HttpStatusCode.Unauthorized,
        mapOf("error" to "Token is invalid or expired")
    )
}
```

**challengeが呼ばれるタイミング**:
```
┌───────────────────────────────────────────────────────────────┐
│  challenge が呼ばれる3つのケース                              │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Authorizationヘッダーがない                                │
│     → 「トークンを送ってください」という応答                   │
│                                                                 │
│  2. verifierで署名検証に失敗                                   │
│     → 「トークンが無効です」という応答                        │
│                                                                 │
│  3. validateでnullを返した                                      │
│     → 「トークンは正しいが条件を満たさない」という応答        │
│                                                                 │
│  💡 challengeを定義しないと、デフォルトで                      │
│     401 Unauthorized + WWW-Authenticate ヘッダーが返る         │
│                                                                 │
│  💡 カスタムchallengeでJSON形式のエラーを返すと                │
│     クライアント（Flutter）側でパースしやすい                  │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

**引数の意味**:
```kotlin
challenge { defaultScheme, realm ->
    // defaultScheme = "Bearer" (JWT認証の場合)
    // realm = 上で設定した "cleaning-report-api"
    // 今回は使わないので _ にしている
}
```

### 🔍 ライブラリ内部で行われている処理

`verifier(jwkProvider, issuer)` は1行でシンプルですが、内部では以下の処理が自動的に行われています：

```
┌─────────────────────────────────────────────────────────────────────┐
│  verifier(jwkProvider, issuer) の内部処理                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1️⃣ リクエストからJWTを抽出                                        │
│     Authorization: Bearer eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9...    │
│                           ↓                                         │
│                    「Bearer 」を除去してトークン部分を取得           │
│                                                                      │
│  2️⃣ JWTヘッダーをデコードしてkid（Key ID）を取得                   │
│     { "alg": "ES256", "kid": "abc123", "typ": "JWT" }               │
│                           ↓                                         │
│                    kid = "abc123" を抽出                            │
│                                                                      │
│  3️⃣ kidに対応する公開鍵をJWKsから取得                              │
│     JwkProvider.get("abc123")                                        │
│           │                                                          │
│           ├─ キャッシュにあれば → キャッシュから返す（高速）        │
│           └─ なければ → JWKsエンドポイントにHTTPリクエスト          │
│                         GET https://xxx.supabase.co/.../jwks.json   │
│                                                                      │
│  4️⃣ 公開鍵で署名を検証                                             │
│     ┌──────────────┐     ┌──────────────┐                           │
│     │ JWTの署名     │ === │ 公開鍵で     │ → 一致すれば本物        │
│     │ (トークン末尾) │     │ 計算した値   │ → 不一致なら偽物        │
│     └──────────────┘     └──────────────┘                           │
│                                                                      │
│  5️⃣ issuer（発行者）をチェック                                     │
│     iss == "https://xxx.supabase.co/auth/v1" か確認                  │
│     → 一致すればOK、違えば401エラー                                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

#### 手動で書くとこうなる

ライブラリがなければ、以下のようなコードを自分で書く必要があります：

```kotlin
// ⚠️ これは説明用の擬似コード（実際には書く必要なし）

fun verifyJwtManually(authorizationHeader: String): JWTPrincipal? {
    // 1️⃣ Authorization ヘッダーからトークンを抽出
    val token = authorizationHeader.removePrefix("Bearer ")
    
    // 2️⃣ JWTをデコードしてヘッダーを読む
    val decodedJwt = JWT.decode(token)
    val kid = decodedJwt.keyId 
        ?: throw Exception("JWT does not contain kid")
    val algorithm = decodedJwt.algorithm  // "ES256"
    
    // 3️⃣ JWKsエンドポイントから公開鍵を取得
    //    （本来はキャッシュも実装する必要あり）
    val jwksUrl = "https://xxx.supabase.co/auth/v1/.well-known/jwks.json"
    val jwksResponse = httpClient.get(jwksUrl)
    val keys = parseJwks(jwksResponse)
    val jwk = keys.find { it.kid == kid }
        ?: throw Exception("Key not found")
    
    // 4️⃣ 公開鍵を取り出してJava用に変換
    val publicKey = when (jwk.kty) {
        "EC" -> {
            val x = Base64.decode(jwk.x)
            val y = Base64.decode(jwk.y)
            // ECPublicKey を構築...（複雑な処理）
        }
        "RSA" -> { /* RSAPublicKeyを構築 */ }
    }
    
    // 5️⃣ 署名を検証
    val verifier = JWT.require(Algorithm.ECDSA256(publicKey, null))
        .withIssuer("https://xxx.supabase.co/auth/v1")
        .build()
    
    val verified = verifier.verify(token)
    
    // 6️⃣ 有効期限チェック
    if (verified.expiresAt < Date()) {
        throw Exception("Token expired")
    }
    
    return JWTPrincipal(verified)
}
```

#### ライブラリが提供する価値

| 自分で実装すると... | ライブラリを使うと |
|:---|:---|
| JWKsエンドポイントへのHTTPリクエスト実装 | 自動 |
| 公開鍵のキャッシュ管理 | `.cached()` で設定 |
| レート制限 | `.rateLimited()` で設定 |
| EC/RSA公開鍵のパース処理 | 自動 |
| kid による鍵の選択 | 自動 |
| 署名アルゴリズムの判定（ES256/RS256等） | 自動 |
| issuer/有効期限のチェック | 設定するだけ |

**つまり**: 1行の `verifier(jwkProvider, issuer)` には、約50〜100行分のボイラープレートコードが隠蔽されています。

### Step 4: ユーザー情報取得ヘルパー

#### `server/src/main/kotlin/com/cleaning/auth/AuthExtensions.kt`

```kotlin
package com.cleaning.auth

import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.*
import java.util.UUID

/**
 * 認証済みリクエストからユーザーIDを取得
 */
fun ApplicationCall.getUserId(): UUID {
    val principal = principal<JWTPrincipal>()
        ?: throw IllegalStateException("No JWT principal found")
    
    val userId = principal.payload.subject
        ?: throw IllegalStateException("No user ID in token")
    
    return UUID.fromString(userId)
}

/**
 * ユーザーロールを取得
 */
fun ApplicationCall.getUserRole(): String {
    val principal = principal<JWTPrincipal>()
        ?: throw IllegalStateException("No JWT principal found")
    
    // Supabase JWTのapp_metadataからロールを取得
    val appMetadata = principal.payload.getClaim("app_metadata").asMap()
    return appMetadata?.get("role")?.toString() ?: "staff"
}

/**
 * 管理者かどうかチェック
 */
fun ApplicationCall.isAdmin(): Boolean {
    return getUserRole() == "admin"
}
```

**解説**:
- `principal<JWTPrincipal>()`: 認証情報を取得
- `payload.subject`: SupabaseではこれがユーザーID
- `app_metadata.role`: Supabaseのカスタムロール

---

### 🔍 AuthExtensions.kt の各コンポーネント詳細

#### 1. `ApplicationCall` - リクエストコンテキスト

```kotlin
import io.ktor.server.application.ApplicationCall

fun ApplicationCall.getUserId(): UUID { ... }
```

**ApplicationCallとは？**:
```
┌───────────────────────────────────────────────────────────────┐
│  ApplicationCall の役割                                       │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  1つのHTTPリクエスト/レスポンスサイクル全体を表すオブジェクト │
│                                                                 │
│  Androidで例えると:                                             │
│  - Activity の Intent + Context を合わせたようなもの          │
│  - リクエストに関する全情報を持っている                        │
│                                                                 │
│  ApplicationCall が持つ情報:                                    │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ call.request     │ HTTPリクエスト情報                   │  │
│  │   .headers       │   → ヘッダー（Authorization等）      │  │
│  │   .queryParameters │ → クエリパラメータ(?month=2026-01)│  │
│  │   .uri           │   → リクエストURI                    │  │
│  ├─────────────────────────────────────────────────────────┤  │
│  │ call.response    │ HTTPレスポンス設定                   │  │
│  │   .status()      │   → ステータスコード設定             │  │
│  │   .headers       │   → レスポンスヘッダー               │  │
│  ├─────────────────────────────────────────────────────────┤  │
│  │ call.parameters  │ URLパスパラメータ（/reports/{id}）  │  │
│  ├─────────────────────────────────────────────────────────┤  │
│  │ call.principal() │ 認証情報（後述）                     │  │
│  ├─────────────────────────────────────────────────────────┤  │
│  │ call.attributes  │ リクエストスコープの一時データ       │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

**なぜ拡張関数にするか？**:
```kotlin
// 拡張関数なし（毎回書く）
val principal = call.principal<JWTPrincipal>()
val userId = UUID.fromString(principal!!.payload.subject)

// 拡張関数あり（シンプル）
val userId = call.getUserId()
```

---

#### 2. `JWTPrincipal` - JWT認証情報コンテナ

```kotlin
import io.ktor.server.auth.jwt.JWTPrincipal

val principal = principal<JWTPrincipal>()
```

**JWTPrincipalとは？**:
```
┌───────────────────────────────────────────────────────────────┐
│  JWTPrincipal の構造                                          │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  認証成功後、validateブロックで作成されるオブジェクト         │
│                                                                 │
│  validate { credential ->                                       │
│      JWTPrincipal(credential.payload)  // ← ここで作成        │
│  }                                                              │
│                                                                 │
│  JWTPrincipal                                                   │
│  └── payload: Payload                                           │
│       ├── subject    │ "sub" クレーム = ユーザーID (UUID)     │
│       ├── issuer     │ "iss" クレーム = 発行者URL             │
│       ├── audience   │ "aud" クレーム = 対象サービス          │
│       ├── expiresAt  │ "exp" クレーム = 有効期限              │
│       ├── issuedAt   │ "iat" クレーム = 発行時刻              │
│       └── getClaim() │ カスタムクレームを取得                 │
│                                                                 │
│  💡 Kotlinの「Principal」= 認証されたエンティティを表す       │
│     英語で「主体」「本人」という意味                           │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

**Supabase JWTのペイロード例**:
```json
{
  "sub": "12345678-1234-1234-1234-123456789012",  // ユーザーID
  "iss": "https://xxx.supabase.co/auth/v1",      // 発行者
  "aud": "authenticated",                         // 対象
  "exp": 1705555200,                              // 有効期限
  "iat": 1705551600,                              // 発行時刻
  "email": "user@example.com",                    // カスタム
  "role": "authenticated",                        // Supabaseロール
  "app_metadata": {                               // アプリ固有データ
    "role": "admin"
  }
}
```

---

#### 3. `principal<T>()` - 認証情報の取得

```kotlin
import io.ktor.server.auth.principal

val principal = principal<JWTPrincipal>()
```

**principal()の内部動作**:
```
┌───────────────────────────────────────────────────────────────┐
│  principal<T>() の仕組み                                      │
├───────────────────────────────────────────────────────────────┤
│                                                                 │
│  リクエスト処理の流れ:                                         │
│                                                                 │
│  1. リクエスト受信                                             │
│       ↓                                                        │
│  2. Authentication プラグインが JWT を検証                     │
│       ↓                                                        │
│  3. validate { } で JWTPrincipal を作成                        │
│       ↓                                                        │
│  4. JWTPrincipal を call.attributes に保存  ← 内部で自動      │
│       ↓                                                        │
│  5. ルートハンドラで call.principal<JWTPrincipal>() を呼ぶ    │
│       ↓                                                        │
│  6. call.attributes から JWTPrincipal を取り出して返す        │
│                                                                 │
│  💡 型パラメータ <JWTPrincipal> で安全にキャスト               │
│     → 間違った型を指定すると null が返る                       │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

**なぜ型パラメータが必要？**:
```kotlin
// Ktorは複数の認証方式をサポート
jwt("supabase-jwt") { ... }       // → JWTPrincipal
basic("legacy-auth") { ... }      // → UserIdPrincipal
oauth("google") { ... }           // → OAuthAccessTokenResponse

// どの型で取得するか明示する必要がある
val jwt = principal<JWTPrincipal>()           // JWT認証の場合
val basic = principal<UserIdPrincipal>()      // Basic認証の場合
```

**nullが返るケース**:
```kotlin
val principal = principal<JWTPrincipal>()
// principal が null になるのは:
// 1. authenticate { } ブロック外で呼んだ
// 2. 認証に失敗した（通常は challenge に行くので来ない）
// 3. 違う型を指定した（JWTPrincipal以外）
```

---

#### 4. 全体の流れまとめ

```
┌─────────────────────────────────────────────────────────────────────┐
│  リクエストからユーザーID取得までの全フロー                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [Flutter] → Authorization: Bearer eyJhbG...                        │
│                    ↓                                                 │
│  [Ktor] Authentication プラグイン                                   │
│         │                                                            │
│         ├─ JWKsから公開鍵取得                                       │
│         ├─ 署名検証 (verifier)                                      │
│         └─ ペイロード検証 (validate)                                │
│                    ↓                                                 │
│         JWTPrincipal(payload) を作成して attributes に保存          │
│                    ↓                                                 │
│  [ルートハンドラ] get("/api/v1/reports") { ... }                    │
│         │                                                            │
│         └─ call.getUserId()                                         │
│              │                                                       │
│              ├─ call.principal<JWTPrincipal>()                      │
│              │     └─ attributes から JWTPrincipal を取得           │
│              │                                                       │
│              ├─ principal.payload.subject                           │
│              │     └─ "sub" クレーム = "12345-abcd-..."             │
│              │                                                       │
│              └─ UUID.fromString(...)                                │
│                    └─ UUID型に変換して返す                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Step 5: Application.kt更新

#### `server/src/main/kotlin/com/cleaning/Application.kt`

```kotlin
package com.cleaning

import com.cleaning.database.DatabaseFactory
import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import com.cleaning.plugins.*

fun main() {
    DatabaseFactory.init()
    
    val port = System.getenv("PORT")?.toInt() ?: 8080
    
    embeddedServer(Netty, port = port, host = "0.0.0.0") {
        configureKoin()
        configureAuthentication()  // 追加: 認証設定
        configureRouting()
        configureSerialization()
    }.start(wait = true)
}
```

---

### Step 6: APIルートに認証を適用

#### `server/src/main/kotlin/com/cleaning/routes/ReportRoutes.kt` を更新

```kotlin
package com.cleaning.routes

import com.cleaning.auth.getUserId
import com.cleaning.auth.isAdmin
import com.cleaning.models.*
import com.cleaning.repositories.ReportRepository
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import org.koin.ktor.ext.inject
import java.time.LocalDate

fun Route.reportRoutes() {
    val reportRepository by inject<ReportRepository>()
    
    // 認証が必要なルート
    authenticate("supabase-jwt") {
        route("/api/v1/reports") {
            
            // GET /api/v1/reports?month=2026-01
            get {
                val month = call.parameters["month"]
                if (month == null) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "month parameter is required"))
                    return@get
                }
                
                // JWTからユーザーIDを取得
                val userId = call.getUserId()
                
                val reports = reportRepository.findByMonth(month, userId)
                call.respond(reports.map { it.toDto() })
            }
            
            // POST /api/v1/reports
            post {
                val request = call.receive<CreateReportRequest>()
                val userId = call.getUserId()
                
                val date = LocalDate.parse(request.date)
                val month = "${date.year}-${date.monthValue.toString().padStart(2, '0')}"
                
                val report = Report(
                    id = java.util.UUID.randomUUID(),
                    userId = userId,
                    date = date,
                    type = ReportType.valueOf(request.type),
                    item = request.item,
                    unitPrice = request.unitPrice,
                    duration = request.duration,
                    amount = request.amount,
                    note = request.note,
                    month = month,
                    createdAt = java.time.LocalDateTime.now(),
                    updatedAt = null
                )
                
                val created = reportRepository.create(report)
                call.respond(HttpStatusCode.Created, created.toDto())
            }
            
            // PUT /api/v1/reports/{id}
            put("/{id}") {
                val id = call.parameters["id"]?.let { java.util.UUID.fromString(it) }
                if (id == null) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Invalid ID"))
                    return@put
                }
                
                val existing = reportRepository.findById(id)
                if (existing == null) {
                    call.respond(HttpStatusCode.NotFound, mapOf("error" to "Report not found"))
                    return@put
                }
                
                // 権限チェック: 自分のレポートまたは管理者のみ編集可能
                val userId = call.getUserId()
                if (existing.userId != userId && !call.isAdmin()) {
                    call.respond(HttpStatusCode.Forbidden, mapOf("error" to "Not authorized"))
                    return@put
                }
                
                val request = call.receive<CreateReportRequest>()
                val date = LocalDate.parse(request.date)
                val month = "${date.year}-${date.monthValue.toString().padStart(2, '0')}"
                
                val updated = reportRepository.update(
                    existing.copy(
                        date = date,
                        type = ReportType.valueOf(request.type),
                        item = request.item,
                        unitPrice = request.unitPrice,
                        duration = request.duration,
                        amount = request.amount,
                        note = request.note,
                        month = month
                    )
                )
                
                call.respond(updated.toDto())
            }
            
            // DELETE /api/v1/reports/{id}
            delete("/{id}") {
                val id = call.parameters["id"]?.let { java.util.UUID.fromString(it) }
                if (id == null) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Invalid ID"))
                    return@delete
                }
                
                val existing = reportRepository.findById(id)
                if (existing == null) {
                    call.respond(HttpStatusCode.NotFound, mapOf("error" to "Report not found"))
                    return@delete
                }
                
                // 権限チェック
                val userId = call.getUserId()
                if (existing.userId != userId && !call.isAdmin()) {
                    call.respond(HttpStatusCode.Forbidden, mapOf("error" to "Not authorized"))
                    return@delete
                }
                
                reportRepository.delete(id)
                call.respond(HttpStatusCode.NoContent)
            }
        }
    }
}
```

**主な変更点**:
- `authenticate("supabase-jwt") { }` でルート全体を保護
- `call.getUserId()` でJWTからユーザーID取得
- `call.isAdmin()` で権限チェック

---

### Step 7: 管理者用ルート追加（オプション）

#### `server/src/main/kotlin/com/cleaning/routes/AdminRoutes.kt`

```kotlin
package com.cleaning.routes

import com.cleaning.auth.getUserId
import com.cleaning.auth.isAdmin
import com.cleaning.models.toDto
import com.cleaning.repositories.ReportRepository
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import org.koin.ktor.ext.inject

fun Route.adminRoutes() {
    val reportRepository by inject<ReportRepository>()
    
    authenticate("supabase-jwt") {
        route("/api/v1/admin") {
            
            // 全ユーザーのレポート取得（管理者のみ）
            get("/reports") {
                if (!call.isAdmin()) {
                    call.respond(HttpStatusCode.Forbidden, mapOf("error" to "Admin only"))
                    return@get
                }
                
                val month = call.parameters["month"]
                if (month == null) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "month is required"))
                    return@get
                }
                
                // TODO: 全ユーザーのレポート取得メソッドをリポジトリに追加
                call.respond(mapOf("message" to "Not implemented yet"))
            }
        }
    }
}
```

---

### Step 8: 動作確認

動作確認には3つの方法があります。**オプションA（ローカル直接実行）** が最も簡単です。

---

#### オプションA: ローカルで直接実行（推奨）

Gradleで直接サーバーを起動します。DBはSupabaseのものをリモートで使用。

```bash
# 1. serverディレクトリに移動
cd /Users/kuwa/Develop/studio/cleaning-report/server

# 2. 環境変数を設定（.envファイルから読み込む場合）
export $(cat .env | grep -v '^#' | xargs)

# または個別に設定
export DATABASE_URL="jdbc:postgresql://xxx.supabase.co:5432/postgres?user=postgres&password=YOUR_PASSWORD"
export SUPABASE_URL="https://xxx.supabase.co"

# 3. サーバー起動
./gradlew run
```

**起動成功時の出力**:
```
[main] INFO Application - Responding at http://0.0.0.0:8080
```

---

#### オプションB: Dockerで実行

```bash
# 1. serverディレクトリに移動
cd /Users/kuwa/Develop/studio/cleaning-report/server

# 2. Fat JARをビルド
./gradlew buildFatJar

# 3. Dockerイメージをビルド（Apple Silicon Macの場合）
docker build --platform linux/amd64 -t cleaning-report-server .

# 4. コンテナを起動
docker run -p 8080:8080 \
  -e DATABASE_URL="jdbc:postgresql://xxx.supabase.co:5432/postgres?user=postgres&password=YOUR_PASSWORD" \
  -e SUPABASE_URL="https://xxx.supabase.co" \
  cleaning-report-server
```

---

#### オプションC: Cloud Runにデプロイ

```bash
# 1. serverディレクトリに移動
cd /Users/kuwa/Develop/studio/cleaning-report/server

# 2. Fat JARをビルド
./gradlew buildFatJar

# 3. Cloud Runにデプロイ
gcloud run deploy cleaning-report-api \
  --source . \
  --platform managed \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --set-env-vars "DATABASE_URL=jdbc:postgresql://xxx.supabase.co:5432/postgres?user=postgres&password=YOUR_PASSWORD" \
  --set-env-vars "SUPABASE_URL=https://xxx.supabase.co"
```

---

#### JWTトークンの取得方法

テスト用のJWTトークンを取得する方法は2つあります：

**方法1: Flutterアプリから取得（推奨）**

デバッグビルドのアプリでログインし、以下のコードでトークンを取得：

```dart
// Flutterのデバッグコンソールに出力
final token = Supabase.instance.client.auth.currentSession?.accessToken;
print('JWT Token: $token');
```

> [!TIP]
> VS Codeのデバッグコンソールからトークンをコピーできます

**方法2: Supabase Dashboard から直接取得**

1. Supabase Dashboard → Authentication → Users
2. 該当ユーザーの「...」メニュー → 「Generate access token」
3. トークンをコピー

---

#### APIテスト（curl）

```bash
# ─────────────────────────────────────────────────────────────
# テスト1: トークンなしでアクセス → 401エラーになるはず
# ─────────────────────────────────────────────────────────────
curl -s http://localhost:8080/api/v1/reports?month=2026-01 | jq .

# 期待する結果:
# {
#   "error": "Token is invalid or expired"
# }

# ─────────────────────────────────────────────────────────────
# テスト2: 有効なトークンでアクセス → 200でデータ取得
# ─────────────────────────────────────────────────────────────
# まずトークンを変数に設定
JWT_TOKEN="eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6Inh4eC..."

# GETリクエスト
curl -s http://localhost:8080/api/v1/reports?month=2026-01 \
  -H "Authorization: Bearer $JWT_TOKEN" | jq .

# 期待する結果:
# [] または レポートデータの配列

# ─────────────────────────────────────────────────────────────
# テスト3: ヘルスチェック（認証不要）
# ─────────────────────────────────────────────────────────────
curl -s http://localhost:8080/health | jq .

# 期待する結果:
# {
#   "status": "healthy"
# }

# ─────────────────────────────────────────────────────────────
# テスト4: 無効なトークンでアクセス → 401エラー
# ─────────────────────────────────────────────────────────────
curl -s http://localhost:8080/api/v1/reports?month=2026-01 \
  -H "Authorization: Bearer invalid_token_here" | jq .

# 期待する結果:
# {
#   "error": "Token is invalid or expired"
# }
```

---

#### トラブルシューティング

| 症状 | 原因と対策 |
|:---|:---|
| **`SUPABASE_URL is not set`** | 環境変数が設定されていない。`export SUPABASE_URL=...` を実行 |
| **`Connection refused`** | サーバーが起動していない。`./gradlew run` を確認 |
| **`401` が返る（正常なトークンで）** | SUPABASE_URLが間違っている可能性。issuerと一致するか確認 |
| **`SigningKeyNotFoundException`** | JWKsエンドポイントにアクセスできない。URLを確認 |
| **`Token expired`** | JWTの有効期限切れ（デフォルト1時間）。新しいトークンを取得 |

## ディレクトリ構成（Phase 3.3完了後）

```
server/src/main/kotlin/com/cleaning/
├── Application.kt
├── auth/
│   └── AuthExtensions.kt         # NEW: 認証ヘルパー（拡張関数）
├── di/
│   └── AppModule.kt
├── database/
│   ├── DatabaseFactory.kt
│   └── tables/
│       └── ReportsTable.kt
├── models/
│   └── Report.kt
├── plugins/
│   ├── Authentication.kt        # NEW: JWT認証
│   ├── Koin.kt
│   ├── Routing.kt
│   └── Serialization.kt
├── repositories/
│   └── ReportRepository.kt
└── routes/
    ├── AdminRoutes.kt           # NEW: 管理者API
    ├── HealthRoute.kt
    └── ReportRoutes.kt          # 認証追加
```

---

## 成功基準チェックリスト

- [ ] JWTなしのリクエストが401エラーになる
- [ ] 有効なJWTでuser_idが正しく取得できる
- [ ] 自分のレポートのみ取得/編集/削除できる
- [ ] 管理者は全レポートにアクセスできる

---

## トラブルシューティング

### Q: JWTが常に無効と判定される

**A**: 以下を確認:

1. **JWKsエンドポイントにアクセスできるか**
   ```bash
   curl https://xxxx.supabase.co/auth/v1/.well-known/jwks.json
   ```
   → `keys`配列が返ってくればOK

2. **トークンの有効期限が切れていないか**
   - 期限確認: [jwt.io](https://jwt.io) でトークンをデコードして`exp`を確認

3. **Issuerの形式が正しいか**
   - 形式: `https://xxx.supabase.co/auth/v1`
   - サーバー側の`SUPABASE_URL`と一致しているか

4. **kidが含まれているか**
   - ES256トークンには`kid`（Key ID）が必須
   - jwt.ioのヘッダーで`kid`を確認

### Q: 「JWT does not contain kid」エラー

**A**: Supabaseの新しいJWT Signing Keys（ECC P-256）が有効になっていない可能性があります。

Supabase Dashboard → Project Settings → API → JWT Keys タブ で、
「JWT Signing Keys」が有効（CURRENT KEY に ECC P-256 が表示）であることを確認してください。

### Q: キーローテーション後にJWTが無効になる

**A**: JWKsエンドポイントのキャッシュが原因の可能性があります。

- Supabaseはエッジで10分間キャッシュ
- サーバー側も5分間キャッシュ

**対策**: キーをローテーションする際は、**20分以上待ってから**旧キーを無効化してください。

### Q: app_metadataにroleがない

**A**: Supabaseでユーザー作成時にapp_metadataを設定:
```sql
UPDATE auth.users 
SET raw_app_meta_data = '{"role": "admin"}'::jsonb 
WHERE email = 'admin@example.com';
```

---

## 次のステップ

Phase 3.3が完了したら、[Phase 3.4: Flutter側接続切り替え](./Phase3.4_Flutter接続切替.md)に進んでください。
