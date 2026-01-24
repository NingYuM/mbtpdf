# @bobzhang/mbtpdf/document/pdfst

PDF structure tree operations for tagged PDFs.

## Overview

This package handles the structure tree in tagged PDF documents. Tagged PDFs contain semantic structure information that maps content to logical document elements (paragraphs, headings, tables, etc.), enabling accessibility features and content reflow.

## Functions

### trim_structure_tree

Remove structure tree entries for pages not in the specified range.

```moonbit nocheck
pub fn trim_structure_tree(pdf : @pdf.Pdf, range : Array[Int]) -> Unit raise
```

### renumber_parent_trees

Renumber /ParentTree entries when merging multiple PDFs. Updates /StructParent and /StructParents references to maintain consistency.

```moonbit nocheck
pub fn renumber_parent_trees(pdfs : Array[@pdf.Pdf]) -> Unit raise
```

### merge_structure_trees

Merge structure trees from multiple PDFs into a single document.

```moonbit nocheck
pub fn merge_structure_trees(
  pdf : @pdf.Pdf,
  pdfs : Array[@pdf.Pdf],
  add_toplevel_document? : Bool
) -> Int? raise
```

- `add_toplevel_document`: Wrap in /Document element (default: false)
- Returns the merged StructTreeRoot object number

## Variables

### endpage

Hook for resolving page count (re-exported from pdf module).

```moonbit nocheck
pub let endpage : Ref[(@pdf.Pdf) -> Int]
```

## Tagged PDF Structure

A structure tree contains:
- **/StructTreeRoot**: Root of the structure hierarchy
- **/K**: Children (structure elements)
- **/ParentTree**: Maps marked content to structure elements
- **/IDTree**: Maps element IDs to structure elements
- **/RoleMap**: Custom element type mappings
- **/ClassMap**: Attribute class definitions
