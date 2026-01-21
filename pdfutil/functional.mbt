///|
/// Invert a predicate.
pub fn[A] notpred(p : (A) -> Bool raise?) -> (A) -> Bool raise? {
  value => !p(value)
}

///|
/// Prefix equality.
pub fn[A : Eq] eq(left : A, right : A) -> Bool {
  left == right
}

///|
/// Prefix inequality.
pub fn[A : Eq] neq(left : A, right : A) -> Bool {
  left != right
}

///|
/// Reverse comparison.
pub fn[A : Compare] rev_compare(left : A, right : A) -> Int {
  if left < right {
    1
  } else if left > right {
    -1
  } else {
    0
  }
}

///|
/// Exclusive or of two booleans.
pub fn bool_xor(left : Bool, right : Bool) -> Bool {
  left != right
}

///|
/// The identity function.
pub fn[A] ident(value : A) -> A {
  value
}

///|
/// A constant predicate that always returns true.
pub fn[A] always(_ : A) -> Bool {
  true
}

///|
/// A constant predicate that always returns false.
pub fn[A] never(_ : A) -> Bool {
  false
}

///|
/// Apply [f] [n] times to [arg].
pub fn[A] applyn(f : (A) -> A raise?, n : Int, arg : A) -> A raise? {
  if n == 0 {
    arg
  } else {
    applyn(f, n - 1, f(arg))
  }
}

///|
/// Build a tuple.
pub fn[A, B] tuple(left : A, right : B) -> (A, B) {
  (left, right)
}

///|
/// Make a nullary function from a unary function and value.
pub fn[A, B] mkunit(f : (A) -> B raise?, value : A) -> () -> B raise? {
  () => f(value)
}

///|
/// Evaluate [v], evaluate and ignore [f], and return [v]'s result.
pub fn[A] do_return(v : () -> A raise?, f : () -> Unit raise?) -> A raise? {
  let result = v()
  f()
  result
}

///|
/// Call [f] [n] times.
pub fn do_many(f : () -> Unit raise?, n : Int) -> Unit raise {
  if n < 0 {
    fail("Invalid_argument: Pdfutil.do_many")
  }
  for _ in 0..<n {
    f()
  }
}
