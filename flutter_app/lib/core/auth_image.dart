import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'auth_events.dart';

/// An image widget that loads images through the authenticated Dio client.
/// Use this for files behind protected endpoints (e.g., /api/v1/uploads/...).
class AuthImage extends ConsumerWidget {
  const AuthImage({
    super.key,
    required this.url,
    this.fit,
    this.width,
    this.height,
    this.fallback,
  });

  final String url;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dio = ref.watch(dioProvider);

    return FutureBuilder<Uint8List?>(
      future: _loadBytes(dio),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: width,
            height: height,
            child: fallback,
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            width: width,
            height: height,
            child: fallback,
          );
        }
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return SizedBox(
            width: width,
            height: height,
            child: fallback,
          );
        }
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => SizedBox(
            width: width,
            height: height,
            child: fallback,
          ),
        );
      },
    );
  }

  Future<Uint8List?> _loadBytes(Dio dio) async {
    try {
      final response = await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data as Uint8List?;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        AuthEvents.instance.broadcastLogout();
      }
      return null;
    }
  }
}
