# JWT検証実装 理解度チェックリスト

認証チームの仕組みを理解するための、JWT検証の実装詳細に焦点を当てたチェックリストです。
※ OAuth/OIDC/SAMLのプロトコル概念は `auth_sso_oauth_oidc_saml_checklist.md` を参照

---

## 📚 セクション1: JWTの構造

### Q1. JWTの3つのパートは？

- A) Header, Payload, Signature
- B) Token, Key, Value
- C) User, Role, Permission
- D) Request, Response, Error

<details>
<summary>答えを見る</summary>

**正解: A**

```
eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.signature
└── Header ──────┘└── Payload ─────┘└─ Signature ─┘
```

| パート | 内容 |
|---|---|
| **Header** | アルゴリズム、トークンタイプ |
| **Payload** | クレーム（ユーザー情報、有効期限等） |
| **Signature** | 改ざん検証用の署名 |

</details>

---

### Q2. JWTの標準クレームで「有効期限」を表すのは？

- A) exp
- B) iat
- C) sub
- D) aud

<details>
<summary>答えを見る</summary>

**正解: A**

| クレーム | 意味 |
|---|---|
| **sub** | Subject（ユーザーID） |
| **exp** | Expiration（有効期限） |
| **iat** | Issued At（発行日時） |
| **aud** | Audience（対象者） |
| **iss** | Issuer（発行者） |

```kotlin
// Ktor での検証
jwt {
    validate { credential ->
        if (credential.expiresAt?.before(Date()) == true) {
            null  // 期限切れ
        } else {
            JWTPrincipal(credential.payload)
        }
    }
}
```

</details>

---

### Q3. JWTのSignature（署名）の目的は？

- A) データの暗号化
- B) トークンの改ざん検出
- C) トークンの圧縮
- D) ユーザー認証

<details>
<summary>答えを見る</summary>

**正解: B**

**重要:** JWTは暗号化ではない。Base64エンコードなので誰でも中身を読める。

署名の検証フロー:
1. Header + Payload + 秘密鍵で署名を再計算
2. 受け取った署名と比較
3. 一致すれば改ざんなし

</details>

---

## 📚 セクション2: 署名アルゴリズム

### Q4. HS256とRS256/ES256の違いは？

- A) 同じアルゴリズム
- B) HS256は暗号化、RS256は署名
- C) HS256は共通鍵、RS256/ES256は公開鍵/秘密鍵のペア
- D) HS256は古い、RS256は新しい

<details>
<summary>答えを見る</summary>

**正解: C**

| アルゴリズム | 種類 | 鍵 |
|---|---|---|
| **HS256** | HMAC-SHA256（対称鍵） | 共通の秘密鍵 |
| **RS256** | RSA-SHA256（非対称鍵） | 公開鍵/秘密鍵ペア |
| **ES256** | ECDSA-SHA256（非対称鍵） | 公開鍵/秘密鍵ペア |

**使い分け:**
- **HS256**: 発行者と検証者が同じ（シンプル）
- **RS256/ES256**: 発行者と検証者が異なる（IdP → RP）

</details>

---

### Q5. 非対称鍵（RS256/ES256）で、秘密鍵と公開鍵の役割は？

- A) 秘密鍵で検証、公開鍵で署名
- B) 秘密鍵で署名、公開鍵で検証
- C) どちらでも署名・検証可能
- D) 両方とも同じ鍵

<details>
<summary>答えを見る</summary>

**正解: B**

| 鍵 | 保持者 | 用途 |
|---|---|---|
| **秘密鍵** | IdP（認証サーバー） | JWT署名 |
| **公開鍵** | RP（サービス側） | 署名検証 |

**Ktor での検証（ES256の例）:**
```kotlin
val publicKey = loadPublicKey()  // IdPから取得
jwt {
    verifier(JWT.require(Algorithm.ECDSA256(publicKey, null)).build())
}
```

</details>

---

### Q6. JWKSエンドポイントの目的は？

- A) JWTを発行する
- B) ユーザー情報を取得する
- C) トークンを失効させる
- D) 公開鍵を安全に配布する

<details>
<summary>答えを見る</summary>

**正解: D**

**JWKS (JSON Web Key Set):**
```json
{
  "keys": [
    {
      "kty": "EC",
      "kid": "key-id-1",
      "crv": "P-256",
      "x": "...",
      "y": "..."
    }
  ]
}
```

**メリット:**
- 鍵のローテーションが容易
- `kid`で使用する鍵を特定
- 公開鍵をハードコードしなくて済む

```kotlin
// Ktor でのJWKS検証
val jwkProvider = JwkProviderBuilder(issuerUrl)
    .cached(10, 24, TimeUnit.HOURS)
    .build()
```

</details>

---

## 📚 セクション3: Ktorでの実装

### Q7. Ktor でJWT認証を設定する際の基本構成は？

- A) `install(Sessions)`
- B) `install(Authentication)` + `jwt { ... }`
- C) `install(Auth)`
- D) `install(JWT)`

<details>
<summary>答えを見る</summary>

**正解: B**

```kotlin
install(Authentication) {
    jwt("auth-jwt") {
        realm = "my-app"
        verifier(jwtVerifier)
        validate { credential ->
            if (credential.payload.subject != null) {
                JWTPrincipal(credential.payload)
            } else null
        }
        challenge { _, _ ->
            call.respond(HttpStatusCode.Unauthorized)
        }
    }
}
```

</details>

---

### Q8. Ktorの`validate`ブロックで`null`を返すとどうなる？

- A) 認証失敗（challengeが呼ばれる）
- B) 認証成功
- C) エラーログが出力される
- D) 何も起きない

<details>
<summary>答えを見る</summary>

**正解: A**

```kotlin
validate { credential ->
    // 検証ロジック
    if (isValid(credential)) {
        JWTPrincipal(credential.payload)  // 認証成功
    } else {
        null  // 認証失敗 → challenge実行
    }
}

challenge { _, _ ->
    call.respond(HttpStatusCode.Unauthorized, "Token invalid")
}
```

</details>

---

### Q9. 認証済みユーザー情報をルート内で取得する方法は？

- A) `call.request.user`
- B) `call.principal<JWTPrincipal>()`
- C) `call.authentication.user`
- D) `call.session.user`

<details>
<summary>答えを見る</summary>

**正解: B**

```kotlin
authenticate("auth-jwt") {
    get("/me") {
        val principal = call.principal<JWTPrincipal>()
        val userId = principal?.subject
        val email = principal?.payload?.getClaim("email")?.asString()
        
        call.respond(mapOf("userId" to userId, "email" to email))
    }
}
```

</details>

---

## 📚 セクション4: セキュリティ考慮事項

### Q10. JWT検証で必ず確認すべき項目は？

- A) 署名のみ
- B) ユーザー名のみ
- C) 署名、有効期限、audience、issuer
- D) トークンの長さ

<details>
<summary>答えを見る</summary>

**正解: C**

| 検証項目 | 理由 |
|---|---|
| **署名** | 改ざん検出 |
| **exp** | 期限切れトークン拒否 |
| **aud** | 他サービス宛のトークン拒否 |
| **iss** | 信頼するIdPからの発行確認 |

```kotlin
JWT.require(algorithm)
    .withIssuer("https://my-idp.example.com")
    .withAudience("my-service")
    .build()
```

</details>

---

### Q11. Access TokenとRefresh Tokenの違いは？

- A) 同じ目的
- B) Access Tokenは長命、Refresh Tokenは短命
- C) Refresh Tokenはクライアントで生成
- D) Access TokenはAPI呼び出し用（短命）、Refresh Tokenは更新用（長命）

<details>
<summary>答えを見る</summary>

**正解: D**

| トークン | 有効期限 | 用途 |
|---|---|---|
| **Access Token** | 15分〜1時間 | API呼び出し |
| **Refresh Token** | 数日〜数週間 | Access Token更新 |

**フロー:**
1. ログイン → Access Token + Refresh Token取得
2. Access TokenでAPI呼び出し
3. 期限切れ → Refresh Tokenで新Access Token取得

</details>

---

### Q12. JWTの`alg: none`攻撃とは？

- A) アルゴリズムを強化する
- B) 署名なしでトークンを受け入れさせる攻撃
- C) 暗号化を追加する
- D) トークンを圧縮する

<details>
<summary>答えを見る</summary>

**正解: B**

**攻撃手法:**
1. 攻撃者がHeaderを`{"alg":"none"}`に変更
2. 署名部分を空にする
3. 脆弱なサーバーが署名検証をスキップ

**対策:**
```kotlin
// 明示的にアルゴリズムを指定
JWT.require(Algorithm.ES256(publicKey, null))
    .build()
// `alg: none`は拒否される
```

</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 JWT検証を深く理解 |
| 8-10問 | 👍 基礎はOK |
| 5-7問 | 📖 復習推奨 |
| 4問以下 | 📚 基礎から学び直し |

---

## 📝 復習用キーワード

- **JWT構造**: Header, Payload, Signature
- **標準クレーム**: sub, exp, iat, aud, iss
- **HS256 vs RS256/ES256**: 対称鍵 vs 非対称鍵
- **JWKS**: 公開鍵の動的取得
- **Ktor認証**: `install(Authentication)` + `jwt { }`
- **検証項目**: 署名、exp、aud、iss
- **Access vs Refresh**: API用（短命） vs 更新用（長命）
- **alg:none攻撃**: アルゴリズム明示指定で対策
