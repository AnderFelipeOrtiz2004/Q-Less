import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

bool _isRemotePath(String path) {
  return path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('blob:');
}

String _absoluteImageUrl(String path) {
  final cleanPath = path.trim();
  if (cleanPath.isEmpty) return '';
  if (_isRemotePath(cleanPath)) return cleanPath;

  if (cleanPath.startsWith('backend/') || cleanPath.startsWith('storage/')) {
    return '${AuthService.baseUrl}/${cleanPath.replaceFirst(RegExp(r'^/+'), '')}';
  }

  return '';
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

  final imageUrlCandidate = _absoluteImageUrl(imageUrl);
  final imagePathCandidate = _absoluteImageUrl(imagePath);
  final resolvedUrl = imageUrlCandidate.contains('/storage/blob:')
      ? imagePathCandidate
      : imageUrlCandidate.isNotEmpty
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
