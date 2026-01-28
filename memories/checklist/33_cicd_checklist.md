# CI/CD 理解度チェックリスト

自動化済みのCI/CDパイプラインの仕組みを理解し、トラブル発生時に何が起きているか把握できるようになることがゴールです。

---

## 📚 セクション1: CI/CD基礎概念

### Q1. CI（継続的インテグレーション）の主な目的は？

- A) 本番環境へのデプロイを自動化する
- B) コード変更を頻繁にマージし、自動テストで品質を担保する
- C) インフラを自動構築する
- D) ログを収集する

<details>
<summary>答えを見る</summary>

**正解: B**

| 概念 | 目的 |
|---|---|
| **CI** | コード変更を頻繁にマージ、自動テストで早期に問題発見 |
| **CD** | テスト済みコードを自動でデプロイ |

**CIの典型的なフロー:**
1. 開発者がPRを作成
2. 自動でビルド実行
3. 自動テスト実行
4. 結果をPRに表示

</details>

---

### Q2. CD における「Continuous Delivery」と「Continuous Deployment」の違いは？

- A) 同じ意味
- B) Deliveryは手動承認後にデプロイ、Deploymentは承認なしで自動デプロイ
- C) Deliveryはテストなし、Deploymentはテストあり
- D) Deliveryはステージング、Deploymentは本番

<details>
<summary>答えを見る</summary>

**正解: B**

| 概念 | デプロイ方法 |
|---|---|
| **Continuous Delivery** | 本番デプロイ可能な状態を維持、最終デプロイは手動承認 |
| **Continuous Deployment** | mainマージで自動的に本番デプロイ |

**選択基準:**
- 規制が厳しい業界 → Delivery（承認プロセス必須）
- スタートアップ/高速リリース → Deployment

</details>

---

### Q3. CI/CDパイプラインで「ビルド」フェーズが失敗する主な原因は？

- A) テストコードのバグ
- B) デプロイ先の設定ミス
- C) 本番環境のダウン
- D) コンパイルエラー、依存関係の問題

<details>
<summary>答えを見る</summary>

**正解: D**

**ビルドフェーズで起きること:**
- ソースコードのコンパイル
- 依存関係の解決・ダウンロード
- 成果物（JAR、Docker Image等）の生成

**よくある失敗原因:**
- コンパイルエラー
- 依存ライブラリのバージョン競合
- 依存ライブラリのダウンロード失敗

</details>

---

## 📚 セクション2: GitHub Actions

### Q4. GitHub Actionsのワークフローファイルの配置場所は？

- A) リポジトリルートの`.github/workflows/`
- B) リポジトリルートの`ci/`
- C) `src/`内の任意の場所
- D) GitHub Webでのみ設定

<details>
<summary>答えを見る</summary>

**正解: A**

```
.github/
└── workflows/
    ├── ci.yml      # PRトリガー
    └── deploy.yml  # mainマージトリガー
```

</details>

---

### Q5. 以下のGitHub Actionsの`on`設定の意味は？

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

- A) mainブランチへのpushとmainへのPRで実行
- B) 全てのブランチで実行
- C) mainブランチからのpushでのみ実行
- D) 手動実行のみ

<details>
<summary>答えを見る</summary>

**正解: A**

| トリガー | 意味 |
|---|---|
| `push.branches: [main]` | mainへのマージ時 |
| `pull_request.branches: [main]` | mainへのPR作成/更新時 |

**他のよく使うトリガー:**
```yaml
on:
  workflow_dispatch:  # 手動実行
  schedule:
    - cron: '0 0 * * *'  # 毎日0時
```

</details>

---

### Q6. GitHub Actionsの`secrets`の用途は？

- A) ログの保存
- B) APIキーやパスワードなど機密情報の安全な保管
- C) キャッシュの保存
- D) テスト結果の保存

<details>
<summary>答えを見る</summary>

**正解: B**

```yaml
- name: Deploy to Cloud Run
  env:
    GCP_SA_KEY: ${{ secrets.GCP_SA_KEY }}
```

**secretsの特徴:**
- リポジトリ設定で暗号化保存
- ログにマスクされて出力されない
- forkしたリポジトリからはアクセス不可（セキュリティ）

</details>

---

## 📚 セクション3: Cloud Run デプロイ

### Q7. Cloud Runへのデプロイパイプラインで必要なステップは？

- A) テストのみ
- B) ビルドのみ
- C) ビルド → Dockerイメージ作成 → Container Registryにpush → Cloud Runにデプロイ
- D) ビルド → テスト → デプロイ

<details>
<summary>答えを見る</summary>

**正解: C**

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # GCP認証
      - uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      # Dockerイメージビルド & push
      - name: Build and push
        run: |
          gcloud builds submit --tag gcr.io/$PROJECT_ID/$IMAGE
      
      # Cloud Runにデプロイ
      - name: Deploy
        run: |
          gcloud run deploy $SERVICE \
            --image gcr.io/$PROJECT_ID/$IMAGE \
            --region asia-northeast1
```

</details>

---

### Q8. デプロイ時の「ブルーグリーンデプロイメント」とは？

- A) 2つのバージョンを同時に稼働させ、トラフィックを切り替える
- B) テスト環境と本番環境を統合
- C) 古いバージョンを即座に削除
- D) 手動でサーバーを再起動

<details>
<summary>答えを見る</summary>

**正解: A**

| 戦略 | 特徴 |
|---|---|
| **ブルーグリーン** | 新旧2バージョン稼働、切り替え |
| **ローリング** | 徐々に新バージョンに置き換え |
| **カナリア** | 一部トラフィックのみ新バージョン |

**Cloud Runのデフォルト動作:**
- 新リビジョンに100%トラフィック移行
- 問題時は前リビジョンに戻せる

```bash
# トラフィック分割（カナリア）
gcloud run services update-traffic SERVICE \
  --to-revisions LATEST=10,PREVIOUS=90
```

</details>

---

### Q9. デプロイ失敗時の原因特定で最初に確認すべきは？

- A) ソースコード
- B) ローカル環境での再現
- C) CIのログ、Cloud Runのログ
- D) 設計書

<details>
<summary>答えを見る</summary>

**正解: C**

**確認順序:**
1. GitHub Actionsのログ（どのステップで失敗？）
2. Cloud Build / Cloud Runのログ
3. エラーメッセージの内容

**よくある失敗パターン:**
- Dockerビルド失敗 → Dockerfileの問題
- push失敗 → 認証・権限の問題
- デプロイ失敗 → リソース制限、ヘルスチェック失敗

</details>

---

## 📚 セクション4: 実践的なCI/CD

### Q10. テストの「フレーキー（Flaky）テスト」とは？

- A) 常に成功するテスト
- B) 常に失敗するテスト
- C) 同じコードでも成功したり失敗したりする不安定なテスト
- D) 実行時間が長いテスト

<details>
<summary>答えを見る</summary>

**正解: C**

**フレーキーテストの原因:**
- タイミング依存（sleep、非同期処理）
- 外部サービス依存
- テスト間の状態共有
- 環境差異

**対策:**
- モック使用
- リトライ機構
- テストの隔離

</details>

---

### Q11. CI/CDパイプラインの実行時間短縮に有効な方法は？

- A) テストをすべて削除
- B) すべてを直列実行
- C) デプロイを手動に変更
- D) キャッシュの活用、並列実行

<details>
<summary>答えを見る</summary>

**正解: D**

**最適化手法:**
- 依存関係のキャッシュ
- テストの並列実行
- 変更ファイルに関連するテストのみ実行
- Dockerレイヤーキャッシュ

```yaml
# 依存関係キャッシュ
- uses: actions/cache@v4
  with:
    path: ~/.gradle/caches
    key: gradle-${{ hashFiles('**/*.gradle*') }}
```

</details>

---

### Q12. Infrastructure as Code（IaC）をCI/CDに組み込む利点は？

- A) 手動でのみインフラ変更可能
- B) インフラ変更もコードレビュー・自動テスト可能
- C) ログ収集が不要になる
- D) テストが不要になる

<details>
<summary>答えを見る</summary>

**正解: B**

**IaC + CI/CDの利点:**
- インフラ変更をPRでレビュー
- `terraform plan`で変更内容を事前確認
- 変更履歴がGitに残る
- 環境間の差異を防止

```yaml
# Terraform CI
- name: Terraform Plan
  run: terraform plan
  # PRでplan結果を表示
  
- name: Terraform Apply
  if: github.ref == 'refs/heads/main'
  run: terraform apply -auto-approve
```

</details>

---

## ✅ 採点基準

| 正解数 | 評価 |
|:---:|:---|
| 11-12問 | 🏆 CI/CDの仕組みを深く理解 |
| 8-10問 | 👍 基礎はOK |
| 5-7問 | 📖 復習推奨 |
| 4問以下 | 📚 基礎から学び直し |

---

## 📝 復習用キーワード

- **CI vs CD**: 統合・テスト vs デプロイ自動化
- **Delivery vs Deployment**: 手動承認 vs 完全自動
- **GitHub Actions**: `.github/workflows/`、`on`トリガー、`secrets`
- **Cloud Runデプロイ**: Dockerイメージ → Registry → デプロイ
- **ブルーグリーン**: 新旧バージョン並行稼働
- **フレーキーテスト**: 不安定なテスト
- **キャッシュ**: ビルド時間短縮
- **IaC**: インフラ変更もコードレビュー可能
