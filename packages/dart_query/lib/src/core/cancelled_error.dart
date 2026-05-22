class CancelledError extends Error {
  final bool revert;
  final bool silent;

  CancelledError({this.revert = false, this.silent = false});

  @override
  String toString() => 'CancelledError(revert: $revert, silent: $silent)';
}

bool isCancelledError(Object error) => error is CancelledError;
