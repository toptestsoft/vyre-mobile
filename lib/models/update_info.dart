class UpdateInfo {
  final bool hasUpdate;
  final String version;
  final String releaseNotes;
  final String? downloadUrl;
  final String? error;

  const UpdateInfo({
    required this.hasUpdate,
    required this.version,
    required this.releaseNotes,
    this.downloadUrl,
    this.error,
  });
}
