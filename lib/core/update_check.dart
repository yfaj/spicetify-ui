import 'dart:convert';
import 'dart:io';

/// Owner/repo the releases are published to.
const releaseRepoUrl = 'https://github.com/yfaj/spicetify-ui';

/// Fetches the latest published release tag (e.g. "v1.1.0") from GitHub.
/// Returns null on any network failure — update checks must never break
/// the app or log scary errors when offline.
Future<String?> fetchLatestReleaseTag({
  HttpClient Function()? clientFactory,
}) async {
  final client = (clientFactory ?? HttpClient.new)();
  try {
    final request = await client.getUrl(
      Uri.parse(
        'https://api.github.com/repos/yfaj/spicetify-ui/releases/latest',
      ),
    );
    request.headers.set('Accept', 'application/vnd.github+json');
    request.headers.set('User-Agent', 'spicetify-ui');
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) return null;
    final tag = json['tag_name'];
    return tag is String && tag.isNotEmpty ? tag : null;
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Strips a leading "v" and any build suffix ("+2") so "v1.1.0" and
/// "1.1.0+2" compare cleanly.
List<int> _parseVersion(String version) {
  final cleaned = version.replaceFirst(RegExp(r'^v'), '').split('+').first;
  return cleaned.split('.').map((part) => int.tryParse(part) ?? 0).toList();
}

/// True when [latest] is strictly newer than [current].
bool isNewerVersion(String current, String latest) {
  final a = _parseVersion(current);
  final b = _parseVersion(latest);
  for (var i = 0; i < 3; i++) {
    final left = i < a.length ? a[i] : 0;
    final right = i < b.length ? b[i] : 0;
    if (right > left) return true;
    if (right < left) return false;
  }
  return false;
}

/// Opens the release page in the system browser. Fire-and-forget: a failure
/// to launch is logged by the caller, not thrown.
Future<bool> openReleasePage() async {
  try {
    if (Platform.isWindows) {
      final result = await Process.run('cmd', [
        '/c',
        'start',
        '',
        releaseRepoUrl,
      ]);
      return result.exitCode == 0;
    }
    if (Platform.isMacOS) {
      final result = await Process.run('open', [releaseRepoUrl]);
      return result.exitCode == 0;
    }
    final result = await Process.run('xdg-open', [releaseRepoUrl]);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
