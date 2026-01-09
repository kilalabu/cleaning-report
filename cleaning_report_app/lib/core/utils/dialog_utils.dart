import 'package:flutter/material.dart';

Future<void> showSuccessDialog(BuildContext context, String message) async {
  if (!context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      // Auto-close after 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (ctx.mounted && Navigator.of(ctx).canPop()) {
          Navigator.of(ctx).pop();
        }
      });

      return AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );
    },
  );
}
