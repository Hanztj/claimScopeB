import 'package:flutter/material.dart';

class BlockingProgressHelper {
  const BlockingProgressHelper._();

  static Future<T> run<T>({
    required BuildContext context,
    required String message,
    required Future<T> Function() operation,
    Duration initialDelay = Duration.zero,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );

    if (initialDelay > Duration.zero) {
      await Future<void>.delayed(initialDelay);
    }

    try {
      return await operation();
    } finally {
      if (context.mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);
        if (navigator.canPop()) {
          navigator.pop();
        }
      }
    }
  }
}
