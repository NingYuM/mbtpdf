///|
/// Union of two integer rectangles (xmin, xmax, ymin, ymax).
pub fn box_union(
  left : (Int, Int, Int, Int),
  right : (Int, Int, Int, Int),
) -> (Int, Int, Int, Int) {
  let (xmin0, xmax0, ymin0, ymax0) = left
  let (xmin1, xmax1, ymin1, ymax1) = right
  (min(xmin0, xmin1), max(xmax0, xmax1), min(ymin0, ymin1), max(ymax0, ymax1))
}

///|
/// Union of two floating point rectangles (xmin, xmax, ymin, ymax).
pub fn box_union_float(
  left : (Double, Double, Double, Double),
  right : (Double, Double, Double, Double),
) -> (Double, Double, Double, Double) {
  let (xmin0, xmax0, ymin0, ymax0) = left
  let (xmin1, xmax1, ymin1, ymax1) = right
  (
    fmin(xmin0, xmin1),
    fmax(xmax0, xmax1),
    fmin(ymin0, ymin1),
    fmax(ymax0, ymax1),
  )
}

///|
/// Intersection of two integer rectangles (xmin, xmax, ymin, ymax).
pub fn box_overlap(
  ax0 : Int,
  ay0 : Int,
  ax1 : Int,
  ay1 : Int,
  bx0 : Int,
  by0 : Int,
  bx1 : Int,
  by1 : Int,
) -> (Int, Int, Int, Int)? {
  if ax0 > bx1 || ay0 > by1 || ax1 < bx0 || ay1 < by0 {
    None
  } else {
    Some((max(ax0, bx0), max(ay0, by0), min(ax1, bx1), min(ay1, by1)))
  }
}

///|
/// Intersection of two floating point rectangles (xmin, xmax, ymin, ymax).
pub fn box_overlap_float(
  ax0 : Double,
  ay0 : Double,
  ax1 : Double,
  ay1 : Double,
  bx0 : Double,
  by0 : Double,
  bx1 : Double,
  by1 : Double,
) -> (Double, Double, Double, Double)? {
  if ax0 > bx1 || ay0 > by1 || ax1 < bx0 || ay1 < by0 {
    None
  } else {
    Some((fmax(ax0, bx0), fmax(ay0, by0), fmin(ax1, bx1), fmin(ay1, by1)))
  }
}
