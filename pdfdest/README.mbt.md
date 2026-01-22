# pdfdest

PDF destination types for links and bookmarks.

## Overview

The `pdfdest` package provides:

- Destination type definitions
- Reading destinations from PDF objects
- Creating destination objects
- Transforming destinations with matrices

## Destination Types

```mbt
pub(all) enum Destination {
  NullDestination
  XYZ(TargetPage, Double?, Double?, Double?)      // page, left, top, zoom
  Fit(TargetPage)                                  // Fit entire page
  FitH(TargetPage, Double?)                        // Fit width, top
  FitV(TargetPage, Double?)                        // Fit height, left
  FitR(TargetPage, Double, Double, Double, Double) // Fit rectangle
  FitB(TargetPage)                                 // Fit bounding box
  FitBH(TargetPage, Double?)                       // Fit bbox width
  FitBV(TargetPage, Double?)                       // Fit bbox height
  NamedDestinationElsewhere(String)                // External file
}
```

## Target Page

```mbt
pub(all) enum TargetPage {
  OtherDocPageNumber(Int)  // Page in external doc
  PageObject(Int)          // Object number in current doc
}
```

## Reading Destinations

```mbt
let dest = @pdfdest.read_destination!(pdf, dest_object)
match dest {
  XYZ(page, left, top, zoom) => {
    // Handle XYZ destination
  }
  Fit(page) => {
    // Handle Fit destination
  }
  _ => ()
}
```

## Creating Destinations

```mbt
// Create XYZ destination (specific position)
let dest = @pdfdest.Destination::XYZ(
  @pdfdest.TargetPage::PageObject(page_objnum),
  Some(100.0),  // left
  Some(700.0),  // top
  Some(1.0),    // zoom (100%)
)

// Create Fit destination (fit entire page)
let dest = @pdfdest.Destination::Fit(
  @pdfdest.TargetPage::PageObject(page_objnum),
)
```

## Converting to PDF Object

```mbt
let dest_obj = @pdfdest.pdfobject_of_destination(dest)
// Can be used in /Dest entries, bookmarks, etc.
```

## Transforming Destinations

When pages are transformed (rotated, scaled), update destinations:

```mbt
let transformed = @pdfdest.transform_destination(
  pdf,
  transform,
  destination,
)
```

## Common Usage

### Bookmark Destinations

```mbt
// Read bookmark destination
let bookmark_dest = @pdfdest.read_destination!(pdf, bookmark_dict)

// Get page number
let pagenum = @pdfpage.pagenumber_of_target!(pdf, bookmark_dest)
```

### Link Annotations

```mbt
// Read link destination from annotation
let link_dest = @pdfdest.read_destination!(pdf, annot_dict)
```
