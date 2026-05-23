## 0.1.0

- Initial release
- QueryClient with mount/unmount lifecycle
- QueryCache with build-or-get, partial key matching, GC
- Query state machine with 8-action reducer
- QueryObserver with select, placeholderData, stale timer, refetch interval
- Retryer with exponential backoff, pause/continue/cancel, 3 network modes
- MutationCache with scoped sequential execution
- Mutation with exact TanStack callback ordering
- MutationObserver with mutate/mutateAsync
- Hydration/dehydration for cache persistence
- StreamedQuery for real-time data (WebSocket, SSE, LLM streaming)
- Structural sharing via replaceEqualDeep
- InMemoryQueryStorage
- skipToken for type-safe conditional queries
- StaleTime.static_ for never-stale data
