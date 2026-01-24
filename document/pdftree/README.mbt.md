# @bobzhang/mbtpdf/document/pdftree

Name tree and number tree operations for PDF documents.

## Overview

This package handles PDF name trees and number trees, which are balanced tree structures used to efficiently store key-value mappings. Name trees use string keys (e.g., named destinations, embedded files), while number trees use integer keys (e.g., page labels, structure parent tree).

## Functions

### read_name_tree

Read a name tree as a flat array of (key, value) pairs.

```moonbit nocheck
pub fn read_name_tree(pdf : @pdf.Pdf, tree : @pdf.PdfObject) -> Array[(String, @pdf.PdfObject)]
```

### read_number_tree

Read a number tree as a flat array of (key, value) pairs. Keys are returned as strings for uniformity.

```moonbit nocheck
pub fn read_number_tree(pdf : @pdf.Pdf, tree : @pdf.PdfObject) -> Array[(String, @pdf.PdfObject)]
```

### build_name_tree

Build a name or number tree from a flat array of entries.

```moonbit nocheck
pub fn build_name_tree(
  isnum : Bool,
  pdf : @pdf.Pdf,
  entries : Array[(String, @pdf.PdfObject)]
) -> @pdf.PdfObject
```

- `isnum`: true for number tree, false for name tree

### merge_name_trees_no_clash

Merge multiple name trees assuming no duplicate keys.

```moonbit nocheck
pub fn merge_name_trees_no_clash(pdf : @pdf.Pdf, trees : Array[@pdf.PdfObject]) -> @pdf.PdfObject
```

### merge_number_trees_no_clash

Merge multiple number trees assuming no duplicate keys.

```moonbit nocheck
pub fn merge_number_trees_no_clash(pdf : @pdf.Pdf, trees : Array[@pdf.PdfObject]) -> @pdf.PdfObject
```

## Tree Structure

PDF trees consist of:
- **Root node**: Contains /Names or /Nums array, or /Kids for intermediate nodes
- **Intermediate nodes**: /Kids array pointing to child nodes, /Limits for key range
- **Leaf nodes**: /Names or /Nums array with key-value pairs

The implementation automatically balances trees with a maximum of 10 entries per leaf node.
