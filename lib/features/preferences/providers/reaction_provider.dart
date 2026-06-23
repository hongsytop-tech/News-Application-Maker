import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:news_application_maker/core/providers/core_providers.dart';
import 'package:news_application_maker/features/news_feed/models/news_article.dart';
import 'package:news_application_maker/features/preferences/providers/recommendation_provider.dart';
import 'package:news_application_maker/features/preferences/services/event_service.dart';
import 'package:news_application_maker/features/preferences/services/reaction_service.dart';
import 'package:news_application_maker/features/trash/providers/trash_provider.dart';

const kLike = 'like';
const kDislike = 'dislike';

final reactionServiceProvider = Provider<ReactionService>((ref) {
  return ReactionService(ref.watch(localStorageProvider));
});

/// Holds each article's like/dislike state (url -> 'like' | 'dislike') and
/// records the corresponding preference event when a reaction is set.
class ReactionNotifier extends StateNotifier<Map<String, String>> {
  ReactionNotifier(this._service, this._ref) : super(const {}) {
    state = _service.load();
  }

  final ReactionService _service;
  final Ref _ref;

  /// Sets [reaction] (kLike/kDislike) for [article], or clears it if the same
  /// reaction is tapped again. Records a preference event when newly set.
  /// Disliking also moves the article to "확인한 뉴스" (hides it from the feed);
  /// clearing a dislike brings it back.
  Future<void> toggle(NewsArticle article, String reaction) async {
    final url = article.url;
    final wasDisliked = state[url] == kDislike;
    final next = Map<String, String>.from(state);
    if (next[url] == reaction) {
      next.remove(url); // tapping the active reaction clears it
    } else {
      next[url] = reaction;
      _ref.read(recommendationProvider.notifier).record(
            reaction == kLike ? EventType.like : EventType.dislike,
            article,
          );
    }
    state = next;
    await _service.save(next);

    final nowDisliked = next[url] == kDislike;
    if (nowDisliked && !wasDisliked) {
      await _ref.read(trashProvider.notifier).trash(article);
    } else if (!nowDisliked && wasDisliked) {
      await _ref.read(trashProvider.notifier).restore(url);
    }
  }
}

final reactionsProvider =
    StateNotifierProvider<ReactionNotifier, Map<String, String>>((ref) {
  return ReactionNotifier(ref.watch(reactionServiceProvider), ref);
});
