/// PDF生成リポジトリインターフェース
abstract class PdfRepository {
  /// 指定月のPDFを生成
  /// 成功時: {success: true, dataUrl: String, filename: String}
  /// 失敗時: {success: false, message: String}
  Future<Map<String, dynamic>> generatePdf({
    required String month,
    required DateTime billingDate,
  });
}
