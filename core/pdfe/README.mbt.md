# @bobzhang/mbtpdf/core/pdfe

Error logging utilities for PDF operations.

## Overview

This package provides a configurable logging system for error messages during PDF processing. It uses a replaceable logger function that defaults to writing to stderr.

## Types

### Logger

Type alias for logging functions:

```moonbit nocheck
///|
pub type Logger = (String) -> Unit
```

## Values

### logger

The current error logger, stored as a mutable reference. Can be replaced for custom logging behavior.

```moonbit nocheck
pub let logger : Ref[Logger]
```

### read_debug

Debug flag for PDF reading operations. Set to `true` to enable debug output.

```moonbit nocheck
pub let read_debug : Ref[Bool]
```

## Functions

### log

Log a message using the current logger.

```moonbit check
///|
test "log: captures messages with custom logger" {
  let messages : Array[String] = []
  let prev = @pdfe.logger.val
  @pdfe.logger.val = fn(msg) { messages.push(msg) }
  @pdfe.log("hello")
  @pdfe.log("world")
  @pdfe.logger.val = prev
  inspect(messages, content="[\"hello\", \"world\"]")
}
```

### default

The default logger function that writes to stderr.

```moonbit nocheck
pub fn default(String) -> Unit
```

## Usage

**Replace the logger for testing:**

```moonbit nocheck
// Capture log messages
let messages : Array[String] = []
let prev = @pdfe.logger.val
@pdfe.logger.val = fn(msg) { messages.push(msg) }

// ... code that calls @pdfe.log() ...

// Restore original logger
@pdfe.logger.val = prev
```

**Enable debug mode:**

```moonbit nocheck
@pdfe.read_debug.val = true
```
