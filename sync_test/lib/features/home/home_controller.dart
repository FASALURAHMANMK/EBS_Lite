import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_providers.dart';
import '../../data/repositories/product_repo.dart';
import '../../data/repositories/sale_repo.dart';

class HomeState {
  final bool running;
  final String log;
  const HomeState({required this.running, required this.log});
  HomeState copyWith({bool? running, String? log}) => HomeState(
    running: running ?? this.running,
    log: log ?? this.log,
  );
}

class HomeController extends StateNotifier<HomeState> {
  HomeController(this.ref) : super(const HomeState(running: false, log: ''));
  final Ref ref;
  StreamSubscription<String>? _sub;

  Future<void> startSync() async {
    final engine = ref.read(syncEngineProvider);
    _sub?.cancel();
    _sub = engine.logStream.listen((e) => _append(e));
    await engine.start();
    state = state.copyWith(running: true);
  }

  Future<void> stopSync() async {
    final engine = ref.read(syncEngineProvider);
    await engine.stop();
    _sub?.cancel();
    state = state.copyWith(running: false);
  }

  void _append(String s) {
    state = state.copyWith(log: '${state.log}$s\n');
  }

  Future<void> seedLocalData() async {
    final products = ref.read(productRepoProvider);
    final sales = ref.read(saleRepoProvider);
    await products.seedSamples();
    await sales.seedSamples();
    _append('Seeded local sample data.');
  }

  Future<void> makeLocalChange() async {
    final products = ref.read(productRepoProvider);
    await products.insertRandom();
    _append('Inserted a random local product (queued in outbox).');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final homeControllerProvider = StateNotifierProvider<HomeController, HomeState>((ref) => HomeController(ref));