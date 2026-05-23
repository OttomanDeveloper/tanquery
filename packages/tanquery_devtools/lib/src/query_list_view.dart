import 'package:flutter/material.dart';
import 'package:tanquery/tanquery.dart';
import 'status_badge.dart';

class QueryListView extends StatelessWidget {
  final List<Query> queries;
  final void Function(Query query) onQueryTap;
  final String filterText;
  final String? statusFilter;

  const QueryListView({
    super.key,
    required this.queries,
    required this.onQueryTap,
    this.filterText = '',
    this.statusFilter,
  });

  @override
  Widget build(BuildContext context) {
    var filtered = queries;
    if (filterText.isNotEmpty) {
      filtered = filtered
          .where((q) => q.queryKey.parts.join(', ').toLowerCase().contains(filterText.toLowerCase()))
          .toList();
    }

    if (filtered.isEmpty) {
      return const Center(
        child: Text('No queries', style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final query = filtered[index];
        final age = query.state.dataUpdatedAt != null
            ? _formatAge(DateTime.now().difference(query.state.dataUpdatedAt!))
            : '-';

        return InkWell(
          onTap: () => onQueryTap(query),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                StatusBadge(
                  status: query.state.status,
                  fetchStatus: query.state.fetchStatus,
                  isStale: query.isStaleByTime(Duration.zero),
                  isActive: query.isActive(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    query.queryKey.parts.join(', '),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(age, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(width: 4),
                Text(
                  '${query.observerCount}',
                  style: TextStyle(
                    fontSize: 10,
                    color: query.isActive() ? Colors.blue : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatAge(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }
}
