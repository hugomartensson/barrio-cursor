# Code Quality Guidelines

This document outlines the code quality standards enforced in this project.

## ESLint Complexity Rules

All rules are set as **errors** and will block commits via pre-commit hooks.

| Rule | Limit | Description |
|------|-------|-------------|
| `complexity` | 10 | Maximum cyclomatic complexity per function |
| `max-depth` | 3 | Maximum nesting depth |
| `max-lines` | 300 | Maximum lines per file (excluding blanks/comments) |
| `max-lines-per-function` | 50 | Maximum lines per function |
| `max-params` | 4 | Maximum function parameters |
| `max-statements` | 20 | Maximum statements per function |

## Refactoring Patterns

### When complexity is too high

**Extract helper functions:**

```typescript
// ❌ Bad: Complex nested logic
function processEvent(event: Event): Result {
  if (event.type === 'A') {
    if (event.status === 'active') {
      // many lines...
    } else {
      // many lines...
    }
  } else {
    // many lines...
  }
}

// ✅ Good: Extracted into focused functions
function processEvent(event: Event): Result {
  if (event.type === 'A') {
    return processTypeA(event);
  }
  return processOtherTypes(event);
}

function processTypeA(event: Event): Result {
  return event.status === 'active' 
    ? handleActiveTypeA(event) 
    : handleInactiveTypeA(event);
}
```

### When nesting is too deep

**Use early returns:**

```typescript
// ❌ Bad: Deep nesting
function validate(input: Input): boolean {
  if (input) {
    if (input.name) {
      if (input.name.length > 0) {
        return true;
      }
    }
  }
  return false;
}

// ✅ Good: Early returns
function validate(input: Input): boolean {
  if (!input) return false;
  if (!input.name) return false;
  if (input.name.length === 0) return false;
  return true;
}
```

### When functions have too many parameters

**Use an options object:**

```typescript
// ❌ Bad: Too many parameters
function createEvent(
  title: string,
  description: string,
  category: string,
  lat: number,
  lng: number,
  startTime: Date
): Event { }

// ✅ Good: Options object
interface CreateEventOptions {
  title: string;
  description: string;
  category: string;
  location: { lat: number; lng: number };
  startTime: Date;
}

function createEvent(options: CreateEventOptions): Event { }
```

### When files are too large

**Split into modules:**

- Extract types to `types/` directory
- Extract utilities to `utils/` directory
- Split routes into separate files per resource
- Create service layer for business logic

## Pre-commit Workflow

Before each commit, the following checks run automatically:

1. `eslint --fix` - Auto-fix lint issues
2. `prettier --write` - Format code

If any rule violations remain after auto-fix, the commit is blocked.

## Best Practices

1. **Single Responsibility**: Each function should do one thing
2. **Descriptive Names**: Use clear, descriptive function and variable names
3. **Type Safety**: Always use TypeScript types, avoid `any`
4. **Error Handling**: Use the `ApiError` class for consistent error responses
5. **Validation**: Validate inputs at route level using Zod schemas
6. **Testing**: Write tests before implementation (TDD)



