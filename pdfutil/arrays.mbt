///|
/// Set each element of an array to [value].
pub fn[A] set_array(xs : Array[A], value : A) -> Unit {
  xs.fill(value)
}

///|
/// Array analog of [iter2], failing if lengths mismatch.
pub fn[A, B] array_iter2(
  f : (A, B) -> Unit raise?,
  xs : Array[A],
  ys : Array[B],
) -> Unit raise {
  let len = xs.length()
  if len != ys.length() {
    invalid_arg("Pdfutil.array_iter2")
  }
  let mut i = 0
  while i < len {
    f(xs[i], ys[i])
    i += 1
  }
}

///|
/// Array analog of [map2], failing if lengths mismatch.
pub fn[A, B, C] array_map2(
  f : (A, B) -> C raise?,
  xs : Array[A],
  ys : Array[B],
) -> Array[C] raise {
  let len = xs.length()
  if len != ys.length() {
    invalid_arg("Pdfutil.array_map2")
  }
  let out : Array[C] = Array::new(capacity=len)
  let mut i = 0
  while i < len {
    out.push(f(xs[i], ys[i]))
    i += 1
  }
  out
}

///|
/// Swap two elements of an array in place.
pub fn[A] swap(xs : Array[A], i : Int, j : Int) -> Unit {
  xs.swap(i, j)
}
