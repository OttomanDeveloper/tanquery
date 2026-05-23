import 'package:flutter/widgets.dart';
import 'package:dart_query/dart_query.dart';
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
    if (oldWidget.queryKey != widget.queryKey) {
      _unsubscribe?.call();
      _observer?.destroy();
      _createObserver();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  void _createObserver() {
    final client = DartQuery.of(context);
    _observer = QueryObserver<InfiniteData<TPage, TParam>>(
      cache: client.getQueryCache(),
      queryKey: widget.queryKey,
      queryFn: _buildInfiniteQueryFn(),
      staleTime: widget.staleTime,
      gcTime: widget.gcTime,
      enabled: widget.enabled,
      retryCount: widget.retryCount,
    );
  }

  QueryFn<InfiniteData<TPage, TParam>> _buildInfiniteQueryFn() {
    return () async {
      final firstPage = await widget.queryFn(widget.initialPageParam);
      return InfiniteData<TPage, TParam>(
        pages: [firstPage],
        pageParams: [widget.initialPageParam],
      );
    };
  }

  void _fetchNextPage() {
    final data = _observer?.currentResult.data;
    if (data == null || data.pages.isEmpty) return;
    final nextParam = widget.getNextPageParam?.call(
      data.pages.last,
      data.pages,
      data.pageParams.last,
      data.pageParams,
    );
    if (nextParam == null) return;

    final client = DartQuery.of(context);
    final cache = client.getQueryCache();
    final query = cache.find(queryKey: widget.queryKey);
    if (query == null) return;

    final currentData = data;
    query.setData(
      InfiniteData<TPage, TParam>(
        pages: currentData.pages,
        pageParams: currentData.pageParams,
      ),
    );

    widget.queryFn(nextParam).then((page) {
      query.setData(
        InfiniteData<TPage, TParam>(
          pages: [...currentData.pages, page],
          pageParams: [...currentData.pageParams, nextParam],
        ),
      );
    });
  }

  void _fetchPreviousPage() {
    final data = _observer?.currentResult.data;
    if (data == null || data.pages.isEmpty) return;
    final prevParam = widget.getPreviousPageParam?.call(
      data.pages.first,
      data.pages,
      data.pageParams.first,
      data.pageParams,
    );
    if (prevParam == null) return;

    final client = DartQuery.of(context);
    final cache = client.getQueryCache();
    final query = cache.find(queryKey: widget.queryKey);
    if (query == null) return;

    final currentData = data;
    widget.queryFn(prevParam).then((page) {
      query.setData(
        InfiniteData<TPage, TParam>(
          pages: [page, ...currentData.pages],
          pageParams: [prevParam, ...currentData.pageParams],
        ),
      );
    });
  }

  void _subscribe() {
    _unsubscribe = _observer!.subscribe((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_observer == null) return const SizedBox.shrink();
    return widget.builder(
      context,
      _observer!.currentResult,
      _fetchNextPage,
      _fetchPreviousPage,
    );
  }
}
