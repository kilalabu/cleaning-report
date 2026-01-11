目的：Android(Kotlin) & Flutterエンジニアからバックエンド領域へスキルを広げていくためのステップを踏む。

Phase 1: ハイブリッド構成（現在）
UIをFlutter Webに置き換え、バックエンドとPDF生成をGASに任せる構成です。
フロント: Flutter Web (GitHub Pages / Firebase Hosting)
バックエンド/PDF: GAS
必須要件：無料で運用する

Phase 2: Supabase への移行
データの管理をスプレッドシートからデータベース（Postgres）へ移行し、認証を統合します。
フロント: Flutter Web
バックエンド: Supabase (Auth / DB)
PDF生成: GAS (SupabaseのEdge FunctionsからGASを叩く)
必須要件：無料で運用する
目的: RDBの設計や、BaaSを利用したモダンなアプリ開発のフローを習得できます。

Phase 3: Ktor での再構築（最終形）
ビジネスロジックをKtorで書き直し、自前のAPIサーバーとして運用します。
フロント: Flutter Web
バックエンド: Ktor (Google Cloud Run 等でホスティング)
データベース: Supabase (Postgres) / Cloud SQL
必須要件：無料で運用する
目的: API設計、Kotlinによるサーバーサイド開発、gRPCへの拡張性、インフラ構成（Docker/Cloud Run等）の深い理解が得る
