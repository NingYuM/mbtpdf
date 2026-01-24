# @bobzhang/mbtpdf/core/pdfutil

Small utility helpers used across the PDF library.

## Overview

This package provides general-purpose utility functions for output buffering, memoization, and hash table operations used throughout the PDF processing modules.

## Variables

### stdout_buffer / stderr_buffer

Buffered output for stdout and stderr, used in async-only environments.

```moonbit nocheck
pub let stdout_buffer : Ref[String]
pub let stderr_buffer : Ref[String]
```

## Functions

### flprint

Print a message to stdout with line-buffered flushing.

```moonbit nocheck
pub fn flprint(message : String) -> Unit
```

### fleprint

Print a message to stderr with line-buffered flushing.

```moonbit nocheck
pub fn fleprint(message : String) -> Unit
```

### memoize

Memoize a nullary function, caching the first computed value for subsequent calls.

```moonbit nocheck
pub fn memoize[T](f : () -> T raise) -> (() -> T raise)
```

### hashtable_of_dictionary

Build a hash map from an array of key/value pairs.

```moonbit nocheck
pub fn hashtable_of_dictionary[K : Hash + Eq, V](pairs : Array[(K, V)]) -> Map[K, V]
```

### null_hash

Construct an empty hash table.

```moonbit nocheck
pub fn null_hash[K, V]() -> Map[K, V]
```

### list_of_hashtbl

Extract all key/value pairs from a hash table as an array.

```moonbit nocheck
pub fn list_of_hashtbl[K, V](table : Map[K, V]) -> Array[(K, V)]
```
