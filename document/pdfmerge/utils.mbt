///|
/// Compare two byte arrays lexicographically.
fn compare_bytes(left : Array[Byte], right : Array[Byte]) -> Int {
  let min_len = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for i in 0..<min_len {
    let a = left[i].to_int()
    let b = right[i].to_int()
    if a != b {
      return a - b
    }
  }
  if left.length() == right.length() {
    0
  } else if left.length() < right.length() {
    -1
  } else {
    1
  }
}

///|
fn[T] flatten(lists : Array[Array[T]]) -> Array[T] {
  let mut total = 0
  for list in lists {
    total = total + list.length()
  }
  let out = Array::new(capacity=total)
  for list in lists {
    out.append(list[:])
  }
  out
}

///|
fn ilist(start : Int, finish : Int) -> Array[Int] {
  if finish < start {
    return []
  }
  let out = Array::new(capacity=finish - start + 1)
  for i in start..<=finish {
    out.push(i)
  }
  out
}

///|
fn contains_int(values : Array[Int], value : Int) -> Bool {
  values.search_by(v => v == value) is Some(_)
}

///|
fn[T] slice(values : Array[T], start : Int, count : Int) -> Array[T] raise {
  if start < 0 || count < 0 || start + count > values.length() {
    raise @pdf.PdfError::Msg("slice: out of bounds")
  }
  let out = Array::new(capacity=count)
  for i in 0..<count {
    out.push(values[start + i])
  }
  out
}

///|
fn[K : Eq, V] lookup(key : K, pairs : Array[(K, V)]) -> V? {
  match pairs.search_by(pair => pair.0 == key) {
    Some(i) => Some(pairs[i].1)
    None => None
  }
}

///|
fn[K : Eq, V] lookup_fail(
  key : K,
  pairs : Array[(K, V)],
  err : String,
) -> V raise {
  match lookup(key, pairs) {
    Some(value) => value
    None => raise @pdf.PdfError::Msg(err)
  }
}

///|
fn[A, B] combine(left : Array[A], right : Array[B]) -> Array[(A, B)] raise {
  if left.length() != right.length() {
    raise @pdf.PdfError::Msg("combine: length mismatch")
  }
  let out = Array::new(capacity=left.length())
  for i in 0..<left.length() {
    out.push((left[i], right[i]))
  }
  out
}

///|
fn[T] collate(items : Array[T], cmp : (T, T) -> Int) -> Array[Array[T]] {
  let out = Array::new()
  let mut i = 0
  while i < items.length() {
    let group = Array::new()
    group.push(items[i])
    let mut j = i + 1
    while j < items.length() && cmp(items[i], items[j]) == 0 {
      group.push(items[j])
      j = j + 1
    }
    out.push(group)
    i = j
  }
  out
}

///|
fn setify_strings(values : Array[String]) -> Array[String] {
  let seen = Map::new(capacity=values.length())
  let out = Array::new()
  for value in values {
    if seen.get(value) is None {
      seen.set(value, ())
      out.push(value)
    }
  }
  out
}

///|
fn remove_entry(
  entries : Array[(String, PdfObject)],
  key : String,
) -> Array[(String, PdfObject)] {
  entries.filter(entry => entry.0 != key)
}

///|
fn add_entry(
  entries : Array[(String, PdfObject)],
  key : String,
  value : PdfObject,
) -> Array[(String, PdfObject)] {
  match entries.search_by(entry => entry.0 == key) {
    None => {
      let out = entries[:].to_array()
      out.push((key, value))
      out
    }
    Some(_) =>
      entries.map(entry => if entry.0 == key { (key, value) } else { entry })
  }
}
