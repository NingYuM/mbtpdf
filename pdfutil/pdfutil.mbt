///|
/// Small utility helpers used across the port.
/// More functions will be added as modules are ported.
pub let stdout_file : Ref[@fs.File?] = Ref::new(None)

///|
/// Cached stderr file handle.
pub let stderr_file : Ref[@fs.File?] = Ref::new(None)

///|
/// Open a special output path lazily and cache the handle.
fn open_special(path : String, slot : Ref[@fs.File?]) -> @fs.File? {
  match slot.val {
    Some(file) => Some(file)
    None => {
      @async.run_async_main(() => {
        let res : Result[@fs.File, Error] = try? @fs.open(
          path,
          mode=WriteOnly,
          append=true,
        )
        match res {
          Ok(file) => slot.val = Some(file)
          Err(_) => ()
        }
      })
      slot.val
    }
  }
}

///|
/// Print something and then flush standard output.
pub fn flprint(message : String) -> Unit {
  match open_special("/dev/stdout", stdout_file) {
    Some(file) =>
      @async.run_async_main(() => {
        let _ : Result[Unit, Error] = try? file.write(message)
        let _ : Result[Unit, Error] = try? file.sync(only_data=true)
        ()
      })
    None => println(message)
  }
}

///|
/// Print something and then flush standard error.
pub fn fleprint(message : String) -> Unit {
  match open_special("/dev/stderr", stderr_file) {
    Some(file) =>
      @async.run_async_main(() => {
        let _ : Result[Unit, Error] = try? file.write(message)
        let _ : Result[Unit, Error] = try? file.sync(only_data=true)
        ()
      })
    None => println(message)
  }
}

///|
/// Print a list of floating point numbers separated by spaces.
pub fn print_floats(values : Array[Double]) -> Unit {
  let sb = StringBuilder::new()
  for i, value in values {
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_object(value)
  }
  flprint(sb.to_string())
}

///|
/// Print a list of integers separated by spaces.
pub fn print_ints(values : Array[Int]) -> Unit {
  let sb = StringBuilder::new()
  for i, value in values {
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_object(value)
  }
  flprint(sb.to_string())
}

///|
/// Print a list of int32 values separated by spaces.
pub fn print_int32s(values : Array[Int]) -> Unit {
  let sb = StringBuilder::new()
  for i, value in values {
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_object(value)
  }
  flprint(sb.to_string())
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
/// Build a hash set from a list of keys.
pub fn[K : Hash + Eq] hashset_of_list(values : Array[K]) -> Map[K, Unit] {
  let table : Map[K, Unit] = Map::new(capacity=values.length() * 2)
  for value in values {
    table.set(value, ())
  }
  table
}

///|
/// Construct an empty hash table.
pub fn[K, V] null_hash() -> Map[K, V] {
  Map::new(capacity=0)
}

///|
/// Lookup an entry in a hash table.
pub fn[K : Hash + Eq, V] tryfind(table : Map[K, V], key : K) -> V? {
  table.get(key)
}

///|
/// Extract all pairs from a hash table.
pub fn[K, V] list_of_hashtbl(table : Map[K, V]) -> Array[(K, V)] {
  table.to_array()
}
