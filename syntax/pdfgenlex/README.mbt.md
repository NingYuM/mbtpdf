# pdfgenlex

Generic lexer tokens for PDF parsing.

## Overview

The `pdfgenlex` package defines the `Token` enum representing all lexical tokens that appear in PDF syntax. It provides functions to lex tokens from input streams or strings.

## Token Type

```mbt nocheck
///|
pub(all) enum Token {
  LexNull // null value
  LexBool(Bool) // true / false
  LexInt(Int) // integer literal
  LexReal(Double) // floating-point literal
  LexString(String) // string literal (...)
  LexName(String) // name /Foo
  LexLeftSquare // [
  LexRightSquare // ]
  LexLeftDict // <<
  LexRightDict // >>
  LexStream(Stream) // stream data
  LexEndStream // endstream
  LexObj // obj
  LexEndObj // endobj
  LexR // R (indirect reference)
  LexComment(String) // % comment
  StopLexing // internal: stop signal
  LexNone // internal: no token
}
```

## Lexing from Strings

```mbt check
///|
test "lex_string parses integers" {
  let tokens = @pdfgenlex.lex_string("42")
  guard tokens[0] is LexInt(n) else { fail("expected int") }
  inspect(n, content="42")
}
```

```mbt check
///|
test "lex_string parses floats" {
  let tokens = @pdfgenlex.lex_string("3.14")
  guard tokens[0] is LexReal(r) else { fail("expected real") }
  assert_true(r > 3.13 && r < 3.15)
}
```

```mbt check
///|
test "lex_string parses names" {
  let tokens = @pdfgenlex.lex_string("foo bar")
  guard tokens[0] is LexName(name) else { fail("expected name") }
  inspect(name, content="foo")
}
```

```mbt check
///|
test "lex_string parses multiple tokens" {
  let tokens = @pdfgenlex.lex_string("10 20 30")
  inspect(tokens.length(), content="3")
}
```

## Lexing from Input

```mbt check
///|
test "lex_single returns one token" {
  let input = @pdfio.Input::of_string("123 456")
  guard @pdfgenlex.lex_single(input) is LexInt(n) else { fail("expected int") }
  inspect(n, content="123")

  // Second call returns next token
  guard @pdfgenlex.lex_single(input) is LexInt(m) else { fail("expected int") }
  inspect(m, content="456")
}
```

```mbt check
///|
test "lex returns all tokens" {
  let input = @pdfio.Input::of_string("1 2 3")
  let tokens = @pdfgenlex.lex(input)
  inspect(tokens.length(), content="3")
}
```

## Token Categories

### Literals

- `LexNull` - PDF null
- `LexBool(Bool)` - `true` or `false`
- `LexInt(Int)` - integer like `42`, `-10`
- `LexReal(Double)` - floating point like `3.14`, `1.0e-5`
- `LexString(String)` - literal string content

### Structural

- `LexName(String)` - names like `foo`, `Type`
- `LexLeftSquare`, `LexRightSquare` - `[` and `]`
- `LexLeftDict`, `LexRightDict` - `<<` and `>>`

### Objects

- `LexObj`, `LexEndObj` - object delimiters
- `LexStream(Stream)`, `LexEndStream` - stream delimiters
- `LexR` - indirect reference marker

### Special

- `LexComment(String)` - PDF comments
- `StopLexing` - internal stop signal
- `LexNone` - placeholder for no token
