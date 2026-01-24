# pdf

Core types and operations for in-memory PDF document representation.

## Overview

The `pdf` package provides the fundamental data structures for representing PDF documents in memory. It defines the `PdfObject` enum for all PDF value types, the `Pdf` struct for complete documents, and operations for manipulating objects, dictionaries, streams, and object graphs.

## Core Types

### PdfObject

The central enum representing all PDF value types:

```mbt nocheck
///|
pub(all) enum PdfObject {
  Null
  Boolean(Bool)
  Integer(Int)
  Real(Double)
  String(String)
  Name(String)
  Array(Array[PdfObject])
  Dictionary(Array[(String, PdfObject)])
  Stream(Ref[(PdfObject, Stream)])
  Indirect(Int)
}
```

- **Null**: PDF null value
- **Boolean**: `true` or `false`
- **Integer/Real**: Numeric values
- **String**: Literal or hexadecimal strings
- **Name**: PDF names like `/Type`, `/Page`
- **Array**: Ordered collection of objects
- **Dictionary**: Key-value pairs (keys are names)
- **Stream**: Dictionary plus binary data
- **Indirect**: Reference to another object by number

### Pdf

The in-memory document representation:

```mbt nocheck
///|
pub(all) struct Pdf {
  major : Int // PDF major version
  minor : Int // PDF minor version
  root : Int // Object number of document catalog
  objects : PdfObjects // All objects in the document
  mut trailerdict : PdfObject
  was_linearized : Bool
  mut saved_encryption : SavedEncryption?
}
```

### Stream

Stream data can be loaded or deferred:

```mbt nocheck
///|
pub(all) enum Stream {
  Got(@pdfio.MutableBytes) // Data in memory
  ToGet(ToGet) // Data still on disk
}
```

## Creating Documents

### Empty Document

```mbt nocheck
///|
let pdf = @pdf.empty()
// Creates PDF 2.0 with no objects
```

### Adding Objects

```mbt nocheck
let pdf = @pdf.empty()

// Add an object and get its number
let objnum = @pdf.addobj(pdf, @pdf.PdfObject::Dictionary([
  ("/Type", @pdf.PdfObject::Name("/Page")),
]))

// Add with a specific object number
@pdf.addobj_given_num(pdf, (42, @pdf.PdfObject::Integer(100)))
```

## Object Lookup

### Basic Lookup

```mbt check
///|
test "lookup_obj returns Null for missing objects" {
  let pdf = @pdf.empty()
  assert_true(@pdf.lookup_obj(pdf, 999) is Null)
}
```

### Following Indirect References

```mbt check
///|
test "direct follows indirects" {
  let pdf = @pdf.empty()
  let objnum = @pdf.addobj(pdf, @pdf.PdfObject::Integer(42))
  let indirect = @pdf.PdfObject::Indirect(objnum)
  guard @pdf.direct(pdf, indirect) is Integer(n) else {
    fail("expected Integer")
  }
  inspect(n, content="42")
}
```

### Dictionary Key Lookup

```mbt check
///|
test "lookup_direct finds keys" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Page")),
    ("/Count", @pdf.PdfObject::Integer(5)),
  ])
  guard @pdf.lookup_direct(pdf, "/Type", dict) is Some(Name(name)) else {
    fail("expected Name")
  }
  inspect(name, content="/Page")
  assert_true(@pdf.lookup_direct(pdf, "/Missing", dict) is None)
}
```

### Nested Chain Lookup

For deeply nested dictionaries, use `lookup_chain`:

```mbt check
///|
test "lookup_chain navigates nested dicts" {
  let pdf = @pdf.empty()
  let inner = @pdf.PdfObject::Dictionary([
    ("/Value", @pdf.PdfObject::Integer(100)),
  ])
  let outer = @pdf.PdfObject::Dictionary([("/Inner", inner)])
  guard @pdf.lookup_chain(pdf, outer, ["/Inner", "/Value"][:])
    is Some(Integer(n)) else {
    fail("expected Integer")
  }
  inspect(n, content="100")
}
```

## Dictionary Manipulation

### Adding Entries

```mbt check
///|
test "add_dict_entry" {
  let dict = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Page")),
  ])
  let updated = @pdf.add_dict_entry(dict, "/Count", @pdf.PdfObject::Integer(1))
  match updated {
    Dictionary(entries) => inspect(entries.length(), content="2")
    _ => fail("expected dictionary")
  }
}
```

### Replacing Entries

```mbt check
///|
test "replace_dict_entry" {
  let dict = @pdf.PdfObject::Dictionary([("/Count", @pdf.PdfObject::Integer(1))])
  let updated = @pdf.replace_dict_entry(
    dict,
    "/Count",
    @pdf.PdfObject::Integer(5),
  )
  guard @pdf.lookup_immediate("/Count", updated) is Some(Integer(n)) else {
    fail("expected Integer")
  }
  inspect(n, content="5")
}
```

### Removing Entries

```mbt check
///|
test "remove_dict_entry" {
  let dict = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Page")),
    ("/Count", @pdf.PdfObject::Integer(1)),
  ])
  let updated = @pdf.remove_dict_entry(dict, "/Count")
  match updated {
    Dictionary(entries) => inspect(entries.length(), content="1")
    _ => fail("expected dictionary")
  }
}
```

## Object Iteration

### Iterating All Objects

```mbt nocheck
@pdf.objiter(
  fn(objnum, obj) {
    println("Object \{objnum}: \{obj}")
  },
  pdf,
)
```

### Selecting Objects by Predicate

```mbt nocheck
// Find all page objects

///|
let page_nums = @pdf.objselect(
  fn(obj) {
    match @pdf.lookup_direct(pdf, "/Type", obj) {
      Some(Name("/Page")) => true
      _ => false
    }
  },
  pdf,
)
```

### Transforming All Objects

```mbt nocheck
// Apply a transformation to every object
@pdf.objselfmap(
  fn(obj) {
    // Return transformed object
    obj
  },
  pdf,
)
```

## Stream Operations

### Getting Stream Data

```mbt nocheck
match obj {
  Stream(_) => {
    @pdf.getstream!(obj)  // Loads data if deferred
    let bytes = @pdf.bigarray_of_stream!(obj)
    // Use bytes...
  }
  _ => ()
}
```

## Geometry Operations

### Parsing Rectangles

```mbt check
///|
test "parse_rectangle" {
  let pdf = @pdf.empty()
  let rect = @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(612.0),
    @pdf.PdfObject::Real(792.0),
  ])
  let (minx, miny, maxx, maxy) = @pdf.parse_rectangle(pdf, rect)
  inspect((minx, miny, maxx, maxy), content="(0, 0, 612, 792)")
}
```

### Matrices

```mbt nocheck
// Parse a matrix from a dictionary

///|
let matrix = @pdf.parse_matrix(pdf, "/Matrix", dict)

// Create a matrix object

///|
let matrix_obj = @pdf.make_matrix(@pdftransform.TransformMatrix::identity())
```

## Reference Management

### Finding Referenced Objects

```mbt nocheck
// Find all objects reachable from a starting object

///|
let refs = @pdf.objects_referenced([], [], pdf, start_obj)
```

### Removing Unreferenced Objects

```mbt nocheck
// Garbage collect unreferenced objects
@pdf.remove_unreferenced!(pdf)
```

## Document Operations

### Renumbering Objects

```mbt nocheck
// Calculate changes to renumber 1..n

///|
let change_table = @pdf.changes(pdf)

// Apply renumbering

///|
let renumbered = @pdf.renumber(change_table, pdf)
```

### Deep Copy

```mbt nocheck
// Create an independent copy

///|
let copy = @pdf.deep_copy(pdf)
```

### Renumbering Multiple PDFs

```mbt nocheck
// Make object numbers mutually exclusive across documents

///|
let renumbered = @pdf.renumber_pdfs([pdf1, pdf2, pdf3])
```

## Name Trees

PDF name trees are hierarchical structures for mapping names to values:

```mbt nocheck
// Lookup in a name tree

///|
let value = @pdf.nametree_lookup(pdf, @pdf.PdfObject::String("key"), tree)

// Get all entries

///|
let entries = @pdf.contents_of_nametree(pdf, tree)
```

## Character Classification

```mbt nocheck
///|
test "is_delimiter" {
  inspect(is_delimiter('('), content="true") // internal function
  inspect(is_delimiter('/'), content="true")
  inspect(is_delimiter('a'), content="false")
}
```

```mbt check
///|
test "is_whitespace" {
  inspect(@pdf.is_whitespace(' '), content="true")
  inspect(@pdf.is_whitespace('\n'), content="true")
  inspect(@pdf.is_whitespace('a'), content="false")
}
```

## Error Handling

The package uses `PdfError` for error conditions:

```mbt nocheck
///|
pub(all) suberror PdfError {
  Msg(String)
}
```

Functions that can fail use the `raise` keyword and should be called with `!` or within error handling contexts.
