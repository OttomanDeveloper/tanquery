import 'package:dart_query/dart_query.dart';

Future<List<String>> fetchTodos() async {
  await Future.delayed(const Duration(seconds: 1));
  return ['Buy milk', 'Walk the dog', 'Write code'];
}

void main() async {
  final client = QueryClient();
  client.mount();

  // Fetch and cache data
  final todos = await client.fetchQuery<List<String>>(
    queryKey: QueryKey(['todos']),
    queryFn: fetchTodos,
  );
  print('Fetched ${todos.length} todos');

  // Read from cache
  final cached = client.getQueryData<List<String>>(QueryKey(['todos']));
  print('Cached: $cached');

  // Invalidate (marks as stale)
  await client.invalidateQueries(queryKey: QueryKey(['todos']));
  print('Invalidated todos');

  // Set data manually
  client.setQueryData<List<String>>(
    QueryKey(['todos']),
    (List<String> old) => [...old, 'New todo'],
  );
  print('Updated: ${client.getQueryData<List<String>>(QueryKey(["todos"]))}');

  client.unmount();
}
