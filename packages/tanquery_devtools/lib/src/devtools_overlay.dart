import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tanquery/tanquery.dart';
import 'package:tanquery_flutter/tanquery_flutter.dart';
import 'query_list_view.dart';
import 'query_detail_view.dart';
import 'mutation_log_view.dart';

class DartQueryDevtools extends StatefulWidget {
  final bool enabled;
  final Widget child;

  const DartQueryDevtools({
    super.key,
    this.enabled = true,
    required this.child,
  });

  @override
  State<DartQueryDevtools> createState() => _DartQueryDevtoolsState();
}

class _DartQueryDevtoolsState extends State<DartQueryDevtools> {
  bool _isOpen = false;
  int _tabIndex = 0; // 0=queries, 1=mutations
  Query? _selectedQuery;
  String _filterText = '';
  Unsubscribe? _queryCacheUnsub;
  Unsubscribe? _mutationCacheUnsub;
  String? _statusFilter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToCaches();
  }

  @override
  void dispose() {
    _queryCacheUnsub?.call();
    _mutationCacheUnsub?.call();
    super.dispose();
  }

  void _subscribeToCaches() {
    _queryCacheUnsub?.call();
    _mutationCacheUnsub?.call();

    if (!widget.enabled) return;

    try {
      final client = DartQuery.of(context);
      _queryCacheUnsub = client.getQueryCache().subscribe((_) {
        if (mounted) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
      });
      _mutationCacheUnsub = client.getMutationCache().subscribe((_) {
        if (mounted) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Stack(
      children: [
        widget.child,
        if (_isOpen) _buildPanel(context),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'tanquery_devtools',
            onPressed: () => setState(() => _isOpen = !_isOpen),
            backgroundColor: _isOpen ? Colors.red : Colors.deepPurple,
            child: Icon(_isOpen ? Icons.close : Icons.bug_report, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context) {
    final client = DartQuery.of(context);
    final queryCache = client.getQueryCache();
    final mutationCache = client.getMutationCache();

    return Positioned(
      left: 16,
      right: 80,
      bottom: 80,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 360),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    _TabButton(
                      label: 'Queries (${queryCache.getAll().length})',
                      isSelected: _tabIndex == 0,
                      onTap: () => setState(() {
                        _tabIndex = 0;
                        _selectedQuery = null;
                      }),
                    ),
                    _TabButton(
                      label: 'Mutations (${mutationCache.getAll().length})',
                      isSelected: _tabIndex == 1,
                      onTap: () => setState(() {
                        _tabIndex = 1;
                        _selectedQuery = null;
                      }),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        client.clear();
                        setState(() => _selectedQuery = null);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.delete_sweep, size: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),

              // Filter
              if (_tabIndex == 0 && _selectedQuery == null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: TextField(
                    onChanged: (v) => setState(() => _filterText = v),
                    decoration: const InputDecoration(
                      hintText: 'Filter by key...',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(),
                      hintStyle: TextStyle(fontSize: 11),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final status in [null, 'fresh', 'stale', 'fetching', 'paused', 'error', 'inactive'])
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: GestureDetector(
                              onTap: () => setState(() => _statusFilter = status == _statusFilter ? null : status),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _statusFilter == status ? Colors.deepPurple : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status ?? 'all',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _statusFilter == status ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              // Content
              Expanded(
                child: _tabIndex == 0
                    ? _selectedQuery != null
                        ? QueryDetailView(
                            query: _selectedQuery!,
                            onBack: () => setState(() => _selectedQuery = null),
                            onInvalidate: () {
                              _selectedQuery!.invalidate();
                              setState(() {});
                            },
                            onRemove: () {
                              queryCache.remove(_selectedQuery!);
                              setState(() => _selectedQuery = null);
                            },
                            onRefetch: () {
                              _selectedQuery!.fetch().then((_) {}).catchError((_) {});
                              setState(() {});
                            },
                            onReset: () {
                              _selectedQuery!.reset();
                              setState(() {});
                            },
                          )
                        : QueryListView(
                            queries: queryCache.getAll(),
                            onQueryTap: (q) => setState(() => _selectedQuery = q),
                            filterText: _filterText,
                            statusFilter: _statusFilter,
                          )
                    : MutationLogView(mutations: mutationCache.getAll()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.deepPurple : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.deepPurple : Colors.grey,
          ),
        ),
      ),
    );
  }
}
