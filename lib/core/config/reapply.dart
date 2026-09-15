String stripGitHash(String version) {
  final index = version.indexOf('.g');
  return index == -1 ? version : version.substring(0, index);
}

bool needsReapply({required String? backupVersion, required String? spotifyVersion}) {
  if (backupVersion == null || backupVersion.isEmpty) return false;
  if (spotifyVersion == null || spotifyVersion.isEmpty) return false;
  return stripGitHash(backupVersion) != spotifyVersion;
}
