///|
fn read_data_to_bytes(load : async () -> &@io.Data) -> Array[Byte] raise {
  let result : Ref[Result[Array[Byte], Error]] = Ref::new(
    Err(Failure::Failure("uninitialized async read")),
  )
  @async.run_async_main(() => {
    let data_res : Result[&@io.Data, Error] = try? load()
    result.val = match data_res {
      Ok(data) => Ok(data.binary().to_array())
      Err(err) => Err(err)
    }
  })
  match result.val {
    Ok(bytes) => bytes
    Err(err) => raise err
  }
}

///|
fn run_async_unit(load : async () -> Unit) -> Unit raise {
  let result : Ref[Result[Unit, Error]] = Ref::new(
    Err(Failure::Failure("uninitialized async write")),
  )
  @async.run_async_main(() => {
    let res : Result[Unit, Error] = try? load()
    result.val = res
  })
  match result.val {
    Ok(_) => ()
    Err(err) => raise err
  }
}

///|
/// Read an entire file into a byte array.
pub fn contents_of_file(filename : String) -> Array[Byte] raise {
  read_data_to_bytes(() => @fs.read_file(filename))
}

///|
/// Write a byte array to a file (truncating).
pub fn contents_to_file(filename : String, data : Array[Byte]) -> Unit raise {
  run_async_unit(() => @fs.write_file(filename, Bytes::from_array(data)))
}

///|
/// List leaf file names in a directory.
pub fn leafnames_of_dir(path : String) -> Array[String] raise {
  let result : Ref[Result[Array[String], Error]] = Ref::new(
    Err(Failure::Failure("uninitialized async readdir")),
  )
  @async.run_async_main(() => {
    let res : Result[Array[String], Error] = try? @fs.readdir(path)
    result.val = res
  })
  match result.val {
    Ok(names) => names
    Err(err) => raise err
  }
}
