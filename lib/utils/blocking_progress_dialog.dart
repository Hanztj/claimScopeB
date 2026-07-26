import 'package:flutter/material.dart';

/// Runs [task] while showing the same blocking progress dialog used by the
/// submission flows.
///
/// The dialog is given one rendered frame before the task begins so the
/// progress indicator remains visible and animated while asynchronous or
/// isolate work runs.
Future<T> runWithBlockingProgress<T>({
  required BuildContext context,
  required String message,
  String? secondaryMessage,
  required Future<T> Function() task,
}) async {
  BuildContext? progressDialogContext;

  final dialogFuture = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      progressDialogContext = dialogContext;
      return PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: CircularProgressIndicator(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.88),
                      ),
                    ),
                    if (secondaryMessage != null &&
                        secondaryMessage.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        secondaryMessage,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: Theme.of(dialogContext)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  await Future<void>.delayed(Duration.zero);
  await WidgetsBinding.instance.endOfFrame;

  try {
    return await task();
  } finally {
    final dialogContext = progressDialogContext;
    if (dialogContext != null && dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
    await dialogFuture;
  }
}
