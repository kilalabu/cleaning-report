# Supabase Edge Functions 理解度チェックリスト

Edge Functionsに関する本質的な理解を確認するための問題集です。  
※ TypeScriptの記法ではなく、アーキテクチャ・ライブラリ・フローの理解に焦点を当てています。

---

## 📚 セクション1: 基礎理解（4択問題）

### Q1. Supabase Edge Functions のランタイムは何？

- A) Node.js
- B) Python
- C) Deno
- D) Go

<details>
<summary>答えを見る</summary>

**正解: C**

Supabase Edge Functions は **Deno** ベースのサーバーレス関数です。

**Node.js との主な違い:**
| 項目 | Deno | Node.js |
|:---|:---|:---|
| パッケージ管理 | URLインポート | npm |
| TypeScript | ネイティブサポート | 要トランスパイル |
| セキュリティ | サンドボックス（権限明示必要） | 制限なし |
</details>

---

### Q2. Edge Functions で npm パッケージを使用する場合、どのように import する？

- A) `import xxx from 'package-name'` で直接指定
- B) `require('package-name')` で読み込む
- C) `https://esm.sh/` 経由で URL インポート
- D) npm install 後に node_modules から import

<details>
<summary>答えを見る</summary>

**正解: C**

Deno は URL ベースのインポートを使用します。npm パッケージは `esm.sh` を経由して使用できます。

```typescript
// ✅ Deno での正しいインポート
import { jsPDF } from "https://esm.sh/jspdf@2.5.1";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ❌ Node.js 方式（動かない）
const express = require('express');
```

ただし、Node.js 固有の API（fs, path 等）に依存するパッケージは動作しません。
</details>

---

### Q3. Edge Functions の Free Tier 制限として正しいのは？

- A) 100回/月
- B) 10,000回/月
- C) 100,000回/月
- D) 500,000回/月

<details>
<summary>答えを見る</summary>

**正解: D**

Supabase Edge Functions の Free Tier は **500,000回/月** の呼び出しが可能です。

| 項目 | Free Tier |
|:---|:---|
| 呼び出し回数 | 500,000回/月 |
| 実行時間制限 | 150秒 |
| メモリ制限 | 150MB |
| リクエストボディ | 最大6MB |
</details>

---

### Q4. Edge Functions から Supabase データベースにアクセスする際、RLS は適用される？

- A) 常に適用される
- B) 常にバイパスされる
- C) クライアントから渡された JWT を使えば適用される
- D) config.toml の設定に関係なく適用されない

<details>
<summary>答えを見る</summary>

**正解: C**

Edge Functions 内でクライアントから渡された JWT（Authorization ヘッダー）を使って Supabase Client を初期化すれば、そのユーザーとして RLS が適用されます。

```typescript
const supabaseClient = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_ANON_KEY")!,
  { global: { headers: { Authorization: req.headers.get("Authorization")! } } }
);
```

一方、`SUPABASE_SERVICE_ROLE_KEY` を使うと RLS をバイパスします。
</details>

---

## 📚 セクション2: アーキテクチャ理解

### Q5. 今回の実装で Flutter → PDF生成 の流れとして正しいのは？

- A) Flutter → GAS（直接）
- B) Flutter → Edge Functions → Supabase DB → PDF生成（Edge内）
- C) Flutter → Edge Functions → GAS → PDF生成
- D) Flutter → Supabase DB → Edge Functions → PDF生成

<details>
<summary>答えを見る</summary>

**正解: C**

Phase 2 では以下の流れでPDFを生成しています：

```
[Flutter Web]
    ↓ HTTPリクエスト + JWT
[Supabase Edge Functions]
    ↓ DBからデータ取得
    ↓ GASにPOSTでデータ送信
[GAS Web App]
    ↓ スプレッドシートテンプレートでPDF生成
[PDF Base64 返却]
    ↓
[Flutter Webでダウンロード]
```

既存のGASのPDF生成ロジックを再利用しつつ、Edge Functionsで認証・データ取得を担当しています。
</details>

---

### Q6. Edge Functions で認証チェックを行う正しいフローは？

- A) リクエストボディから email/password を受け取ってログイン処理
- B) Authorization ヘッダーから JWT を取得し、`supabase.auth.getUser()` で検証
- C) クエリパラメータから user_id を取得して直接使用
- D) Cookie からセッション情報を取得

<details>
<summary>答えを見る</summary>

**正解: B**

Edge Functions での認証フロー：

1. Flutter アプリでログイン済みの `session.access_token` を取得
2. HTTP リクエストのヘッダに `Authorization: Bearer {token}` を付与
3. Edge Function 側で `supabase.auth.getUser()` でユーザー情報を取得

```typescript
const { data: { user } } = await supabaseClient.auth.getUser();
if (!user) {
  return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
}
```

クエリパラメータやリクエストボディで user_id を渡す方法は**なりすまし可能**なのでセキュリティ上NGです。
</details>

---

### Q7. `supabase/config.toml` で `verify_jwt = false` に設定する理由は？

- A) JWT 検証を無効化してパフォーマンスを向上させるため
- B) 認証なしで Edge Functions を公開するため
- C) Edge Function 内で独自に認証チェックを行うため、Supabase のデフォルト検証をスキップ
- D) 開発環境でのみ使用する設定で、本番では true にすべき

<details>
<summary>答えを見る</summary>

**正解: C**

`verify_jwt = false` は、Supabase のゲートウェイレベルでの JWT 検証をスキップし、**関数内で独自に認証チェック**を行うための設定です。

これにより：
- 認証チェックのカスタマイズが可能
- エラーハンドリングを詳細に制御できる
- 未認証リクエストでも関数内で適切にエラーを返せる

関数内では必ず `supabase.auth.getUser()` で認証チェックを行う必要があります。
</details>

---

## 📚 セクション3: 環境・デプロイ理解

### Q8. Edge Functions のシークレット（環境変数）を設定する正しい方法は？

- A) コード内に直接記述
- B) `.env` ファイルをリポジトリにコミット
- C) `supabase secrets set KEY=VALUE` コマンドまたは Dashboard から設定
- D) `package.json` に記述

<details>
<summary>答えを見る</summary>

**正解: C**

シークレットは以下の方法で設定します：

```bash
# CLI で設定
supabase secrets set GAS_ENDPOINT=https://script.google.com/macros/s/xxx/exec
```

または Dashboard → Edge Functions → Secrets から設定できます。

**⚠️ 注意:**
- シークレットをコード内に直接記述しない
- `.env` ファイルをリポジトリにコミットしない
- ローカル開発時は `--env-file ./supabase/.env.local` で読み込む
</details>

---

### Q9. Edge Functions をデプロイすると何が起こる？

- A) ステージング環境に反映され、手動で本番に昇格が必要
- B) 即座に本番に反映される
- C) レビュー待ち状態になる
- D) 古いバージョンと並行稼働する

<details>
<summary>答えを見る</summary>

**正解: B**

```bash
supabase functions deploy generate-pdf
```

このコマンドを実行すると**即座に本番に反映**されます。

**⚠️ 注意:**
- ステージング環境が必要な場合は別の Supabase プロジェクトを作成する必要があります
- ロールバック機能はないため、十分なテスト後にデプロイしてください
</details>

---

### Q10. ローカル開発時、Edge Functions はどこのデータベースに接続する？

- A) 自動的に本番 Supabase DB に接続
- B) `supabase start` で起動したローカル DB に接続
- C) 接続先を毎回手動で指定する必要がある
- D) データベースには接続できない

<details>
<summary>答えを見る</summary>

**正解: B**

`supabase start` でローカルの Supabase 環境（DB含む）が起動します。

```bash
# ローカル環境を起動
supabase start

# Edge Functions をローカル実行
supabase functions serve generate-pdf --env-file ./supabase/.env.local
```

本番 DB への接続はデプロイ後に自動で行われます。ローカル開発時は本番データを汚さずにテストできます。
</details>

---

## 📚 セクション4: GAS連携理解

### Q11. Phase 2 で GAS を継続利用する理由として正しいのは？

- A) Edge Functions では PDF 生成が不可能だから
- B) 既存の PDF 生成ロジックとスプレッドシートテンプレートを再利用するため
- C) GAS の方が高速だから
- D) Supabase の制限で外部 API 呼び出しができないから

<details>
<summary>答えを見る</summary>

**正解: B**

Phase 2 では以下の理由で GAS を継続利用しています：

1. **既存ロジックの実績**: 動作実績のある PDF 生成ロジックを再利用
2. **テンプレート活用**: スプレッドシートを使った柔軟なレイアウト
3. **段階的移行**: 一度に全てを移行せず、リスクを分散

将来的に Edge Functions 内で直接 PDF 生成することも可能ですが、日本語フォント対応などの課題があります。
</details>

---

### Q12. Phase 2 で GAS 側が担当する役割として正しいのは？

- A) データの取得・認証・PDF生成すべて
- B) 認証とデータ取得のみ
- C) PDF生成のみ（データは Edge Functions から POST で受け取る）
- D) Edge Functions へのプロキシ

<details>
<summary>答えを見る</summary>

**正解: C**

Phase 2 での役割分担：

| コンポーネント | 役割 |
|:---|:---|
| **Flutter** | UIとユーザー操作 |
| **Edge Functions** | 認証チェック、DB からデータ取得、GAS への POST |
| **GAS** | PDF 生成のみ（受け取ったデータを使用） |

**データの唯一のソース（Single Source of Truth）は Supabase に統一**されています。GAS はスプレッドシートからデータを読み込まず、Edge Functions から受け取ったデータのみを使用します。
</details>

---

## 📚 セクション5: 代替案比較

### Q13. Supabase Edge Functions と Vercel Functions の比較で正しいのは？

- A) Vercel の方が Supabase 認証との統合が容易
- B) Edge Functions は月 100,000 回まで無料
- C) Edge Functions の Free Tier は月 500,000 回で、Vercel より多い
- D) 両者のランタイムは同じ Node.js

<details>
<summary>答えを見る</summary>

**正解: C**

| 項目 | Supabase Edge | Vercel Functions |
|:---|:---|:---|
| ランタイム | Deno | Node.js |
| Supabase認証統合 | ◎ ネイティブ | △ 手動設定 |
| **Free Tier** | **500,000回/月** | **100,000回/月** |

Supabase プロジェクト内で認証・DB・関数を一元管理したい場合は Edge Functions が最適です。
</details>

---

### Q14. CORS（Cross-Origin Resource Sharing）を Edge Functions で設定する正しい方法は？

- A) `supabase/config.toml` で設定
- B) Dashboard の設定画面で指定
- C) レスポンスヘッダーで設定
- D) CORS は自動で設定されるため不要

<details>
<summary>答えを見る</summary>

**正解: C**

CORS はレスポンスヘッダーで設定します：

```typescript
return new Response(JSON.stringify(data), {
  headers: {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
  },
});
```

また、OPTIONS リクエスト（プリフライト）への対応も必要な場合があります：

```typescript
if (req.method === 'OPTIONS') {
  return new Response('ok', {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, content-type',
    }
  });
}
```
</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 13-14問 | 🏆 完全に理解している |
| 10-12問 | 👍 概ね理解している。復習推奨箇所あり |
| 7-9問 | 📖 基礎は理解しているが、深い理解が必要 |
| 6問以下 | 📚 ドキュメントを再度読み込むことを推奨 |

---

## 📝 復習用キーワード

- **Deno**: Edge Functions のランタイム。URLインポート、TypeScriptネイティブ
- **esm.sh**: npm パッケージを Deno で使うための CDN
- **JWT 認証フロー**: Authorization ヘッダー → getUser() で検証
- **verify_jwt = false**: 関数内で独自に認証チェックするための設定
- **GAS 連携**: 認証・データ取得は Edge Functions、PDF生成は GAS
- **CORS**: レスポンスヘッダーで設定
- **デプロイ**: 即座に本番反映される
