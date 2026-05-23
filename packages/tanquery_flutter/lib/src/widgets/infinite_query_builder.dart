import 'package:flutter/widgets.dart';
import 'package:tanquery/tanquery.dart';
import '../provider.dart';

typedef InfiniteQueryWidgetBuilder<TPage, TParam> = Widget Function(
  BuildContext context,
  QueryObserverResult<InfiniteData<TPage, TParam>> state,
  void Function() fetchNextPage,
  void Function() fetchPreviousPage,
);

class InfiniteQueryBuilder<TPage, TParam> extends StatefulWidget {
  final QueryKey queryKey;
  final Future<TPage> Function(TParam pageParam) queryFn;
  final TParam initialPageParam;
  final TParam? Function(TPage lastPage, List<TPage> allPages, TParam lastParam, List<TParam> allParams)?
      getNextPageParam;
  final TParam? Function(TPage firstPage, List<TPage> allPages, TParam firstParam, List<TParam> allParams)?
      getPreviousPageParam;
  final InfiniteQueryWidgetBuilder<TPage, TParam> builder;
  final Duration staleTime;
  final Duration gcTime;
  final bool enabled;
  final int retryCount;
  final int? maxPages;

  const InfiniteQueryBuilder({
    super.key,
    required this.queryKey,
    required this.queryFn,
    required this.initialPageParam,
    this.getNextPageParam,
    this.getPreviousPageParam,
    required this.builder,
    this.staleTime = Duration.zero,
    this.gcTime = const Duration(minutes: 5),
    this.enabled = true,
    this.retryCount = 3,
    this.maxPages,
  });

  @override
  State<InfiniteQueryBuilder<TPage, TParam>> createState() =>
      _InfiniteQueryBuilderState<TPage, TParam>();
}

class _InfiniteQueryBuilderState<TPage, TParam>
    extends State<InfiniteQueryBuilder<TPage, TParam>> {
  QueryObserver<InfiniteData<TPage, TParam>>? _observer;
  Unsubscribe? _unsubscribe;
  bool _isFetchingPage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_observer == null) {
      _createObserver();
      _subscribe();
    }
  }

  @override
  void didUpdateWidget(InfiniteQueryBuilder<TPage, TParam> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queryKey != widget.queryKey ||
        oldWidget.staleTime != widget.staleTime ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.retryCount != widget.retryCount) {
      _unsubscribe?.call();
      _observer?.destroy();
      _createObserver();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _observer?.destroy();
    super.dispose();
  }

  void _createObserver() {
    final client = DartQuery.of(context);
    _observer = QueryObserver<InfiniteData<TPage, TParam>>(
      cache: client.getQueryCache(),
      queryKey: widget.queryKey,
      queryFn: _buildQueryFn(),
      staleTime: widget.staleTime,
      gcTime: widget.gcTime,
      enabled: widget.enabled,
      retryCount: widget.retryCount,
    );
  }

  QueryFn<InfiniteData<TPage, TParam>> _buildQueryFn() {
    return () async {
      final firstPage = await widget.queryFn(widget.initialPageParam);
      return InfiniteData<TPage, TParam>(
        pages: [firstPage],
        pageParams: [widget.initialPageParam],
      );
    };
  }

  void _fetchNextPage() {
    if (!mounted || _isFetchingPage) return;
    final data = _observer?.currentResult.data;
    if (data == null || data.pages.isEmpty) return;

    final nextParam = widget.getNextPageParam?.call(
      data.pages.last, data.pages, data.pageParams.last, data.pageParams,
    );
    if (nextParam == null) return;

    _isFetchingPage = true;
    widget.queryFn(nextParam).then((page) {
      if (!mounted) return;
      final current = _observer?.currentResult.data;
      if (current == null) return;

      final client = DartQuery.of(context);
      final query = client.getQueryCache().find(queryKey: widget.queryKey);
      if (query == null) return;

      var newPages = [...current.pages, page];
      var newParams = [...current.pageParams, nextParam];
      if (widget.maxPages != null && newPages.length > widget.maxPages!) {
        newPages = newPages.sublist(1);
        newParams = newParams.sublist(1);
      }
      query.setData(InfiniteData<TPage, TParam>(pages: newPages, pageParams: newParams));
    }).catchError((_) {}).whenComplete(() => _isFetchingPage = false);
  }

  void _fetchPreviousPage() {
    if (!mounted || _isFetchingPage) return;
    final data = _observer?.currentResult.data;
    if (data == null || data.pages.isEmpty) return;

    final prevParam = widget.getPreviousPageParam?.call(
      data.pages.first, data.pages, data.pageParams.first, data.pageParams,
    );
    if (prevParam == null) return;

    _isFetchingPage = true;
    widget.queryFn(prevParam).then((page) {
      if (!mounted) return;
      final current = _observer?.currentResult.data;
      if (current == null) return;

      final client = DartQuery.of(context);
      final query = client.getQueryCache().find(queryKey: widget.queryKey);
      if (query == null) return;

      var newPages = [page, ...current.pages];
      var newParams = [prevParam, ...current.pageParams];
      if (widget.maxPages != null && newPages.length > widget.maxPages!) {
        newPages = newPages.sublist(0, newPages.length - 1);
        newParams = newParams.sublist(0, newParams.length - 1);
      }
      query.setData(InfiniteData<TPage, TParam>(pages: newPages, pageParams: newParams));
    }).catchError((_) {}).whenComplete(() => _isFetchingPage = false);
  }

  void _subscribe() {
    _unsubscribe = _observer!.subscribe((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_observer == null) return const SizedBox.shrink();
    return widget.builder(context, _observer!.currentResult, _fetchNextPage, _fetchPreviousPage);
  }
}
