# The Grug-Brained Claude: Principles for Writing Code

Source: [grugbrain.dev](https://grugbrain.dev/)

## Prime Directive

Complexity is the enemy. Every line of code, every abstraction, every indirection is a liability. The goal is not clever code. The goal is code that works, that others can read, and that doesn't fight you when it needs to change.

## Complexity

- Say no to features and scope creep. The best code is code that doesn't exist.
- When you must say yes, prefer the 80/20 solution: deliver most of the value with minimal code. A simple solution that covers 80% of cases beats an elaborate one that covers 100%.
- Treat complexity as a budget. Every abstraction, every layer, every generic parameter spends from it. Be stingy.

## Abstraction and Factoring

- Do not abstract prematurely. Wait until you see the real pattern repeat before extracting it. Three similar blocks of code are better than a premature abstraction.
- Let structure emerge from the code naturally. Good cut-points reveal themselves over time.
- Repetition is sometimes cheaper than the wrong abstraction. A little copy-paste can be better than a tangled shared utility.
- DRY is a guideline, not a law. If deduplication makes the code harder to follow, keep the duplication.

## Chesterton's Fence

- Before removing or rewriting existing code, understand why it exists. Ugly code often hides hard-won correctness. Ask "what problem did this solve?" before deleting it.
- Read before you edit. Understand before you change.

## Refactoring

- Keep refactors small and incremental. Large rewrites fail more often than they succeed.
- Do not refactor code you weren't asked to touch. A bug fix does not need surrounding code cleaned up.
- Resist the urge to "improve" while passing through. Fix what you were asked to fix, nothing more.

## Testing

- Prefer integration tests. They verify real behavior at a level where failures are debuggable.
- Don't over-mock. Mocking severs the connection between test and reality. If everything is mocked, you're testing your mocks.
- Don't write tests for the sake of coverage numbers. Write tests that catch real bugs.

## Expression and Readability

- Prefer clear, verbose code over compressed one-liners. Named intermediate variables are free documentation and make debugging easy.
- If a reader has to mentally unpack a dense expression to understand it, break it apart.
- Code is read far more often than it is written. Optimize for the reader.

## Locality of Behavior

- Keep related logic together. It's better for code to be understandable by reading one file than to be "properly separated" across six.
- Separation of concerns is valuable, but not at the cost of scattering a single logical operation across the codebase.

## Type Systems and Generics

- Use types for clarity and tooling support, not for theoretical purity.
- Be very cautious with generics. Each generic parameter multiplies complexity. A concrete implementation you can read is better than a generic one you can't.
- If a type signature is harder to understand than the function body, simplify it.

## Concurrency

- Treat concurrency with appropriate fear. Prefer stateless designs, simple queues, and optimistic locking over shared mutable state.
- If you don't need concurrency, don't add it.

## Optimization

- Do not optimize without profiling first. Intuition about bottlenecks is usually wrong.
- Network latency dwarfs CPU micro-optimization in most systems. Fix the I/O before tuning the loops.

## API Design

- Make the common case easy and the complex case possible.
- Layer APIs: a simple high-level interface for most users, a lower-level one for those who need control.
- Put methods where they belong, on the objects they operate on.

## Microservices and Architecture

- Do not solve code organization problems by adding network boundaries. A function call is always simpler than an HTTP request.
- Distributed systems add failure modes, latency, and operational overhead. Justify every service boundary.

## Logging

- Log generously. Good logging is the difference between a 5-minute fix and a 5-hour investigation.
- Use structured logging with request IDs and dynamic log levels. Invest in logging infrastructure the way you invest in the code itself.

## Fads and Trends

- Be skeptical of revolutionary new approaches. Most have been tried before and found wanting.
- Evaluate new tools and patterns against the complexity they introduce, not just the problem they claim to solve.
- Boring technology that works beats exciting technology that might.

## Humility

- Admit when you don't understand something. Pretending to understand creates worse code than asking a clarifying question.
- The smartest approach is usually the simplest one that works.
