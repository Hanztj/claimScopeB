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
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
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
