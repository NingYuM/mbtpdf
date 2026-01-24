///|
test "log forwards to logger" {
  let messages : Array[String] = []
  let prev = @pdfe.Pdfe::new().logger.val
  @pdfe.Pdfe::new().logger.val = message => messages.push(message)
  @pdfe.Pdfe::new().log("hello")
  @pdfe.Pdfe::new().log("world")
  @pdfe.Pdfe::new().logger.val = prev
  inspect(messages, content="[\"hello\", \"world\"]")
}
