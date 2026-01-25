///|
/// Deprecated shim type for legacy call sites.
///
/// Prefer the free function `@pdfe.log(...)` instead of `Pdfe::new().log(...)`.
pub struct Pdfe {
  unit : Unit
}

///|
/// Deprecated constructor. Prefer `@pdfe.log(...)`.
pub fn Pdfe::new() -> Pdfe {
  { unit: () }
}

///|
/// Deprecated logging method. Prefer `@pdfe.log(...)`.
pub fn Pdfe::log(self : Pdfe, message : String) -> Unit {
  let _ = self
  log(message)
}
