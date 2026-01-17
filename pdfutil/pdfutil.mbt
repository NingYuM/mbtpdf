///|
/// Small utility helpers used across the port.
/// More functions will be added as modules are ported.
pub fn flprint(message : String) -> Unit {
  println(message)
}

///|
/// Temporary stderr shim (MoonBit stdlib does not expose stderr yet).
pub fn fleprint(message : String) -> Unit {
  println(message)
}
