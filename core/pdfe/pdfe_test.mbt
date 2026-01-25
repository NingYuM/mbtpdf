///|
test "log forwards to logger" {
  let messages : Array[String] = []
  let prev = @pdfe.logger.val
  @pdfe.logger.val = message => messages.push(message)
  @pdfe.log("hello")
  @pdfe.log("world")
  @pdfe.logger.val = prev
  inspect(messages, content="[\"hello\", \"world\"]")
}
