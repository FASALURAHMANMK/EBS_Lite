class OutboxState {
  const OutboxState({
    this.isOnline = false,
    this.hasConnectivity = true,
    this.isChecking = true,
    this.queuedCount = 0,
    this.isSyncing = false,
    this.lastError,
    this.lastSyncAt,
  });

  final bool isOnline;
  final bool hasConnectivity;
  final bool isChecking;
  final int queuedCount;
  final bool isSyncing;
  final String? lastError;
  final DateTime? lastSyncAt;

  OutboxState copyWith({
    bool? isOnline,
    bool? hasConnectivity,
    bool? isChecking,
    int? queuedCount,
    bool? isSyncing,
    String? lastError,
    DateTime? lastSyncAt,
  }) {
    return OutboxState(
      isOnline: isOnline ?? this.isOnline,
      hasConnectivity: hasConnectivity ?? this.hasConnectivity,
      isChecking: isChecking ?? this.isChecking,
      queuedCount: queuedCount ?? this.queuedCount,
      isSyncing: isSyncing ?? this.isSyncing,
      lastError: lastError,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}
