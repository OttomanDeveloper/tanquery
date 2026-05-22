class InfiniteData<TPage, TParam> {
  final List<TPage> pages;
  final List<TParam> pageParams;

  const InfiniteData({
    required this.pages,
    required this.pageParams,
  });

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
