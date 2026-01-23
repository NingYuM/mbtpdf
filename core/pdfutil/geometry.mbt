///|
/// Two-dimensional vector type.
pub type Vector = (Double, Double)

///|
/// Make a vector from point [start] to point [finish].
pub fn mkvector(start : (Double, Double), finish : (Double, Double)) -> Vector {
  (finish.0 - start.0, finish.1 - start.1)
}

///|
/// Invert a vector.
pub fn invert(vec : Vector) -> Vector {
  (-vec.0, -vec.1)
}

///|
/// Offset a point by a vector.
pub fn offset_point(vec : Vector, point : (Double, Double)) -> Vector {
  (point.0 + vec.0, point.1 + vec.1)
}

///|
/// Find the vector pi/2 anticlockwise from the given one.
pub fn perpendicular(vec : Vector) -> Vector {
  (-vec.1, vec.0)
}

///|
/// Square a number.
pub fn sqr(value : Double) -> Double {
  value * value
}

///|
/// Length of a vector.
pub fn veclength(vec : Vector) -> Double {
  (sqr(vec.0) + sqr(vec.1)).sqrt()
}

///|
/// Scale a vector to a given length.
pub fn scalevectolength(length : Double, vec : Vector) -> Vector {
  let current = veclength(vec)
  if current == 0.0 {
    vec
  } else {
    let factor = length / current
    (vec.0 * factor, vec.1 * factor)
  }
}

///|
/// Make a unit vector in the direction from one point to a second.
pub fn mkunitvector(
  start : (Double, Double),
  finish : (Double, Double),
) -> Vector {
  scalevectolength(1.0, mkvector(start, finish))
}

///|
/// Find the point equidistant between two others.
pub fn between(a : (Double, Double), b : (Double, Double)) -> (Double, Double) {
  ((a.0 + b.0) / 2.0, (a.1 + b.1) / 2.0)
}

///|
/// Cartesian distance between two points.
pub fn distance_between(a : (Double, Double), b : (Double, Double)) -> Double {
  let dx = a.0 - b.0
  let dy = b.1 - a.1
  (sqr(dx) + sqr(dy)).sqrt()
}
