///|
/// A single transformation operation.
pub(all) enum TransformOp {
  Scale((Double, Double), Double, Double)
  Rotate((Double, Double), Double)
  Translate(Double, Double)
  ShearX((Double, Double), Double)
  ShearY((Double, Double), Double)
} derive(Debug)

///|
/// A list of transformations, stored with the most recent op at the head.
pub type Transform = Array[TransformOp]

///|
/// A transformation matrix (a c e / b d f / 0 0 1).
pub(all) struct TransformMatrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
} derive(Debug)

///|
/// The identity transform.
pub let i : Transform = Array::new()

///|
/// The identity matrix.
pub let i_matrix : TransformMatrix = {
  a: 1.0,
  b: 0.0,
  c: 0.0,
  d: 1.0,
  e: 0.0,
  f: 0.0,
}

///|
fn point_eq(a : (Double, Double), b : (Double, Double)) -> Bool {
  a.0 == b.0 && a.1 == b.1
}

///|
fn concat(a : Transform, b : Transform) -> Transform {
  let out = Array::new(capacity=a.length() + b.length())
  for item in a {
    out.push(item)
  }
  for item in b {
    out.push(item)
  }
  out
}

///|
fn tail(tr : Transform) -> Transform {
  let out = Array::new(
    capacity=if tr.length() > 0 { tr.length() - 1 } else { 0 },
  )
  let mut i = 1
  while i < tr.length() {
    out.push(tr[i])
    i = i + 1
  }
  out
}

///|
fn safe_float(value : Double) -> Double {
  if value == 0.0 || value.is_nan() || value.is_inf() {
    0.0
  } else {
    value
  }
}

///|
fn pi() -> Double {
  4.0 * @math.atan(1.0)
}

///|
fn string_of_op(op : TransformOp) -> String {
  match op {
    TransformOp::Scale((x, y), sx, sy) =>
      "Scale about (\{x}, \{y}) by \{sx} in x and \{sy} in y\n"
    TransformOp::Rotate((x, y), angle) =>
      "Rotate by \{angle} about (\{x}, \{y})\n"
    TransformOp::Translate(dx, dy) => "Translate by \{dx}, \{dy}\n"
    TransformOp::ShearX((x, y), factor) =>
      "Shear in X about (\{x}, \{y}), proportionality constant \{factor}\n"
    TransformOp::ShearY((x, y), factor) =>
      "Shear in Y about (\{x}, \{y}), proportionality constant \{factor}\n"
  }
}

///|
/// Make a string of a transform for debug purposes.
pub fn string_of_transform(tr : Transform) -> String {
  let sb = StringBuilder::new()
  let mut i = tr.length() - 1
  while i >= 0 {
    sb.write_string(string_of_op(tr[i]))
    i = i - 1
  }
  sb.to_string()
}

///|
/// String of a transformation matrix.
pub fn string_of_matrix(m : TransformMatrix) -> String {
  "\{m.a}, \{m.b}, \{m.c}, \{m.d}, \{m.e}, \{m.f}"
}

///|
/// Compose a transformation operation onto an existing transform.
pub fn compose(op : TransformOp, tr : Transform) -> Transform {
  if tr.length() == 0 {
    return [op]
  }
  let head = tr[0]
  match (head, op) {
    (TransformOp::Translate(dx, dy), TransformOp::Translate(dx2, dy2)) =>
      concat([TransformOp::Translate(dx + dx2, dy + dy2)], tail(tr))
    (TransformOp::Scale(p, sx, sy), TransformOp::Scale(p2, sx2, sy2)) =>
      if point_eq(p, p2) {
        concat([TransformOp::Scale(p, sx * sx2, sy * sy2)], tail(tr))
      } else {
        concat([op], tr)
      }
    (TransformOp::Rotate(p, a), TransformOp::Rotate(p2, a2)) =>
      if point_eq(p, p2) {
        concat([TransformOp::Rotate(p, a + a2)], tail(tr))
      } else {
        concat([op], tr)
      }
    (TransformOp::ShearX(p, a), TransformOp::ShearX(p2, a2)) =>
      if point_eq(p, p2) {
        concat([TransformOp::ShearX(p, a + a2)], tail(tr))
      } else {
        concat([op], tr)
      }
    (TransformOp::ShearY(p, a), TransformOp::ShearY(p2, a2)) =>
      if point_eq(p, p2) {
        concat([TransformOp::ShearY(p, a + a2)], tail(tr))
      } else {
        concat([op], tr)
      }
    _ => concat([op], tr)
  }
}

///|
/// Append two transforms (perform b then a).
pub fn append(a : Transform, b : Transform) -> Transform {
  concat(a, b)
}

///|
/// Compose two matrices. Applying the result is equivalent to applying m then m'.
pub fn matrix_compose(
  m_prime : TransformMatrix,
  m : TransformMatrix,
) -> TransformMatrix {
  {
    a: m_prime.a * m.a + m_prime.c * m.b,
    c: m_prime.a * m.c + m_prime.c * m.d,
    e: m_prime.a * m.e + m_prime.c * m.f + m_prime.e,
    b: m_prime.b * m.a + m_prime.d * m.b,
    d: m_prime.b * m.c + m_prime.d * m.d,
    f: m_prime.b * m.e + m_prime.d * m.f + m_prime.f,
  }
}

///|
/// Matrix inversion. Raises NonInvertable if no inverse.
pub fn matrix_invert(
  m : TransformMatrix,
) -> TransformMatrix raise NonInvertable {
  let divisor = m.a * m.d - m.b * m.c
  if divisor == 0.0 {
    raise NonInvertable::NonInvertable
  }
  let det = 1.0 / divisor
  if det == 0.0 || det.is_nan() || det.is_inf() {
    raise NonInvertable::NonInvertable
  }
  {
    a: det * m.d,
    b: det * -m.b,
    c: det * -m.c,
    d: det * m.a,
    e: det * (m.c * m.f - m.d * m.e),
    f: det * (m.b * m.e - m.a * m.f),
  }
}

///|
/// Make a translation matrix.
pub fn mktranslate(tx : Double, ty : Double) -> TransformMatrix {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: tx, f: ty }
}

///|
/// Make a scale matrix about a center point.
pub fn mkscale(
  center : (Double, Double),
  sx : Double,
  sy : Double,
) -> TransformMatrix {
  let translate = mktranslate(-center.0, -center.1)
  let translate_back = mktranslate(center.0, center.1)
  let scale_matrix = { a: sx, b: 0.0, c: 0.0, d: sy, e: 0.0, f: 0.0 }
  matrix_compose(translate_back, matrix_compose(scale_matrix, translate))
}

///|
/// Make a rotation matrix about a center point.
pub fn mkrotate(center : (Double, Double), angle : Double) -> TransformMatrix {
  let translate = mktranslate(-center.0, -center.1)
  let translate_back = mktranslate(center.0, center.1)
  let rotation_matrix = {
    a: @math.cos(angle),
    b: @math.sin(angle),
    c: -@math.sin(angle),
    d: @math.cos(angle),
    e: 0.0,
    f: 0.0,
  }
  matrix_compose(translate_back, matrix_compose(rotation_matrix, translate))
}

///|
/// Matrix to shear in x about a point.
pub fn mkshearx(center : (Double, Double), factor : Double) -> TransformMatrix {
  let translate = mktranslate(-center.0, -center.1)
  let translate_back = mktranslate(center.0, center.1)
  let shear_matrix = { a: 1.0, b: 0.0, c: factor, d: 1.0, e: 0.0, f: 0.0 }
  matrix_compose(translate_back, matrix_compose(shear_matrix, translate))
}

///|
/// Matrix to shear in y about a point.
pub fn mksheary(center : (Double, Double), factor : Double) -> TransformMatrix {
  let translate = mktranslate(-center.0, -center.1)
  let translate_back = mktranslate(center.0, center.1)
  let shear_matrix = { a: 1.0, b: factor, c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
  matrix_compose(translate_back, matrix_compose(shear_matrix, translate))
}

///|
/// Make a matrix from a single transformation operation.
pub fn matrix_of_op(op : TransformOp) -> TransformMatrix {
  match op {
    TransformOp::Scale(center, sx, sy) => mkscale(center, sx, sy)
    TransformOp::Rotate(center, angle) => mkrotate(center, angle)
    TransformOp::Translate(dx, dy) => mktranslate(dx, dy)
    TransformOp::ShearX(center, factor) => mkshearx(center, factor)
    TransformOp::ShearY(center, factor) => mksheary(center, factor)
  }
}

///|
/// Make a matrix from a transform.
pub fn matrix_of_transform(tr : Transform) -> TransformMatrix {
  let mut acc = i_matrix
  for op in tr {
    acc = matrix_compose(matrix_of_op(op), acc)
  }
  acc
}

///|
/// Transform a coordinate by a given transformation matrix.
pub fn transform_matrix(
  m : TransformMatrix,
  point : (Double, Double),
) -> (Double, Double) {
  let x = point.0
  let y = point.1
  (x * m.a + y * m.c + m.e, x * m.b + y * m.d + m.f)
}

///|
/// Transform a coordinate by a given transform.
pub fn transform(tr : Transform, point : (Double, Double)) -> (Double, Double) {
  let mut x = point.0
  let mut y = point.1
  let mut idx = tr.length() - 1
  while idx >= 0 {
    match tr[idx] {
      TransformOp::Scale((cx, cy), sx, sy) => {
        let dx = x - cx
        let dy = y - cy
        x = dx * sx + cx
        y = dy * sy + cy
      }
      TransformOp::Rotate((cx, cy), angle) => {
        let cosine = @math.cos(angle)
        let sine = @math.sin(angle)
        let dx = x - cx
        let dy = y - cy
        let nx = dx * cosine + dy * -sine
        let ny = dx * sine + dy * cosine
        x = nx + cx
        y = ny + cy
      }
      TransformOp::Translate(dx, dy) => {
        x = x + dx
        y = y + dy
      }
      TransformOp::ShearX((cx, cy), factor) => {
        let dx = x - cx
        let dy = y - cy
        x = dx + dy * factor + cx
        y = dy + cy
      }
      TransformOp::ShearY((cx, cy), factor) => {
        let dx = x - cx
        let dy = y - cy
        x = dx + cx
        y = dx * factor + dy + cy
      }
    }
    idx = idx - 1
  }
  (x, y)
}

///|
/// Decompose a transformation matrix into scale, aspect, rotation, shear,
/// translation in x, translation in y.
pub fn decompose(
  m : TransformMatrix,
) -> (Double, Double, Double, Double, Double, Double) {
  let axb = m.a * m.d - m.c * m.b
  let moda = (m.a * m.a + m.b * m.b).sqrt()
  let modb = (m.c * m.c + m.d * m.d).sqrt()
  let adotb = m.a * m.c + m.b * m.d
  let scale = axb / moda
  let abs_scale = scale.abs()
  let aspect = if abs_scale == 0.0 { 1.0 } else { moda / abs_scale }
  let rotation = @math.atan2(m.b, m.a)
  let shear = if moda * modb == 0.0 {
    0.0
  } else {
    pi() / 2.0 - @math.acos(adotb / (moda * modb))
  }
  (
    safe_float(scale),
    safe_float(aspect),
    safe_float(rotation),
    safe_float(shear),
    safe_float(m.e),
    safe_float(m.f),
  )
}

///|
/// Recompose a matrix from components.
pub fn recompose(
  scale : Double,
  aspect : Double,
  rotation : Double,
  shear : Double,
  tx : Double,
  ty : Double,
) -> TransformMatrix {
  let scale_aspect_shear = {
    a: scale.abs() * aspect,
    b: 0.0,
    c: scale * @math.tan(shear),
    d: scale,
    e: 0.0,
    f: 0.0,
  }
  let rotated = matrix_compose(
    mkrotate((0.0, 0.0), rotation),
    scale_aspect_shear,
  )
  matrix_compose(mktranslate(tx, ty), rotated)
}

///|
/// Exception raised if a matrix is non-invertible.
pub suberror NonInvertable {
  NonInvertable
}
