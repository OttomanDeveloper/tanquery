T functionalUpdate<T>(Object updater, T input) {
  if (updater is T Function(T)) return updater(input);
  return updater as T;
}
