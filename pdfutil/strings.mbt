///|
/// Return the first character of a string, if present.
pub fn firstchar(text : String) -> Char? {
  text.get_char(0)
}

///|
/// Return the last character of a string, if present.
pub fn lastchar(text : String) -> Char? {
  let mut last : Char? = None
  for ch in text {
    last = Some(ch)
  }
  last
}

///|
/// List of characters representing a string.
pub fn explode(text : String) -> Array[Char] {
  let out : Array[Char] = Array::new(capacity=text.length())
  for ch in text {
    out.push(ch)
  }
  out
}

///|
/// String representing a list of characters.
pub fn implode(chars : Array[Char]) -> String {
  let sb = StringBuilder::new(size_hint=chars.length())
  for ch in chars {
    sb.write_char(ch)
  }
  sb.to_string()
}

///|
/// Make a string from a character.
pub fn string_of_char(ch : Char) -> String {
  let sb = StringBuilder::new(size_hint=1)
  sb.write_char(ch)
  sb.to_string()
}

///|
/// Replace all instances of [old] with [replacement] in [text].
pub fn string_replace_all(
  old : String,
  replacement : String,
  text : String,
) -> String {
  if old is "" {
    text
  } else {
    text.replace_all(old~, new=replacement)
  }
}

///|
/// The same as [string_replace_all], but compute the replacement lazily.
pub fn string_replace_all_lazy(
  old : String,
  replacement : () -> String,
  text : String,
) -> String {
  if old is "" {
    text
  } else {
    let sb = StringBuilder::new()
    let mut first = true
    for part in text.split(old) {
      if first {
        first = false
      } else {
        sb.write_string(replacement())
      }
      sb.write_view(part)
    }
    sb.to_string()
  }
}

///|
/// True if [text] starts with [prefix].
pub fn starts_with(text : String, prefix : String) -> Bool {
  text.has_prefix(prefix)
}
