import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

Future<XFile?> pickProfileImageWithOptions(
  BuildContext context, {
  required ImagePicker picker,
  String title = 'Update profile photo',
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from device'),
              subtitle: const Text('Pick an existing image file or photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              subtitle: const Text('Open the camera and ask for permission'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  if (source == null || !context.mounted) {
    return null;
  }

  try {
    return await picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1400,
    );
  } on PlatformException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_profileImageErrorMessage(error))),
      );
    }
    return null;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not open the selected image source right now.',
          ),
        ),
      );
    }
    return null;
  }
}

String _profileImageErrorMessage(PlatformException error) {
  final code = error.code.toLowerCase();
  if (code.contains('camera_access_denied') ||
      code.contains('camera_access_restricted') ||
      code.contains('camera_denied')) {
    return 'Camera permission was denied. Please allow camera access and try again.';
  }
  if (code.contains('photo_access_denied') ||
      code.contains('gallery_access_denied') ||
      code.contains('access_denied')) {
    return 'Photo access was denied. Please allow file or gallery access and try again.';
  }
  if (code.contains('no_available_camera')) {
    return 'No camera is available on this device or browser.';
  }
  return 'We could not open the camera or file picker right now.';
}
