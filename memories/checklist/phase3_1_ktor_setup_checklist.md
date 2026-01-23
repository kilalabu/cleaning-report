# Phase 3.1: Ktorセットアップ & アーキテクチャ 理解度チェックリスト

Phase 3.1 における、**Ktorフレームワークの基本構造とセットアップ**に関する理解度を確認する問題集です。
DockerやCloud Runに関する内容は、別途 [Docker & Cloud Run 理解度チェックリスト](./docker_cloud_run_checklist.md) を参照してください。

---

## 📚 セクション1: Ktorの基本概念

### Q1. Android開発者がKtorサーバーを開発する際、最も意識すべき役割の違いは？

- A) AndroidはJavaで書くが、KtorはKotlinで書く必要がある。
- B) AndroidはローカルDBを使うが、Ktorはデータベースを使えない。
- C) Androidはユーザー入力イベントを受け取るが、Ktorは自発的に処理を開始する。
- D) AndroidはUIスレッドを持つが、KtorはUIを持たず「リクエストを受け取ってレスポンスを返す」ことに特化している。

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**
サーバーサイド（Ktor）の主役は **HTTP リクエスト/レスポンス** です。
Androidアプリではユーザーのタップ操作などがトリガーになりますが、サーバーでは「クライアントからのリクエスト受信」が処理のトリガーになります。
UIを作るのではなく、API（データの窓口）を作ることが主な役割です。

</details>

---

### Q2. Ktorにおける「ルーティング (`routing { }`)」の役割をAndroid開発の用語でたとえると？

- A) `Navigation Graph`（URL/パスと、対応する画面/処理の定義）
- B) `AndroidManifest.xml`（アプリの権限設定）
- C) `build.gradle.kts`（ライブラリ依存関係）
- D) `SharedPreferences`（データの保存）

<details>
<summary>答えを見る</summary>

**正解: A**

**解説:**
**ルーティング**は、「どのURL（パス）にアクセスされたら、どの処理（ハンドラ）を実行するか」を定義する地図のようなものです。
Android Jetpack Navigationで `composable("home") { ... }` と画面を定義するのと非常に似ています。
Ktorでは `get("/health") { ... }` のようにHTTPメソッドとパスを組み合わせて定義します。

</details>

---

### Q3. `Application.module()` 関数の役割として正しいのは？

- A) データベースのテーブルを作成する。
- B) アプリケーションの起動時に実行され、プラグイン（機能）のインストールやルーティングの設定をまとめて行う場所。
- C) 画面のレイアウトを定義する。
- D) テストを実行する。

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
Ktorでは `Application` クラスの拡張関数としてモジュールを定義します。
Androidの `Application.onCreate()` や `MainActivity.onCreate()` に近く、ここで `install(ContentNegotiation)` や `configureRouting()` などを呼び出すことで、サーバーに必要な機能を初期化・構成します。

</details>

---

## 📚 セクション2: プラグインと機能

### Q4. Ktorにおける「プラグイン（旧称: Feature）」とは何か？

- A) 外部の有料サービス。
- B) IntelliJ IDEAの拡張機能。
- C) Google Chromeの拡張機能。
- D) 「認証」「CORS」「JSON変換」など、必要な機能だけをサーバーに追加するための仕組み。

<details>
<summary>答えを見る</summary>

**正解: D**

**解説:**
Ktorは「マイクロフレームワーク」であり、初期状態ではほとんど機能を持っていません。
必要な機能だけを `install(PluginName) { ... }` という形で追加していく設計になっています。
これにより、不要な機能を持たない軽量で高速なサーバーを作ることができます。

</details>

---

### Q5. Android開発における `Retrofit` と、Ktorにおける `ContentNegotiation` プラグインの共通点は？

- A) どちらもHTTP通信を暗号化する機能である。
- B) どちらも「データクラス（Kotlinオブジェクト）」と「JSON」を自動で変換（シリアライズ/デシリアライズ）する設定を行う場所である。
- C) どちらもDB接続を管理する機能である。
- D) 共通点はない。

<details>
<summary>答えを見る</summary>

**正解: B**

**解説:**
- **Android (Retrofit)**: `MoshiConverterFactory` などを追加することで、APIのレスポンス（JSON）を自動で `User` クラスなどに変換します。
- **Ktor (Server)**: `install(ContentNegotiation) { json() }` を設定することで、`call.respond(user)` とするだけで自動的に `User` クラスを JSON に変換して返します。
「型安全なオブジェクトと通信フォーマット（JSON）の橋渡し」という役割は全く同じです。

</details>

---

### Q6. ヘルスチェック API (`GET /health`) を実装する主な目的は？

- A) サーバーのCPU温度を監視するため。
- B) ユーザーの健康状態を管理するため。
- C) Cloud Runやロードバランサーが「サーバーが正常に起動しているか」を定期的に確認し、応答がない場合に再起動やトラフィック遮断を行うため。
- D) データベースのバックアップを取るため。

<details>
<summary>答えを見る</summary>

**正解: C**

**解説:**
クラウド環境では、サーバープロセスが起動していても「応答不能」な状態になることがあります。
インフラ側（Cloud Run等）は定期的に `/health` にアクセスし、200 OK が返ってくるかを確認します（死活監視）。
これが失敗すると「コンテナが死んだ」と判断され、新しいコンテナに置き換えられます。

</details>

---

## 🏆 完了目安

このチェックリストで **5問以上** 正解できれば、Phase 3.1 における Ktor の基礎部分は理解できています。
続いて、[Docker & Cloud Run 理解度チェックリスト](./docker_cloud_run_checklist.md) に進み、インフラ周りの理解を深めてください。
