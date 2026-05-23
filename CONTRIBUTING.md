# Contributing to tanquery

Thanks for wanting to contribute. Here's how to get started.

## Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/OttomanDeveloper/tanquery.git
   cd tanquery
   ```

2. Install dependencies for all packages:
   ```bash
   dart pub get
   ```

   This is a Dart workspace monorepo. Running `dart pub get` at the root resolves dependencies for all three packages.

3. (Optional) Install [melos](https://melos.invertase.dev/) for running commands across packages:
   ```bash
   dart pub global activate melos
   ```

## Project structure

```
tanquery/
  packages/
    tanquery/           # Pure Dart core (no Flutter dependency)
    tanquery_flutter/   # Flutter widget builders
    tanquery_devtools/  # Visual cache inspector overlay
  melos.yaml
  pubspec.yaml          # Workspace root
```

## Running tests

Run all tests from the root:
```bash
dart test packages/tanquery
```

Or with melos:
```bash
melos run test
```

Flutter package tests:
```bash
cd packages/tanquery_flutter && flutter test
cd packages/tanquery_devtools && flutter test
```

## Running the analyzer

```bash
dart analyze packages/tanquery/lib
dart analyze packages/tanquery_flutter/lib
dart analyze packages/tanquery_devtools/lib
```

Or across all packages:
```bash
melos run analyze
```

## Making changes

1. Create a branch off `main`:
   ```bash
   git checkout -b feat/my-feature
   ```

2. Make your changes. Keep these in mind:
   - The core package (`tanquery`) must stay pure Dart. No Flutter imports.
   - Every public API needs a `///` dartdoc comment.
   - Run `dart analyze` and `dart test` before opening a PR.
   - Match existing code style. No trailing whitespace, no unused imports.

3. If you add or change public API, update the relevant `CHANGELOG.md` under a new version heading.

4. Open a pull request against `main`. Describe what you changed and why.

## Code style

- Use `///` doc comments on all public APIs.
- Avoid abbreviations in public-facing names (`queryKey` not `qk`).
- Private members use `_` prefix.
- Prefer `final` fields where possible.
- No `dynamic` unless unavoidable.
- Barrel exports go in the package's top-level `.dart` file (`tanquery.dart`, `tanquery_flutter.dart`, etc).

## Reporting bugs

Open an issue at https://github.com/OttomanDeveloper/tanquery/issues with:
- What you expected to happen
- What actually happened
- Minimal reproduction (a code snippet or small project)
- Dart/Flutter SDK version

## Suggesting features

Open an issue with the "enhancement" label. Explain the use case, not just the solution. What problem are you hitting?

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
