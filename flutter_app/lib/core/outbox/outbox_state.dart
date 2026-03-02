class OutboxState {
  const OutboxState({
    this.isOnline = true,
    this.queuedCount = 0,
    this.isSyncing = false,
    this.lastError,
    this.lastSyncAt,
  });

  final bool isOnline;
  final int queuedCount;
  final bool isSyncing;
  final String? lastError;
  final DateTime? lastSyncAt;

  OutboxState copyWith({
    bool? isOnline,
    int? queuedCount,
    bool? isSyncing,
    String? lastError,
    DateTime? lastSyncAt,
  }) {
    return OutboxState(
      isOnline: isOnline ?? this.isOnline,
      queuedCount: queuedCount ?? this.queuedCount,
      isSyncing: isSyncing ?? this.isSyncing,
      lastError: lastError,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}
