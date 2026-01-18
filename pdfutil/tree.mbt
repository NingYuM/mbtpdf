///|
/// Binary tree type.
pub enum Tree[A] {
  Lf
  Br(A, Tree[A], Tree[A])
}
