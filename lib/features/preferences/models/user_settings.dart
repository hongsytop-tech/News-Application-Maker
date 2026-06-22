import 'package:news_application_maker/features/news_feed/models/news_category.dart';

/// User-controlled app settings. Currently the set of categories the user
/// wants to see in their feed.
class UserSettings {
  const UserSettings({required this.enabledCategoryIds});

  /// Ids of [NewsCategory] the user has enabled. Empty means "the defaults"
  /// (main topics only); sub-topics are opt-in.
  final Set<String> enabledCategoryIds;

  static Set<String> get _defaultIds =>
      {for (final c in NewsCategory.defaults) c.id};

  /// Default: only the main topics enabled (sub-topics off).
  factory UserSettings.initial() =>
      UserSettings(enabledCategoryIds: _defaultIds);

  /// Resolves to the ordered list of enabled categories (falls back to
  /// defaults when nothing is configured).
  List<NewsCategory> get enabledCategories {
    final ids = enabledCategoryIds.isEmpty ? _defaultIds : enabledCategoryIds;
    final list = [
      for (final c in NewsCategory.all)
        if (ids.contains(c.id)) c,
    ];
    return list.isEmpty ? NewsCategory.defaults : list;
  }

  bool isEnabled(String categoryId) =>
      (enabledCategoryIds.isEmpty ? _defaultIds : enabledCategoryIds)
          .contains(categoryId);

  UserSettings toggle(String categoryId) {
    final next = Set<String>.from(
      enabledCategoryIds.isEmpty ? _defaultIds : enabledCategoryIds,
    );
    if (next.contains(categoryId)) {
      next.remove(categoryId);
    } else {
      next.add(categoryId);
    }
    return UserSettings(enabledCategoryIds: next);
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    final list = (json['enabled_categories'] as List?) ?? const [];
    return UserSettings(
      enabledCategoryIds: list.map((e) => e.toString()).toSet(),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled_categories': enabledCategoryIds.toList(),
      };
}
