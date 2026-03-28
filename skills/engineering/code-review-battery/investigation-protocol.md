# Investigation Protocol

When you encounter a suspicious pattern, DO NOT report immediately. Investigate first.

## Step 1: Gather Evidence

- `grep -rn '<pattern>' <relevant-dirs>` — find all instances
- `cat <caller-file>` — read calling code to understand intent
- Execute code snippets to verify behavior if possible
- Check type definitions, error handling, return values

## Step 2: Test the Negative

Actively try to **DISPROVE** the issue before reporting:

- Is there a guard clause you missed? Read the full function.
- Does the caller handle this error case? Read the caller.
- Is there a test that covers this path? Check test files.
- Does the type system prevent this? Check type definitions.
- Is there a fallback or default value?

## Step 3: Classify Scope

- **Systemic** (3+ places): Report as architectural finding with all instances
- **Isolated** (1–2 places): Report as localized finding

## Step 4: Report with Evidence

Only report when you have:

- ✅ Specific file:line reference (verified to exist)
- ✅ Concrete description of what breaks
- ✅ Proof that no existing code handles it
- ✅ Evidence from your investigation (what you searched, what you found)
- ✅ Scope classification (isolated or systemic)
