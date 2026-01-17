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
