import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/core/providers/core_providers.dart';
import 'package:news_application_maker/features/stocks/models/holding.dart';
import 'package:news_application_maker/features/stocks/models/stock_quote.dart';
import 'package:news_application_maker/features/stocks/services/holdings_service.dart';
import 'package:news_application_maker/features/stocks/services/stock_service.dart';

final stockServiceProvider = Provider<StockService>((ref) => const StockService());

final holdingsServiceProvider = Provider<HoldingsService>((ref) {
  return HoldingsService(ref.watch(localStorageProvider));
});

/// The user's holdings list (persisted locally).
class HoldingsNotifier extends StateNotifier<List<Holding>> {
  HoldingsNotifier(this._service) : super(const []) {
    state = _service.loadHoldings();
  }

  final HoldingsService _service;

  Future<void> add(Holding h) async {
    if (state.any((x) => x.code == h.code)) return;
    state = [...state, h];
    await _service.saveHoldings(state);
  }

  Future<void> remove(String code) async {
    state = state.where((x) => x.code != code).toList();
    await _service.saveHoldings(state);
  }

  /// Moves a holding to reorder the list (and persists the new order).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), item);
    state = list;
    await _service.saveHoldings(state);
  }
}

final holdingsProvider =
    StateNotifierProvider<HoldingsNotifier, List<Holding>>((ref) {
  return HoldingsNotifier(ref.watch(holdingsServiceProvider));
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
    this.updatedAt,
    this.loading = false,
    this.error,
  });

  final List<StockQuote> quotes;
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
    state = QuotesState(quotes: cached.quotes, updatedAt: cached.updatedAt);
  }

  final Ref _ref;

  Future<void> refresh() async {
    final holdings = _ref.read(holdingsProvider);
    if (holdings.isEmpty) {
      state = const QuotesState();
      return;
    }
    state = QuotesState(
        quotes: state.quotes, updatedAt: state.updatedAt, loading: true);
    try {
      final quotes = await _ref.read(stockServiceProvider).quotes(holdings);
      final now = DateTime.now();
      await _ref.read(holdingsServiceProvider).saveQuotes(quotes, now);
      state = QuotesState(quotes: quotes, updatedAt: now);
    } catch (e) {
      state = QuotesState(
        quotes: state.quotes,
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
