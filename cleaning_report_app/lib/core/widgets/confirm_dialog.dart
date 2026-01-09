import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 確認ダイアログを表示するヘルパー関数
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = '確認',
  String cancelText = 'キャンセル',
  IconData icon = Icons.help_outline,
  Color? iconColor,
  Color? confirmButtonColor,
  bool isDanger = false,
}) async {
  final effectiveIconColor =
      iconColor ?? (isDanger ? AppTheme.destructive : AppTheme.primary);
  final effectiveButtonColor = confirmButtonColor ??
      (isDanger ? AppTheme.destructive : AppTheme.primary);

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => ConfirmDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: icon,
      iconColor: effectiveIconColor,
      confirmButtonColor: effectiveButtonColor,
    ),
  );

  return result ?? false;
}

/// 削除確認ダイアログを表示するヘルパー関数
Future<bool> showDeleteConfirmDialog({
  required BuildContext context,
  String title = '削除確認',
  String message = 'このデータを削除しますか？\nこの操作は取り消せません。',
}) {
  return showConfirmDialog(
    context: context,
    title: title,
    message: message,
    confirmText: '削除する',
    icon: Icons.delete_outline,
    isDanger: true,
  );
}

/// 確認ダイアログWidget
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final IconData icon;
  final Color iconColor;
  final Color confirmButtonColor;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.icon,
    required this.iconColor,
    required this.confirmButtonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // アイコン
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // タイトル
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // メッセージ
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.mutedForeground,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // ボタン
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: AppTheme.border),
                    ),
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmButtonColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
