///|
/// Buffered stdout text (rendered via println in async-only environments).
let stdout_buffer : Ref[String] = Ref::new("")

///|
/// Buffered stderr text (rendered via println in async-only environments).
let stderr_buffer : Ref[String] = Ref::new("")

///|
pub struct PdfUtil {
  stdout_buffer : Ref[String]
  stderr_buffer : Ref[String]
}

///|
pub fn PdfUtil::new() -> PdfUtil {
  { stdout_buffer, stderr_buffer }
}

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
#as_free_fn(flprint, deprecated="Use `PdfUtil::flprint`")
pub fn PdfUtil::flprint(self : PdfUtil, message : String) -> Unit {
  flush_buffer(self.stdout_buffer, message)
}

///|
/// Print something and then flush standard error.
#as_free_fn(fleprint, deprecated="Use `PdfUtil::fleprint`")
pub fn PdfUtil::fleprint(self : PdfUtil, message : String) -> Unit {
  flush_buffer(self.stderr_buffer, message)
}

///|
/// Memoize a nullary function (cache the first computed value).
#as_free_fn(memoize, deprecated="Use `PdfUtil::memoize`")
pub fn[T] PdfUtil::memoize(_self : PdfUtil, f : () -> T raise) -> () -> T raise {
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
#as_free_fn(hashtable_of_dictionary, deprecated="Use `PdfUtil::hashtable_of_dictionary`")
pub fn[K : Hash + Eq, V] PdfUtil::hashtable_of_dictionary(
  _self : PdfUtil,
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
#as_free_fn(null_hash, deprecated="Use `PdfUtil::null_hash`")
pub fn[K, V] PdfUtil::null_hash(_self : PdfUtil) -> Map[K, V] {
  Map::new(capacity=0)
}

///|
/// Extract all pairs from a hash table.
#as_free_fn(list_of_hashtbl, deprecated="Use `PdfUtil::list_of_hashtbl`")
pub fn[K, V] PdfUtil::list_of_hashtbl(
  _self : PdfUtil,
  table : Map[K, V],
) -> Array[(K, V)] {
  let out = Array::new(capacity=table.length())
  for entry in table {
    out.push(entry)
  }
  out
}
