///|
/// Small utility helpers used across the port.
/// More functions will be added as modules are ported.
pub let stdout_buffer : Ref[String] = Ref::new("")

///|
/// Buffered stderr text (rendered via println in async-only environments).
pub let stderr_buffer : Ref[String] = Ref::new("")

///|
/// Flush complete lines from a buffer using println, keeping partial tails.
fn flush_buffer(buffer : Ref[String], message : String) -> Unit {
  let combined = buffer.val + message
  let mut line = StringBuilder::new()
  for ch in combined {
    if ch == '\n' {
      println(line.to_string())
      line = StringBuilder::new()
    } else {
      line.write_char(ch)
    }
  }
  buffer.val = line.to_string()
}

///|
/// Print something and then flush standard output.
pub fn flprint(message : String) -> Unit {
  flush_buffer(stdout_buffer, message)
}

///|
/// Print something and then flush standard error.
pub fn fleprint(message : String) -> Unit {
  flush_buffer(stderr_buffer, message)
}

///|
/// Memoize a nullary function (cache the first computed value).
pub fn[T] memoize(f : () -> T raise) -> () -> T raise {
  let cached : Ref[T?] = Ref::new(None)
  let ready : Ref[Bool] = Ref::new(false)
  () => if ready.val {
    match cached.val {
      Some(value) => value
      None => f()
    }
  } else {
    let value = f()
    cached.val = Some(value)
    ready.val = true
    value
  }
}

///|
/// Build a hash map from a list of key/value pairs.
pub fn[K : Hash + Eq, V] hashtable_of_dictionary(
  pairs : Array[(K, V)],
) -> Map[K, V] {
  let table : Map[K, V] = Map::new(capacity=pairs.length() * 2)
  for pair in pairs {
    table.set(pair.0, pair.1)
  }
  table
}

///|
/// Construct an empty hash table.
pub fn[K, V] null_hash() -> Map[K, V] {
  Map::new(capacity=0)
}

///|
/// Extract all pairs from a hash table.
pub fn[K, V] list_of_hashtbl(table : Map[K, V]) -> Array[(K, V)] {
  table.to_array()
}
