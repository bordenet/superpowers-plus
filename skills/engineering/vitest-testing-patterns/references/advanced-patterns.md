# Advanced Vitest Patterns

## Modern Vitest 3+ Matchers

```typescript
// toHaveBeenCalledExactlyOnceWith: Combines two assertions
expect(spy).toHaveBeenCalledExactlyOnceWith('arg1', 'arg2')

// toBeOneOf: Check if value is one of options
expect(status).toBeOneOf([200, 201, 204])

// toSatisfy: Custom predicate matching
const isEven = (n: number) => n % 2 === 0
expect(4).toSatisfy(isEven)

// toHaveBeenCalledBefore/After: Call order verification
expect(mockSetup).toHaveBeenCalledBefore(mockTeardown)
```

### Asymmetric Matchers

```typescript
expect(obj).toEqual({
  id: expect.any(String),
  createdAt: expect.any(Date),
  count: expect.any(Number),
})

expect(spy).toHaveBeenCalledWith(
  expect.stringMatching(/^user-\d+$/),
  expect.objectContaining({ role: 'admin' })
)
```

## Parameterized Tests (test.each)

```typescript
it.each([
  { errorName: 'ValidationError', statusCode: 400 },
  { errorName: 'UnauthorizedError', statusCode: 401 },
  { errorName: 'NotFoundError', statusCode: 404 },
])('should map $errorName to $statusCode', ({ errorName, statusCode }) => {
  const err = new Error('Test error')
  err.name = errorName
  errorHandler(err, req, res, next)
  expect(res.status).toHaveBeenCalledExactlyOnceWith(statusCode)
})
```

## Vitest Configuration

### Pool Selection

```typescript
pool: 'threads', // 20-40% faster than forks (for pure JS/TS)
// Switch to 'forks' for native modules (sharp, canvas, bcrypt)
```

### Mock Management

```typescript
restoreMocks: true, // RECOMMENDED: clears history + restores original
// clearMocks: history only | mockReset: + empty function | restoreMocks: + original
```

## Async Testing: Deferred Promises

```typescript
function createDeferred<T>() {
  let resolve!: (value: T) => void
  let reject!: (error: Error) => void
  const promise = new Promise<T>((res, rej) => {
    resolve = res
    reject = rej
  })
  return { promise, resolve, reject }
}

it('should handle race condition', async () => {
  const deferred = createDeferred<string>()
  const resultPromise = service.fetchData(deferred.promise)
  expect(service.isPending()).toBe(true)
  deferred.resolve('value')
  await resultPromise
  expect(service.isPending()).toBe(false)
})
```

## Anti-Patterns

| Anti-Pattern | Fix |
|--------------|-----|
| Testing implementation details | Test observable behavior |
| Over-mocking | Mock dependencies only |
| Multiple concepts per test | One concept per test |
| Not awaiting async | Always `await` promises |
| Shared state between tests | Fresh state in `beforeEach` |
