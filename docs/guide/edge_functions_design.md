# Supabase Edge Functions 設計・背景説明書

## 目次
1. [Edge Functionsとは](#edge-functionsとは)
2. [なぜEdge Functionsを使うのか](#なぜedge-functionsを使うのか)
3. [Edge Functionsのアーキテクチャ](#edge-functionsのアーキテクチャ)
4. [開発環境のセットアップ](#開発環境のセットアップ)
5. [実装設計](#実装設計)
6. [デプロイと運用](#デプロイと運用)
7. [代替案との比較](#代替案との比較)
8. [Q&A](#qa)

---

## Edge Functionsとは

Supabase Edge Functionsは、**Deno**ベースのサーバーレス関数です。Vercel FunctionsやAWS Lambdaに似ていますが、Supabaseプロジェクトと統合されており、データベースや認証と連携しやすいのが特徴です。

### 基本スペック
| 項目 | 仕様 |
| :--- | :--- |
| **ランタイム** | Deno（TypeScript/JavaScript） |
| **実行時間制限** | 150秒（Pro Planで400秒） |
| **メモリ制限** | 150MB（Pro Planで1GB） |
| **リクエストボディ** | 最大6MB |
| **Free Tier** | 500,000呼び出し/月 |
| **コールドスタート** | 通常500ms〜2秒程度 |

### DenoとNode.jsの違い

| 項目 | Deno | Node.js |
| :--- | :--- | :--- |
| **パッケージ管理** | URLインポート | npm |
| **TypeScript** | ネイティブサポート | 要トランスパイル |
| **セキュリティ** | サンドボックス（権限明示必要） | 制限なし |
| **標準ライブラリ** | 充実 | ミニマル |

```typescript
// Deno方式のインポート
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Node.js方式のインポート（使用不可）
// const express = require('express'); // ← ❌ 動かない
```

---

## なぜEdge Functionsを使うのか

### 現状（GAS）の問題点

現在PDF生成はGoogle Apps Script（GAS）で行っていますが、以下の課題があります：

| 課題 | 詳細 |
| :--- | :--- |
| **レスポンス速度** | コールドスタートで5〜10秒かかることがある |
| **Supabaseとの統合** | 別システムなのでデータ連携が複雑 |
| **認証の二重管理** | GAS側でも認証ロジックが必要 |
| **デプロイの分散** | GASとFlutterで別々にデプロイ・管理 |

### Edge Functions移行のメリット

| メリット | 詳細 |
| :--- | :--- |
| **Supabase統合** | 同じプロジェクト内で認証・DB・関数を一元管理 |
| **RLSの恩恵** | 認証済みユーザーのトークンをそのまま使える |
| **モダンなスタック** | TypeScript + Deno で型安全 |
| **コスト** | Free Tierで50万回/月、通常用途なら無料 |

> [!NOTE]
> ただし、**GASのスプレッドシート連携**は引き続き使いたい場合もあります。その場合はEdge FunctionsからGASを呼び出すハイブリッド構成も可能です。

---

## Edge Functionsのアーキテクチャ

### 呼び出しフロー

```
┌──────────────┐     HTTPS + JWT      ┌─────────────────────┐
│ Flutter App  │ ─────────────────────▶│ Supabase Edge       │
│              │                       │ Functions           │
└──────────────┘                       └─────────────────────┘
                                               │
                                               │ Supabase Client
                                               ▼
                                       ┌─────────────────────┐
                                       │ Supabase Database   │
                                       │ (PostgreSQL + RLS)  │
                                       └─────────────────────┘
```

### 認証の流れ

1. Flutterアプリでログイン済みの `session.access_token` を取得
2. HTTPリクエストのヘッダに `Authorization: Bearer {token}` を付与
3. Edge Function側で `supabase.auth.getUser(token)` でユーザー情報を取得
4. そのユーザーとしてDB操作（RLSが適用される）

```typescript
// Edge Function内での認証チェック
const supabaseClient = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_ANON_KEY")!,
  { global: { headers: { Authorization: req.headers.get("Authorization")! } } }
);

const { data: { user } } = await supabaseClient.auth.getUser();
if (!user) {
  return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
}
```

---

## 開発環境のセットアップ

### 1. Supabase CLI のインストール

```bash
# macOS
brew install supabase/tap/supabase

# または npm
npm install -g supabase
```

### 2. プロジェクトとリンク

```bash
cd cleaning-report

# Supabaseにログイン
supabase login

# プロジェクトとリンク（プロジェクトIDはDashboardから確認）
supabase link --project-ref <project-id>
```

### 3. Edge Function の作成

```bash
# generate-pdf という名前の関数を作成
supabase functions new generate-pdf
```

生成されるファイル構造：
```
supabase/
└── functions/
    └── generate-pdf/
        └── index.ts    # メインファイル
```

### 4. ローカルで実行

```bash
# ローカルでSupabaseを起動
supabase start

# Edge Functionをローカル実行
supabase functions serve generate-pdf --env-file ./supabase/.env.local
```

### 5. デプロイ

```bash
supabase functions deploy generate-pdf
```

---

## 実装設計

### PDF生成関数の設計

#### エンドポイント
```
POST https://<project-ref>.supabase.co/functions/v1/generate-pdf
```

#### リクエスト
```json
{
  "month": "2026-01",
  "billingDate": "2026-01-31"
}
```

#### レスポンス
```json
{
  "success": true,
  "data": "data:application/pdf;base64,JVBERi0...",
  "filename": "請求書_2026年1月分.pdf"
}
```

### 実装の選択肢

#### 選択肢1: Edge Function内で直接PDF生成

```typescript
// jspdf または pdf-lib を使用
import { jsPDF } from 'https://esm.sh/jspdf@2.5.1';

const doc = new jsPDF();
doc.text("請求書", 10, 10);
const pdfData = doc.output('datauristring');
```

**メリット**:
- 完全にSupabase内で完結
- GAS不要

**デメリット**:
- 日本語フォント対応が必要（埋め込みで容量増）
- Denoでのjspdf互換性に注意

#### 選択肢2: GASをバックエンドとして継続利用

```typescript
// Edge FunctionからGASを呼び出し
const gasResponse = await fetch(GAS_ENDPOINT, {
  method: 'POST',
  body: JSON.stringify({ month, billingDate, data: reports })
});
```

**メリット**:
- 既存のPDF生成ロジックを再利用
- スプレッドシートテンプレートをそのまま使える

**デメリット**:
- システムが分散する
- GASのコールドスタートも残る

#### 選択肢3: Supabase Storage + 外部PDF生成サービス

- PDFの生成はCloudflare Workers等の外部サービスに委任
- 生成したPDFはSupabase Storageに保存

**メリット**:
- 役割分担が明確
- 重いPDF生成をオフロード

**デメリット**:
- 複雑度が上がる
- 外部サービスのコストがかかる可能性

### 推奨案

**Phase 2では選択肢2（GAS継続利用）**を推奨します：

1. 既存のPDF生成ロジックが動作実績あり
2. スプレッドシートテンプレートを使った柔軟なレイアウト
3. Edge Functionsは認証ラッパーとして使用し、GASへの橋渡しを行う

将来的にGASを完全に置き換えたい場合は、選択肢1への移行を検討できます。

---

## デプロイと運用

### 環境変数の設定

```bash
# シークレットを設定（ダッシュボードからも可能）
supabase secrets set GAS_ENDPOINT=https://script.google.com/macros/s/xxx/exec
```

### モニタリング

- **Dashboard → Edge Functions → Logs** でリアルタイムログ
- エラー発生時は自動的にログに記録

### 更新

```bash
# 関数を更新
supabase functions deploy generate-pdf
```

> [!WARNING]
> デプロイすると即座に本番に反映されます。ステージング環境が必要な場合は別プロジェクトを作成してください。

---

## 代替案との比較

### Edge Functions vs Vercel Functions

| 項目 | Supabase Edge | Vercel Functions |
| :--- | :--- | :--- |
| **ランタイム** | Deno | Node.js |
| **Supabase認証統合** | ◎ ネイティブ | △ 手動設定 |
| **Free Tier** | 500,000回/月 | 100,000回/月 |
| **コールドスタート** | 500ms〜2s | 100ms〜500ms |
| **エッジロケーション** | 全世界分散 | 全世界分散 |

### Edge Functions vs AWS Lambda

| 項目 | Supabase Edge | AWS Lambda |
| :--- | :--- | :--- |
| **設定の複雑さ** | 低 | 高 |
| **コスト予測** | シンプル | 複雑 |
| **Supabase連携** | ◎ | △（SDK経由） |
| **スケーラビリティ** | ○ | ◎ |

### 結論

小〜中規模のSupabaseプロジェクトでは、**Edge Functionsが最も簡単**で、認証・DB連携がスムーズです。大規模や特殊要件がある場合はAWS Lambda等も検討してください。

---

## Q&A

### Q1: Edge FunctionsでNode.jsパッケージは使えるか？

**A**: npm パッケージの多くは `https://esm.sh/` 経由で使えますが、**Node.js固有のAPI（fs, path等）に依存するパッケージは動きません**。

```typescript
// ✅ 使える例
import { jsPDF } from "https://esm.sh/jspdf@2.5.1";

// ❌ 使えない例（Node.js固有API依存）
import puppeteer from "https://esm.sh/puppeteer"; // ブラウザ起動不可
```

### Q2: ローカル開発時にSupabase DBに接続できるか？

**A**: `supabase start` でローカルDBが起動するので、そちらに接続します。本番DBへの接続はデプロイ後に自動で行われます。

### Q3: CORSはどう設定するか？

**A**: レスポンスヘッダで設定します：

```typescript
return new Response(JSON.stringify(data), {
  headers: {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
  },
});
```

### Q4: Secret key は Edge Function 内で使えるか？

**A**: はい、環境変数 `SUPABASE_SERVICE_ROLE_KEY` として自動設定されています。ただし **RLSをバイパスする**ため、必要な場合のみ慎重に使用してください。

### Q5: 既存のGAS PDFロジックはどうなるか？

**A**: Phase 2では引き続きGASを使用します。Edge Functionは認証付きのプロキシとして機能し、Flutter → Edge Function → GAS の流れでPDFを生成します。

---

## 次のステップ

この設計で問題なければ、以下の順序で実装を進めます：

1. [ ] Supabase CLIインストール
2. [ ] `generate-pdf` Edge Function作成
3. [ ] 認証チェック + GAS呼び出しロジック実装
4. [ ] ローカルテスト
5. [ ] デプロイ
6. [ ] Flutterアプリから呼び出し修正

---

## 参考リンク

- [Supabase Edge Functions 公式ドキュメント](https://supabase.com/docs/guides/functions)
- [Deno Standard Library](https://deno.land/std)
- [esm.sh - npm packages for Deno](https://esm.sh/)
