import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../domain/model/drama.dart';

/// High-throughput persistent HTTP keep-alive image cache manager for TMDB posters & cast photos.
/// - Reuses up to 12 pooled TCP/TLS connections per host (eliminates repeated TLS handshakes).
/// - Stores up to 1,500 images on disk for 30 days.
/// - Automatically retries transient socket/timeout failures once.
class MoglogImageCacheManager extends CacheManager with ImageCacheManager {
  static const String cacheKey = 'moglogImageCacheV2';

  static final MoglogImageCacheManager instance = MoglogImageCacheManager._();

  MoglogImageCacheManager._()
      : super(
          Config(
            cacheKey,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 1500,
            repo: JsonCacheInfoRepository(databaseName: cacheKey),
            fileService: _PooledDioFileService(),
          ),
        );

  /// Pre-warms a list of poster/avatar URLs with bounded concurrency so grids and cast rails render instantly.
  static Future<void> prewarmUrls(
    Iterable<String> rawUrls, {
    double? targetWidthDp,
    int maxConcurrent = 6,
    void Function(int done, int total)? onProgress,
  }) async {
    final urls = rawUrls
        .map((u) => optimizeTmdbImageUrl(u, targetWidthDp: targetWidthDp))
        .where((u) => u.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (urls.isEmpty) return;

    var done = 0;
    var nextIndex = 0;
    final total = urls.length;
    final workerCount = maxConcurrent.clamp(1, total);

    Future<void> worker() async {
      while (true) {
        final idx = nextIndex++;
        if (idx >= total) break;
        try {
          await instance
              .getSingleFile(urls[idx])
              .timeout(const Duration(seconds: 10));
        } catch (_) {}
        done++;
        onProgress?.call(done, total);
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));
  }
}

class _PooledDioFileService extends FileService {
  late final Dio _dio;

  _PooledDioFileService() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 8),
        responseType: ResponseType.stream,
        followRedirects: true,
        maxRedirects: 4,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.maxConnectionsPerHost = 12;
        client.idleTimeout = const Duration(seconds: 30);
        client.connectionTimeout = const Duration(seconds: 8);
        client.autoUncompress = true;
        return client;
      },
    );
  }

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    DioException? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _dio.get<ResponseBody>(
          url,
          options: Options(
            headers: headers,
            responseType: ResponseType.stream,
          ),
        );
        return _DioFileServiceResponse(response);
      } on DioException catch (e) {
        lastError = e;
        if (attempt == 0 && _isRetryable(e)) {
          await Future<void>.delayed(const Duration(milliseconds: 220));
          continue;
        }
        rethrow;
      }
    }
    throw lastError ?? Exception('Failed to fetch $url');
  }

  bool _isRetryable(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.unknown;
}

class _DioFileServiceResponse implements FileServiceResponse {
  final Response<ResponseBody> _response;
  final DateTime _receivedTime = DateTime.now();

  _DioFileServiceResponse(this._response);

  String? _header(String name) => _response.headers.value(name);

  @override
  Stream<List<int>> get content =>
      _response.data?.stream.cast<List<int>>() ?? const Stream.empty();

  @override
  int? get contentLength {
    final raw = _header(Headers.contentLengthHeader);
    return raw != null ? int.tryParse(raw) : null;
  }

  @override
  int get statusCode => _response.statusCode ?? 500;

  @override
  DateTime get validTill {
    var ageDuration = const Duration(days: 30);
    final controlHeader = _header('cache-control');
    if (controlHeader != null) {
      for (final setting in controlHeader.split(',')) {
        final trimmed = setting.trim().toLowerCase();
        if (trimmed == 'no-cache') {
          ageDuration = Duration.zero;
        } else if (trimmed.startsWith('max-age=')) {
          final secs = int.tryParse(trimmed.substring(8)) ?? 0;
          if (secs > 0) {
            ageDuration = Duration(seconds: secs);
          }
        }
      }
    }
    return _receivedTime.add(ageDuration);
  }

  @override
  String? get eTag => _header('etag');

  @override
  String get fileExtension {
    final contentType = _header(Headers.contentTypeHeader)?.toLowerCase() ?? '';
    if (contentType.contains('png')) return '.png';
    if (contentType.contains('webp')) return '.webp';
    if (contentType.contains('gif')) return '.gif';
    if (contentType.contains('jpeg') || contentType.contains('jpg')) {
      return '.jpg';
    }
    final path = _response.realUri.path.toLowerCase();
    for (final ext in const ['.webp', '.png', '.jpg', '.jpeg', '.gif']) {
      if (path.endsWith(ext)) return ext;
    }
    return '.jpg';
  }
}
