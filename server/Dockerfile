# 📦 ステージ1: ビルド
# ───────────────────────────────────────────────────────────────
# 💡 Ktorプラグイン 3.3.2 は Gradle 8.11+ を必要とするため、最新版を使用
FROM gradle:8.12-jdk17 AS build

# 作業ディレクトリを /app に設定（以降のコマンドはここで実行）
WORKDIR /app

# ローカルの全ファイルをコンテナ内の /app にコピー
COPY . .

# Fat JARをビルド（全依存を含む単一JARファイル）
#    - 通常のJAR: アプリコードだけ
#    - Fat JAR:   アプリコード + 全ての依存ライブラリ
RUN gradle buildFatJar --no-daemon

# ───────────────────────────────────────────────────────────────
# ステージ2: 実行
# ───────────────────────────────────────────────────────────────
# 💡 eclipse-temurin:17-jre を使用（Alpine版はApple Silicon非対応）
#    - Cloud Run (linux/amd64) でも動作します
#    - イメージサイズは少し大きくなりますが、互換性が高い
FROM eclipse-temurin:17-jre

# 作業ディレクトリを設定
WORKDIR /app

# ステージ1（build）で生成したJARを、現在のステージにコピー
# 💡 build.gradle.kts で archiveFileName を "app.jar" に設定した名前に合わせる
COPY --from=build /app/build/libs/app.jar app.jar

# コンテナがリッスンするポートを宣言（ドキュメント目的）
# これ自体はポートを開放しません、Cloud Runが自動で設定します
EXPOSE 8080

# コンテナ起動時に実行するコマンド
ENTRYPOINT ["java", "-jar", "app.jar"]
