import 'dart:math';

/// Exact 1:1 port of `AboutScreen.kt` semantic version comparison & URL host allowlist.
List<int> parseVersionSegments(String raw) {
  var cleaned = raw.trim();
  if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
    cleaned = cleaned.substring(1);
  }
  final parts = cleaned.split('.');
  final result = <int>[];
  for (var idx = 0; idx < parts.length; idx++) {
    final part = parts[idx];
    // Treat 2-digit patch like "3.0.71" as [3, 0, 7, 1] so 3.0.8 > 3.0.71 > 3.0.7
    if (idx == 2 && part.length == 2 && RegExp(r'^\d\d$').hasMatch(part)) {
      result.add(int.parse(part[0]));
      result.add(int.parse(part[1]));
    } else {
      final digits = part.replaceAll(RegExp(r'[^0-9]'), '');
      result.add(int.tryParse(digits) ?? 0);
    }
  }
  return result;
}

bool isNewerVersion({required String current, required String latest}) {
  final curParts = parseVersionSegments(current);
  final latParts = parseVersionSegments(latest);
  final maxLen = max(curParts.length, latParts.length);
  for (var i = 0; i < maxLen; i++) {
    final c = i < curParts.length ? curParts[i] : 0;
    final l = i < latParts.length ? latParts[i] : 0;
    if (l > c) return true;
    if (l < c) return false;
  }
  return false;
}

const Set<String> kTrustedUpdateHosts = {
  'github.com',
  'objects.githubusercontent.com',
  'release-assets.githubusercontent.com',
  'moglog-instructions.vercel.app',
};

String sanitizeTrustedUpdateUrl(String rawUrl, String fallbackUrl) {
  try {
    final uri = Uri.parse(rawUrl.trim());
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    if (scheme == 'https' &&
        (kTrustedUpdateHosts.contains(host) ||
            host.endsWith('.githubusercontent.com'))) {
      return rawUrl.trim();
    }
    return fallbackUrl;
  } catch (_) {
    return fallbackUrl;
  }
}
