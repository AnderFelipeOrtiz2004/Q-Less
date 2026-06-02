import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/constants.dart';

bool _isRemotePath(String path) {
  return path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('blob:');
}

String getImageUrl(String path) {
  final p = path.trim();
  if (p.isEmpty) return '';

  var cleaned = p.replaceAll('/backend/', '/');
  cleaned = cleaned.replaceAll('backend/', '');

  if (_isRemotePath(cleaned)) {
    return cleaned
        .replaceFirst('http://localhost/', 'http://127.0.0.1/')
        .replaceFirst('https://localhost/', 'https://127.0.0.1/');
  }

  // Rutas absolutas (/storage/... o /q-less/...) → siempre bajo BASE_URL (Apache :80)
  if (cleaned.startsWith('/')) {
    var path = cleaned.replaceFirst(RegExp(r'^/+'), '');
    if (path.startsWith('q-less/')) {
      path = path.substring('q-less/'.length);
    }
    return apiUrl(BASE_URL, path);
  }

  return apiUrl(BASE_URL, cleaned);
}


Widget? _buildDataImage(
  String path, {
  required BoxFit fit,
  double? width,
  double? height,
}) {
  if (!path.startsWith('data:image/')) return null;
  final commaIndex = path.indexOf(',');
  if (commaIndex == -1) return null;

  try {
    final bytes = base64Decode(path.substring(commaIndex + 1));
    return Image.memory(bytes, fit: fit, width: width, height: height);
  } catch (_) {
    return null;
  }
}

Widget buildProductImage(
  String imagePath,
  String imageUrl, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget? placeholder,
}) {
  final dataImage = _buildDataImage(
    imagePath,
    fit: fit,
    width: width,
    height: height,
  );
  if (dataImage != null) return dataImage;

  if (imagePath.isNotEmpty && !_isRemotePath(imagePath)) {
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: fit,
        width: width,
        height: height,
      );
    }

    if (!kIsWeb) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          width: width,
          height: height,
        );
      }
    }
  }

  final imageUrlCandidate = getImageUrl(imageUrl);
  final imagePathCandidate = getImageUrl(imagePath);
  final resolvedUrl = imageUrlCandidate.isNotEmpty
      ? imageUrlCandidate
      : imagePathCandidate;

  if (resolvedUrl.isNotEmpty) {
    return Image.network(
      resolvedUrl,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) =>
          placeholder ?? const Icon(Icons.image_not_supported_outlined),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  return placeholder ??
      const Center(child: Icon(Icons.image_not_supported_outlined));
}
