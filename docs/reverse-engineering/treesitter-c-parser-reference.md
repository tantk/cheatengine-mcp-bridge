# Tree-sitter C Parser Reference

Key details for ensuring decompiled code parses correctly in tools like GitNexus.

## Identifier Rules

From `tree-sitter-c/grammar.js`:
```javascript
identifier: _ =>
  /(\p{XID_Start}|\$|_|\\u[0-9A-Fa-f]{4}|\\U[0-9A-Fa-f]{8})
   (\p{XID_Continue}|\$|\\u[0-9A-Fa-f]{4}|\\U[0-9A-Fa-f]{8})*/,
```

### Safe characters for function names

| Character | Valid? | Notes |
|---|---|---|
| `a-z A-Z` | Yes | Always safe |
| `0-9` | Yes | Except as first character |
| `_` (underscore) | Yes | Always safe |
| `$` (dollar) | Yes | Non-standard C, but explicitly in tree-sitter-c |
| `.` (dot) | **NO** | Becomes member-access operator (`field_expression`) |
| `<` `>` | **NO** | Become relational operators |
| `-` (hyphen) | **NO** | Becomes subtraction |
| `::` | **NO** | Not valid in C |
| `@` `#` `!` `%` | **NO** | Not in identifier charset |
| Space, tab | **NO** | Whitespace terminates token |

### Impact on IL2CPP names

| Pattern | Valid single identifier? | What parser sees |
|---|---|---|
| `GameController__Update` | Yes | One identifier |
| `GameController$$Update` | Yes | One identifier (`$` is valid) |
| `DG.Tweening.Core$$Method` | **NO** | `field_expression` chain (dots split it) |
| `List_int_$$Add` | Yes | One identifier |
| `_Module_$$Method` | Yes | One identifier |

## Function Call Detection

```javascript
call_expression: $ => prec(PREC.CALL, seq(
  field('function', $.expression),
  field('arguments', $.argument_list),
)),
```

A function call is detected when the parser sees: `expression` followed by `(argument_list)`.

The `function` field accepts ANY expression — identifier, field_expression, pointer dereference, etc. Code analysis tools that only look for `function: (identifier)` will miss calls via `field_expression` (which is what `Namespace.Class.Method()` produces).

## Comment Handling

Comments are "extras" in tree-sitter — they can appear **anywhere** between any two tokens:

```c
foo /* this is fine */ (args);  // tree-sitter parses this as call_expression(foo, args)
```

**Critical finding:** `Name/*comment*/(args)` does NOT break tree-sitter's call detection. The `/**/` comment is transparently skipped. If GitNexus failed to detect these calls, the issue is in a **post-parse processing step** (regex-based extraction or custom AST walker that doesn't handle comment nodes), not in tree-sitter itself.

However: removing comments is still better because:
1. It avoids any post-parse tool issues
2. It makes the code cleaner and smaller
3. It eliminates false matches in full-text search

## Recommendations for Our Pipeline

### Name sanitization rules (apply in resolve_decomps.py)

| Original | Replace with | Why |
|---|---|---|
| `.` (namespace dot) | `_` | Dots break identifier parsing |
| `<` `>` (generics) | `_` | Not valid in identifiers |
| `,` (generic params) | `_` | Not valid in identifiers |
| `/*FUN_xxx*/` (address comment) | Remove entirely | Clutters code, potential post-parse issues |

### Resulting format
```
Before: DG.Tweening.Core.DOGetter<Vector3>$$Invoke/*FUN_180abc123*/(args)
After:  DG_Tweening_Core_DOGetter_Vector3_$$Invoke(args)
```

### `$$` is safe
The `$$` separator between class and method is valid in tree-sitter-c. However, it may cause issues in other tools that follow strict C standard (which doesn't include `$`). If maximum compatibility is needed, replace with `__` (double underscore).

## No Runtime Configuration

The identifier regex is baked into the generated parser at grammar-compile time. There is no way to customize valid identifier characters without forking tree-sitter-c and regenerating the parser.

## Sources
- [tree-sitter-c grammar](https://github.com/tree-sitter/tree-sitter-c)
- [tree-sitter Grammar DSL docs](https://tree-sitter.github.io/tree-sitter/creating-parsers/2-the-grammar-dsl.html)
- [C identifier rules (cppreference)](https://en.cppreference.com/w/c/language/identifier.html)
