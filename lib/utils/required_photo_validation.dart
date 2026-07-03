typedef RequiredPhotoCheck = String? Function();

String? firstMissingRequiredPhoto(Iterable<RequiredPhotoCheck> checks) {
  for (final check in checks) {
    final message = check();
    if (message != null && message.isNotEmpty) return message;
  }
  return null;
}