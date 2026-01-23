///|
async fn read_data_to_bytes(load : async () -> &@io.Data) -> Array[Byte] {
  let data = load()
  data.binary().to_array()
}

///|
async fn run_async_unit(load : async () -> Unit) -> Unit {
  load()
}

///|
/// Read an entire file into a byte array.
pub async fn contents_of_file(filename : String) -> Array[Byte] {
  read_data_to_bytes(() => @fs.read_file(filename))
}

///|
/// Write a byte array to a file (truncating).
pub async fn contents_to_file(filename : String, data : Array[Byte]) -> Unit {
  run_async_unit(() => @fs.write_file(filename, Bytes::from_array(data)))
}

///|
/// List leaf file names in a directory.
pub async fn leafnames_of_dir(path : String) -> Array[String] {
  @fs.readdir(path)
}
