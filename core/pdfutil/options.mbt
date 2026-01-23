///|
/// True if an option is [Some].
pub fn[A] some(value : A?) -> Bool {
  value is Some(_)
}

///|
/// True if an option is [None].
pub fn[A] none(value : A?) -> Bool {
  value is None
}

///|
/// Extract the value from an option, failing on [None].
pub fn[A] unopt(value : A?) -> A raise {
  match value {
    Some(v) => v
    None => fail("Option is None")
  }
}
