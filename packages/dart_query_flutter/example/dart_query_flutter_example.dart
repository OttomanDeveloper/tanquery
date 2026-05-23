import 'package:flutter/material.dart';
import 'package:dart_query_flutter/dart_query_flutter.dart';

Future<List<String>> fetchTodos() async {
  await Future.delayed(const Duration(seconds: 1));
  return ['Buy milk', 'Walk the dog', 'Write code'];
}

void main() {
  final queryClient = QueryClient();
  runApp(
    DartQueryProvider(
      client: queryClient,
      child: const MaterialApp(home: TodoScreen()),
    ),
  );
}

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('dart_query_flutter example')),
      body: QueryBuilder<List<String>>(
        queryKey: QueryKey(['todos']),
        queryFn: fetchTodos,
        staleTime: const Duration(minutes: 5),
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.isError) {
            return Center(child: Text('Error: ${state.error}'));
          }
          return ListView(
            children: state.data!.map((todo) => ListTile(title: Text(todo))).toList(),
          );
        },
      ),
    );
  }
}
