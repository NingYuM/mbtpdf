///|
/// Shortened names for Int helpers (Int is 32-bit in MoonBit).
pub fn i32ofi(value : Int) -> Int {
  value
}

///|
pub fn i32toi(value : Int) -> Int {
  value
}

///|
pub fn i32tof(value : Int) -> Double {
  value.to_double()
}

///|
pub fn i32add(a : Int, b : Int) -> Int {
  a + b
}

///|
pub fn i32sub(a : Int, b : Int) -> Int {
  a - b
}

///|
pub fn i32div(a : Int, b : Int) -> Int {
  a / b
}

///|
pub fn i32mul(a : Int, b : Int) -> Int {
  a * b
}

///|
pub fn sr32(value : Int, bits : Int) -> Int {
  value >> bits
}

///|
pub fn lsr32(value : Int, bits : Int) -> Int {
  let shifted = value.reinterpret_as_uint() >> bits
  shifted.reinterpret_as_int()
}

///|
pub fn lsl32(value : Int, bits : Int) -> Int {
  value << bits
}

///|
pub fn lor32(a : Int, b : Int) -> Int {
  a | b
}

///|
pub fn land32(a : Int, b : Int) -> Int {
  a & b
}

///|
pub fn lnot32(value : Int) -> Int {
  value.lnot()
}

///|
pub fn lxor32(a : Int, b : Int) -> Int {
  a ^ b
}

///|
pub fn i32succ(value : Int) -> Int {
  value + 1
}

///|
pub fn i32pred(value : Int) -> Int {
  value - 1
}

///|
pub fn i32max(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
pub fn i32min(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn i64ofi(value : Int) -> Int64 {
  Int64::from_int(value)
}

///|
pub fn i64toi(value : Int64) -> Int {
  value.to_int()
}

///|
pub fn i64tof(value : Int64) -> Double {
  value.to_double()
}

///|
pub fn i64add(a : Int64, b : Int64) -> Int64 {
  Int64::add(a, b)
}

///|
pub fn i64sub(a : Int64, b : Int64) -> Int64 {
  Int64::sub(a, b)
}

///|
pub fn i64div(a : Int64, b : Int64) -> Int64 {
  Int64::div(a, b)
}

///|
pub fn i64mul(a : Int64, b : Int64) -> Int64 {
  Int64::mul(a, b)
}

///|
pub fn sr64(value : Int64, bits : Int) -> Int64 {
  value >> bits
}

///|
pub fn lsr64(value : Int64, bits : Int) -> Int64 {
  let shifted = value.reinterpret_as_uint64() >> bits
  shifted.reinterpret_as_int64()
}

///|
pub fn lsl64(value : Int64, bits : Int) -> Int64 {
  value << bits
}

///|
pub fn lor64(a : Int64, b : Int64) -> Int64 {
  Int64::lor(a, b)
}

///|
pub fn land64(a : Int64, b : Int64) -> Int64 {
  Int64::land(a, b)
}

///|
pub fn lnot64(value : Int64) -> Int64 {
  Int64::lnot(value)
}

///|
pub fn lxor64(a : Int64, b : Int64) -> Int64 {
  Int64::lxor(a, b)
}

///|
pub fn i64succ(value : Int64) -> Int64 {
  Int64::add(value, 1)
}

///|
pub fn i64pred(value : Int64) -> Int64 {
  Int64::sub(value, 1)
}

///|
pub fn i64max(a : Int64, b : Int64) -> Int64 {
  if a > b {
    a
  } else {
    b
  }
}

///|
pub fn i64min(a : Int64, b : Int64) -> Int64 {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn i32ofi64(value : Int64) -> Int {
  value.to_int()
}

///|
pub fn i64ofi32(value : Int) -> Int64 {
  Int64::from_int(value)
}
