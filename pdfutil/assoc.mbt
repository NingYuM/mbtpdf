///|
fn[A] not_found() -> A raise {
  fail("Not_found")
}

///|
/// Lookup a key in an association list.
pub fn[K : Eq, V] lookup(key : K, dict : Array[(K, V)]) -> V? {
  for pair in dict {
    if pair.0 == key {
      return Some(pair.1)
    }
  }
  None
}

///|
/// Lookup a key in an association list, failing if missing.
pub fn[K : Eq, V] lookup_failnull(key : K, dict : Array[(K, V)]) -> V raise {
  match lookup(key, dict) {
    Some(value) => value
    None => not_found()
  }
}

///|
/// Add a binding to an association list, replacing any existing one.
pub fn[K : Eq, V] add(
  key : K,
  value : V,
  dict : Array[(K, V)],
) -> Array[(K, V)] {
  let len = dict.length()
  let mut found = false
  let out : Array[(K, V)] = Array::new(capacity=len + 1)
  for i in 0..<len {
    let pair = dict[i]
    if !found && pair.0 == key {
      out.push((key, value))
      found = true
    } else {
      out.push(pair)
    }
  }
  if !found {
    out.push((key, value))
  }
  out
}

///|
/// Replace an existing binding, failing if the key is missing.
pub fn[K : Eq, V] replace(
  key : K,
  value : V,
  dict : Array[(K, V)],
) -> Array[(K, V)] raise {
  let len = dict.length()
  let mut found = false
  let out : Array[(K, V)] = Array::new(capacity=len)
  for i in 0..<len {
    let pair = dict[i]
    if !found && pair.0 == key {
      out.push((key, value))
      found = true
    } else {
      out.push(pair)
    }
  }
  if !found {
    not_found()
  }
  out
}

///|
/// Remove a key from an association list.
pub fn[K : Eq, V] remove(key : K, dict : Array[(K, V)]) -> Array[(K, V)] {
  let len = dict.length()
  let out : Array[(K, V)] = Array::new(capacity=len)
  let mut removed = false
  for i in 0..<len {
    let pair = dict[i]
    if !removed && pair.0 == key {
      removed = true
    } else {
      out.push(pair)
    }
  }
  out
}

///|
/// Merge two association lists, preferring entries in [overrides].
pub fn[K : Eq, V] mergedict(
  base : Array[(K, V)],
  overrides : Array[(K, V)],
) -> Array[(K, V)] {
  let mut out = base.copy()
  for pair in overrides {
    out = add(pair.0, pair.1, out)
  }
  out
}
