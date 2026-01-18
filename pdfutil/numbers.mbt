///|
/// Round a real to the nearest integer value as a Double.
pub fn round(value : Double) -> Double {
  let ceil = value.ceil()
  let floor = value.floor()
  if ceil - value <= value - floor {
    ceil
  } else {
    floor
  }
}

///|
/// Round a real and return as Int.
pub fn iround(value : Double) -> Int {
  round(value).to_int()
}

///|
/// The largest power of two by which a number is exactly divisible.
pub fn largest_pow2_divisible(value : Int) -> Int {
  if value == 0 {
    return 0
  }
  let mut factor = 1
  while factor <= @int.max_value / 2 && value % (factor * 2) == 0 {
    factor = factor * 2
  }
  factor
}

///|
/// Largest power of two smaller or equal to an integer.
pub fn pow2lt(value : Int) -> Int {
  let mut current = 1
  while current * 2 <= value {
    current = current * 2
  }
  current
}

///|
/// Largest power of two greater or equal to an integer.
pub fn pow2gt(value : Int) -> Int {
  let lt = pow2lt(value)
  if lt == value {
    value
  } else {
    lt * 2
  }
}

///|
/// Base two logarithm for integers.
pub fn log2of(value : Int) -> Int {
  let mut num = 1
  let mut count = 0
  while num * 2 <= value {
    num = num * 2
    count += 1
  }
  count
}

///|
/// [pow exp base] is base to the power exp.
pub fn pow(exp : Int, base : Int) -> Int {
  match exp {
    0 => 1
    1 => base
    _ => {
      let half = pow(exp / 2, base * base)
      if exp % 2 == 0 {
        half
      } else {
        half * base
      }
    }
  }
}

///|
/// Monomorphic integer compare.
pub fn compare_i(a : Int, b : Int) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
/// Monomorphic integer min.
pub fn min(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Monomorphic integer max.
pub fn max(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Monomorphic floating-point min.
pub fn fmin(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Monomorphic floating-point max.
pub fn fmax(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Floating-point absolute value.
pub fn fabs(value : Double) -> Double {
  value.abs()
}

///|
/// Even predicate on integers.
pub fn even(value : Int) -> Bool {
  value % 2 == 0
}

///|
/// Odd predicate on integers.
pub fn odd(value : Int) -> Bool {
  value % 2 != 0
}

///|
/// Pi constant.
pub let pi : Double = @math.PI

///|
/// Square root of two.
pub let root2 : Double = 2.0.sqrt()

///|
/// Convert degrees to radians.
pub fn rad_of_deg(deg : Double) -> Double {
  deg * pi / 180.0
}

///|
/// Convert radians to degrees.
pub fn deg_of_rad(rad : Double) -> Double {
  rad * 180.0 / pi
}

///|
/// Extend [value] of length [bits] to fit a native integer.
pub fn sign_extend(bits : Int, value : Int) -> Int {
  let shift = 31 - bits
  value << shift >> shift
}

///|
/// True when a character is a decimal digit.
pub fn isdigit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
/// Convert a Double to Int.
pub fn toint(value : Double) -> Int {
  value.to_int()
}

///|
/// Normalize a float by replacing abnormal values with 0.
pub fn safe_float(value : Double) -> Double {
  let abs = value.abs()
  if value.is_nan() || value.is_inf() || abs < @double.min_positive {
    0.0
  } else {
    value
  }
}
