/// Container for paginated data in infinite queries.
///
/// Each element in [pages] corresponds to one page of results.
/// The matching element in [pageParams] holds the parameter used to fetch
/// that page (e.g. a cursor or page number).
class InfiniteData<TPage, TParam> {
  /// The fetched pages in order.
  final List<TPage> pages;

  /// The parameter used to fetch each corresponding page.
  final List<TParam> pageParams;

  /// Creates infinite data with the given [pages] and [pageParams].
  const InfiniteData({
    required this.pages,
    required this.pageParams,
  });

  /// Returns a copy with the specified fields replaced.
  InfiniteData<TPage, TParam> copyWith({
    List<TPage>? pages,
    List<TParam>? pageParams,
  }) {
    return InfiniteData(
      pages: pages ?? this.pages,
      pageParams: pageParams ?? this.pageParams,
    );
  }
}
