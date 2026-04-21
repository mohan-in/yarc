import 'package:flutter/material.dart';
import 'package:yarc/utils/image_utils.dart';

/// Prompts the user to pick a save location for [imageUrl] using the native
/// file-save dialog (Android SAF picker).
///
/// A brief "Preparing image…" [SnackBar] is shown while the image bytes are
/// fetched from cache / network. The picker then opens automatically. A final
/// SnackBar reports success or failure after the user finishes.
Future<void> showImageSaveDialog(
  BuildContext context,
  String imageUrl,
) async {
  final messenger = ScaffoldMessenger.of(context);

  // Dismiss any existing snackbar and show a progress indicator while
  // we download the image bytes before opening the native picker.
  _showProgressSnackBar(messenger);

  final success = await ImageUtils.saveImageWithFilePicker(imageUrl);

  messenger.hideCurrentSnackBar();

  // Only show a result snackbar when the file was actually saved.
  // A null return from the picker means the user cancelled — stay silent.
  if (success) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Image saved successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

void _showProgressSnackBar(ScaffoldMessengerState messenger) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Preparing image…'),
          ],
        ),
        duration: Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
