///|
/// Roman numeral values used for conversion (under 1000).
let roman_vals : Array[(Int, String)] = [
  (900, "CM"),
  (500, "D"),
  (400, "CD"),
  (100, "C"),
  (100, "C"),
  (100, "C"),
  (90, "XC"),
  (50, "L"),
  (40, "XL"),
  (10, "X"),
  (10, "X"),
  (10, "X"),
  (9, "IX"),
  (5, "V"),
  (4, "IV"),
  (1, "I"),
  (1, "I"),
  (1, "I"),
]

///|
/// Convert an integer to a roman numeral (upper case).
pub fn roman(n : Int) -> String {
  if n < 1 {
    ""
  } else if n >= 1000 {
    let count = n / 1000
    let sb = StringBuilder::new(size_hint=count)
    for _ in 0..<count {
      sb.write_char('M')
    }
    sb.to_string() + roman(n % 1000)
  } else {
    fn roman_recurse(value : Int, vals : Array[(Int, String)]) -> String {
      match vals {
        [] => ""
        [head, ..tail] =>
          if value >= head.0 {
            head.1 + roman_recurse(value - head.0, tail.to_array())
          } else {
            roman_recurse(value, tail.to_array())
          }
      }
    }

    roman_recurse(n, roman_vals)
  }
}

///|
/// Uppercase roman numeral.
pub fn roman_upper(n : Int) -> String {
  roman(n)
}

///|
/// Lowercase roman numeral.
pub fn roman_lower(n : Int) -> String {
  roman(n).to_lower()
}
