///|
async test "files read/write helpers" {
  let dir = "tmp/pdfutil_io"
  if @fs.exists(dir) {
    @fs.rmdir(dir, recursive=true)
  }
  @fs.mkdir(dir, permission=0o755, recursive=true)
  let path = dir + "/sample.bin"
  let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
  defer file.close()
  let data : Array[Byte] = [0, 1, 2, 3, 255]
  contents_to_file(path, data)
  let read_back = contents_of_file(path)
  assert_eq(read_back, data)
  let names = leafnames_of_dir(dir)
  assert_true(names.contains("sample.bin"))
  @fs.rmdir(dir, recursive=true)
}
