///|
fn clock() -> Double {
  @env.now().to_double() / 1000.0
}

///|
let time : Ref[Double] = Ref::new(0.0)

///|
/// Debug timing hook (OCaml's [tt']).
pub fn tt_prime() -> Unit {
  let _ = clock()
  let _ = time
  ()
}
