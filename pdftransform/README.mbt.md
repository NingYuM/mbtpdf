# pdftransform

2D affine transformation matrices for PDF graphics.

## Overview

The `pdftransform` package provides:

- Affine transformation matrices (translate, scale, rotate, shear)
- Matrix composition and inversion
- Transform points through matrices
- Decomposition and recomposition of transforms

## TransformMatrix

The 2D affine transformation matrix:

```mbt nocheck
///|
pub(all) struct TransformMatrix {
  a : Double // scale x
  b : Double // shear y
  c : Double // shear x
  d : Double // scale y
  e : Double // translate x
  f : Double // translate y
}
```

Represents the matrix:
```
| a  b  0 |
| c  d  0 |
| e  f  1 |
```

### Identity Matrix

```mbt check
///|
test "identity matrix" {
  let m = @pdftransform.i_matrix
  inspect(m.a, content="1")
  inspect(m.d, content="1")
  inspect(m.e, content="0")
}
```

## Creating Transforms

### Translation

```mbt check
///|
test "mktranslate" {
  let m = @pdftransform.mktranslate(10.0, 20.0)
  inspect(m.e, content="10")
  inspect(m.f, content="20")
}
```

### Scaling

```mbt nocheck
// Scale by (sx, sy) around center point
///|
let m = @pdftransform.mkscale((0.0, 0.0), 2.0, 2.0)
```

### Rotation

```mbt nocheck
// Rotate by angle (radians) around center point
///|
let m = @pdftransform.mkrotate((0.0, 0.0), 1.5708) // 90 degrees
```

### Shearing

```mbt nocheck
// Horizontal shear
///|
let m = @pdftransform.mkshearx((0.0, 0.0), 0.5)

// Vertical shear

///|
let m = @pdftransform.mksheary((0.0, 0.0), 0.5)
```

## Transform Operations

### TransformOp Enum

```mbt nocheck
///|
pub(all) enum TransformOp {
  Scale((Double, Double), Double, Double) // center, sx, sy
  Rotate((Double, Double), Double) // center, angle
  Translate(Double, Double) // tx, ty
  ShearX((Double, Double), Double) // center, factor
  ShearY((Double, Double), Double) // center, factor
}
```

### Composing Operations

```mbt nocheck
// Build transform from operations
///|
let tr = @pdftransform.compose(
  @pdftransform.TransformOp::Translate(100.0, 100.0),
  @pdftransform.i,
)
```

### Appending Transforms

```mbt nocheck
///|
let combined = @pdftransform.append(tr1, tr2)
```

## Matrix Operations

### Composition

```mbt check
///|
test "matrix_compose" {
  let t1 = @pdftransform.mktranslate(10.0, 0.0)
  let t2 = @pdftransform.mktranslate(0.0, 20.0)
  let combined = @pdftransform.matrix_compose(t1, t2)
  inspect(combined.e, content="10")
  inspect(combined.f, content="20")
}
```

### Inversion

```mbt nocheck
try {
  let inv = @pdftransform.matrix_invert!(m)
  // Use inverted matrix...
} catch {
  @pdftransform.NonInvertable => println("Matrix not invertible")
}
```

### Converting Operations to Matrix

```mbt nocheck
///|
let op = @pdftransform.TransformOp::Translate(50.0, 50.0)

///|
let matrix = @pdftransform.matrix_of_op(op)
```

## Transforming Points

### With Matrix

```mbt check
///|
test "transform_matrix applies to point" {
  let m = @pdftransform.mktranslate(10.0, 20.0)
  let (x, y) = @pdftransform.transform_matrix(m, (5.0, 5.0))
  inspect(x, content="15")
  inspect(y, content="25")
}
```

### With Transform

```mbt nocheck
let (new_x, new_y) = @pdftransform.transform(tr, (x, y))
```

## Decomposition

Extract scale, rotation, shear, and translation from a matrix:

```mbt nocheck
let (scale, aspect, rotation, shear, tx, ty) = @pdftransform.decompose(m)
```

## Recomposition

Rebuild a matrix from components:

```mbt nocheck
///|
let m = @pdftransform.recompose(scale, aspect, rotation, shear, tx, ty)
```

## Debug Utilities

```mbt check
///|
test "string_of_matrix" {
  let m = @pdftransform.i_matrix
  let s = @pdftransform.string_of_matrix(m)
  assert_true(s.contains("1"))
}
```
