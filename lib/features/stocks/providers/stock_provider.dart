import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/core/providers/core_providers.dart';
import 'package:news_application_maker/features/auth/providers/auth_provider.dart';
import 'package:news_application_maker/features/stocks/models/holding.dart';
import 'package:news_application_maker/features/stocks/models/stock_quote.dart';
import 'package:news_application_maker/features/stocks/services/holdings_service.dart';
import 'package:news_application_maker/features/stocks/services/stock_service.dart';

final stockServiceProvider = Provider<StockService>((ref) => const StockService());

final holdingsServiceProvider = Provider<HoldingsService>((ref) {
  return HoldingsService(ref.watch(localStorageProvider));
});

/// Cross-device sync status for the holdings list, surfaced in the UI so
/// failures (not signed in, RLS/permission errors, network) are visible
/// instead of silently swallowed.
class HoldingsSync {
  const HoldingsSync({this.syncing = false, this.error, this.signedIn = false});

  final bool syncing;
  final String? error;
  final bool signedIn;

  HoldingsSync copyWith({bool? syncing, String? error, bool? signedIn}) =>
      HoldingsSync(
        syncing: syncing ?? this.syncing,
        error: error,
        signedIn: signedIn ?? this.signedIn,
      );
}

final holdingsSyncProvider =
    StateProvider<HoldingsSync>((ref) => const HoldingsSync());

/// The user's holdings list. Loads the local copy immediately and re-syncs
/// from Supabase whenever auth state changes (so it follows the user across
/// devices).
class HoldingsNotifier extends StateNotifier<List<Holding>> {
  HoldingsNotifier(this._service, this._ref) : super(const []) {
    state = _service.loadHoldings();

    _ref.listen(authStateProvider, (_, next) {
      _statusUpdate();
      if (next.valueOrNull != null) {
        sync();
      } else {
        state = _service.loadHoldings();
      }
    });

    // Defer writes to holdingsSyncProvider out of this notifier's build phase
    // (Riverpod forbids modifying another provider during initialization).
    // The listener above only fires on auth *transitions*, so if the user is
    // already signed in when this notifier is created, sync explicitly here.
    Future.microtask(() {
      if (!mounted) return;
      _statusUpdate();
      if (_service.isSignedIn) sync();
    });
  }

  final HoldingsService _service;
  final Ref _ref;

  HoldingsSync get _status => _ref.read(holdingsSyncProvider);
  set _status(HoldingsSync s) {
    if (!mounted) return;
    _ref.read(holdingsSyncProvider.notifier).state = s;
  }

  void _statusUpdate() {
    _status = _status.copyWith(signedIn: _service.isSignedIn);
  }

  /// Pulls the signed-in user's holdings from Supabase into local state.
  /// Records any backend error into [holdingsSyncProvider] so the UI can show
  /// it, rather than failing silently.
  Future<void> sync() async {
    _status = HoldingsSync(syncing: true, signedIn: _service.isSignedIn);
    try {
      final result = await _service.syncFromRemote();
      if (!mounted) return;
      state = result;
      _status = HoldingsSync(signedIn: _service.isSignedIn);
    } catch (e) {
      _status = HoldingsSync(signedIn: _service.isSignedIn, error: e.toString());
    }
  }

  Future<void> _persist() async {
    try {
      await _service.saveHoldings(state);
      _status = HoldingsSync(signedIn: _service.isSignedIn);
    } catch (e) {
      _status = HoldingsSync(signedIn: _service.isSignedIn, error: e.toString());
    }
  }

  Future<void> add(Holding h) async {
    if (state.any((x) => x.code == h.code)) return;
    state = [...state, h];
    await _persist();
  }

  Future<void> remove(String code) async {
    state = state.where((x) => x.code != code).toList();
    await _persist();
  }

  /// Moves a holding to reorder the list (and persists the new order).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), item);
    state = list;
    await _persist();
  }
}

final holdingsProvider =
    StateNotifierProvider<HoldingsNotifier, List<Holding>>((ref) {
  return HoldingsNotifier(ref.watch(holdingsServiceProvider), ref);
});

/// Search results for the add-holding flow.
final stockSearchProvider = FutureProvider.autoDispose
    .family<List<Holding>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  return ref.watch(stockServiceProvider).search(q);
});

/// Quotes for the held stocks; refreshed only on explicit user request.
class QuotesState {
  const QuotesState({
    this.quotes = const [],
    this.indices = const [],
    this.updatedAt,
    this.loading = false,
    this.error,
  });

  final List<StockQuote> quotes;
  final List<StockQuote> indices; // 코스피, 코스닥 (fixed at the top)
  final DateTime? updatedAt;
  final bool loading;
  final String? error;

  StockQuote? forCode(String code) {
    for (final q in quotes) {
      if (q.code == code) return q;
    }
    return null;
  }
}

class QuotesController extends StateNotifier<QuotesState> {
  QuotesController(this._ref) : super(const QuotesState()) {
    final cached = _ref.read(holdingsServiceProvider).loadQuotes();
    state = QuotesState(
      quotes: cached.quotes,
      indices: cached.indices,
      updatedAt: cached.updatedAt,
    );
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = QuotesState(
      quotes: state.quotes,
      indices: state.indices,
      updatedAt: state.updatedAt,
      loading: true,
    );
    try {
      final r =
          await _ref.read(stockServiceProvider).quotes(_ref.read(holdingsProvider));
      final now = DateTime.now();
      await _ref
          .read(holdingsServiceProvider)
          .saveQuotes(r.quotes, r.indices, now);
      state = QuotesState(quotes: r.quotes, indices: r.indices, updatedAt: now);
    } catch (e) {
      state = QuotesState(
        quotes: state.quotes,
        indices: state.indices,
        updatedAt: state.updatedAt,
        error: e.toString(),
      );
    }
  }
}

final quotesControllerProvider =
    StateNotifierProvider<QuotesController, QuotesState>((ref) {
  return QuotesController(ref);
});
