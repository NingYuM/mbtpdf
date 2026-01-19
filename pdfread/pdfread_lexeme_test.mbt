///|
test "string_of_lexeme renders tokens" {
  assert_eq(@pdfread.string_of_lexeme(@pdfgenlex.Token::LexNull), "null")
  assert_eq(@pdfread.string_of_lexeme(@pdfgenlex.Token::LexBool(true)), "true")
  assert_eq(
    @pdfread.string_of_lexeme(@pdfgenlex.Token::LexBool(false)),
    "false",
  )
  assert_eq(@pdfread.string_of_lexeme(@pdfgenlex.Token::LexInt(12)), "12")
  assert_eq(
    @pdfread.string_of_lexeme(@pdfgenlex.Token::LexName("/Name")),
    "/Name",
  )
  assert_eq(@pdfread.string_of_lexeme(@pdfgenlex.Token::LexLeftSquare), "[")
  assert_eq(@pdfread.string_of_lexeme(@pdfgenlex.Token::LexRightSquare), "]")
  assert_eq(@pdfread.string_of_lexeme(@pdfgenlex.Token::LexLeftDict), "<<")
  assert_eq(@pdfread.string_of_lexeme(@pdfgenlex.Token::LexRightDict), ">>")
  assert_eq(
    @pdfread.string_of_lexeme(@pdfgenlex.Token::LexEndStream),
    "EndStream",
  )
  assert_eq(@pdfread.string_of_lexeme(@pdfgenlex.Token::LexObj), "obj")
  assert_eq(@pdfread.string_of_lexeme(@pdfgenlex.Token::LexEndObj), "endobj")
  assert_eq(@pdfread.string_of_lexeme(@pdfgenlex.Token::LexR), "R")
  assert_eq(
    @pdfread.string_of_lexeme(@pdfgenlex.Token::StopLexing),
    "StopLexing",
  )
  assert_eq(@pdfread.string_of_lexeme(@pdfgenlex.Token::LexNone), "LexNone")
}

///|
test "string_of_lexeme escapes string data" {
  let value = "a(b)\\\n"
  let token = @pdfgenlex.Token::LexString(value)
  assert_eq(@pdfread.string_of_lexeme(token), "(a\\(b\\)\\\\\\n)")
}

///|
test "string_of_lexeme prints comments and streams" {
  assert_eq(
    @pdfread.string_of_lexeme(@pdfgenlex.Token::LexComment("note")),
    "\n%note\n",
  )
  let stream = @pdf.Stream::Got(@pdfio.bytes_of_string("data"))
  assert_eq(
    @pdfread.string_of_lexeme(@pdfgenlex.Token::LexStream(stream)),
    "LexStream",
  )
}

///|
test "string_of_lexeme formats scientific real" {
  let candidates : Array[Double] = [1.0e-40, -1.0e-40, 1.0e40]
  let mut picked : Double? = None
  for candidate in candidates {
    let raw = candidate.to_string()
    if raw.contains("e") || raw.contains("E") {
      picked = Some(candidate)
    }
  }
  let value = match picked {
    Some(v) => v
    None => fail("expected scientific notation in Double::to_string")
  }
  let formatted = @pdfread.string_of_lexeme(@pdfgenlex.Token::LexReal(value))
  assert_true(!formatted.contains("e") && !formatted.contains("E"))
}

///|
test "print_lexeme emits output" {
  @pdfread.print_lexeme(@pdfgenlex.Token::LexNull)
}
