import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../widgets/shimmer_placeholder.dart';

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

  if (cleaned.startsWith('/')) {
    var path = cleaned.replaceFirst(RegExp(r'^/+'), '');
    if (path.startsWith('q-less/')) {
      path = path.substring('q-less/'.length);
    }
    return apiUrl(getBaseUrl(), path);
  }

  return apiUrl(getBaseUrl(), cleaned);
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

int? _cacheWidthForDisplay(double? width, BuildContext context) {
  if (width == null) return 480;
  final ratio = MediaQuery.devicePixelRatioOf(context);
  return (width * ratio).round().clamp(120, 900);
}

Widget buildProductImage(
  String imagePath,
  String imageUrl, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget? placeholder,
  BuildContext? context,
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
    final cacheWidth =
        context != null ? _cacheWidthForDisplay(width, context) : 480;
    final loadingWidget = ShimmerPlaceholder(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(12),
    );

    return Image.network(
      resolvedUrl,
      fit: fit,
      width: width,
      height: height,
      filterQuality: FilterQuality.medium,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          placeholder ?? const Icon(Icons.image_not_supported_outlined),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return loadingWidget;
      },
    );
  }

  return placeholder ??
      const Center(child: Icon(Icons.image_not_supported_outlined));
}

/// Avatar circular del usuario (perfil / chatbot).
Widget buildUserAvatar({
  required String avatarPath,
  required String avatarUrl,
  double size = 36,
}) {
  final resolvedUrl = avatarUrl.isNotEmpty ? avatarUrl : getImageUrl(avatarPath);
  final hasImage = avatarPath.isNotEmpty || resolvedUrl.isNotEmpty;

  return ClipRRect(
    borderRadius: BorderRadius.circular(size / 2),
    child: SizedBox(
      width: size,
      height: size,
      child: hasImage
          ? buildProductImage(
              avatarPath,
              resolvedUrl,
              fit: BoxFit.cover,
              width: size,
              height: size,
              placeholder: _avatarPlaceholder(size),
            )
          : _avatarPlaceholder(size),
    ),
  );
}

Widget _avatarPlaceholder(double size) {
  return Container(
    width: size,
    height: size,
    color: const Color(0xFF3EC13B),
    alignment: Alignment.center,
    child: Icon(Icons.person, color: Colors.white, size: size * 0.55),
  );
}
