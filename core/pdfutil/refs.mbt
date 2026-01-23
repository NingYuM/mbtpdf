///|
/// Set a boolean reference to true.
pub fn set(flag : Ref[Bool]) -> Unit {
  flag.val = true
}

///|
/// Set a boolean reference to false.
pub fn clear(flag : Ref[Bool]) -> Unit {
  flag.val = false
}

///|
/// Flip a boolean reference.
pub fn flip(flag : Ref[Bool]) -> Unit {
  flag.val = !flag.val
}

///|
/// Add to an integer reference.
pub fn ref_add_int(target : Ref[Int], delta : Int) -> Unit {
  target.val = target.val + delta
}

///|
/// Subtract from an integer reference.
pub fn ref_sub_int(target : Ref[Int], delta : Int) -> Unit {
  target.val = target.val - delta
}

///|
/// Divide an integer reference.
pub fn ref_div_int(target : Ref[Int], divisor : Int) -> Unit {
  target.val = target.val / divisor
}

///|
/// Multiply an integer reference.
pub fn ref_mul_int(target : Ref[Int], factor : Int) -> Unit {
  target.val = target.val * factor
}

///|
/// Add to a float reference.
pub fn ref_add_double(target : Ref[Double], delta : Double) -> Unit {
  target.val = target.val + delta
}

///|
/// Subtract from a float reference.
pub fn ref_sub_double(target : Ref[Double], delta : Double) -> Unit {
  target.val = target.val - delta
}

///|
/// Divide a float reference.
pub fn ref_div_double(target : Ref[Double], divisor : Double) -> Unit {
  target.val = target.val / divisor
}

///|
/// Multiply a float reference.
pub fn ref_mul_double(target : Ref[Double], factor : Double) -> Unit {
  target.val = target.val * factor
}

///|
/// Cons an element onto the front of a list reference.
pub fn[A] ref_cons(target : Ref[Array[A]], value : A) -> Unit {
  let current = target.val
  let out : Array[A] = Array::new(capacity=current.length() + 1)
  out.push(value)
  for item in current {
    out.push(item)
  }
  target.val = out
}

///|
/// Prepend a list onto the front of a list reference.
pub fn[A] ref_prepend(target : Ref[Array[A]], prefix : Array[A]) -> Unit {
  let current = target.val
  let out : Array[A] = Array::new(capacity=prefix.length() + current.length())
  for item in prefix {
    out.push(item)
  }
  for item in current {
    out.push(item)
  }
  target.val = out
}
