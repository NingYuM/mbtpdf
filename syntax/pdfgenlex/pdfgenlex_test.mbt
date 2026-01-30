///|
test "lex quoted string with escaped quote" {
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string("\"a\\\"b\"")
  debug_inspect(
    tokens,
    content=(
      #|[LexString("a\"b")]
    ),
  )
}

///|
test "string_of_tokens formats values" {
  let tokens = [
    @pdfgenlex.Token::LexInt(1),
    @pdfgenlex.Token::LexReal(1.5),
    @pdfgenlex.Token::LexName("abc"),
  ]
  debug_inspect(
    tokens,
    content=(
      #|[
      #|  LexInt(1),
      #|  LexReal(1.5),
      #|  LexName("abc"),
      #|]
    ),
  )
}

///|
test "lex_string parses numbers and names" {
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string("10 -5 3.14 -2.5e2 name")
  debug_inspect(
    tokens,
    content=(
      #|[
      #|  LexInt(10),
      #|  LexInt(-5),
      #|  LexReal(3.14),
      #|  LexReal(-250),
      #|  LexName("name"),
      #|]
    ),
  )
}

///|
test "lex_string ignores whitespace-only input" {
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string(" \n\t ")
  debug_inspect(tokens, content="[]")
}


///|
test "lex_string tokenizes delimiter characters" {
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string("()<>[]{}%/")
  debug_inspect(
    tokens,
    content=(
      #|[
      #|  LexName("("),
      #|  LexName(")"),
      #|  LexName("<"),
      #|  LexName(">"),
      #|  LexName("["),
      #|  LexName("]"),
      #|  LexName("{"),
      #|  LexName("}"),
      #|  LexName("%"),
      #|  LexName("/"),
      #|]
    ),
  )
}

///|
test "lex_string handles malformed strings" {
  let lex = @pdfgenlex.PdfGenLex::new()
  debug_inspect(lex.lex_string("\"x"), content="[LexString(\"\")]")
  debug_inspect(lex.lex_string("\"a\\"), content="[LexString(\"\")]")
  debug_inspect(lex.lex_string("\"a\\n\""), content="[LexString(\"a\\\\n\")]")
}

///|
test "lex_string treats invalid exponential as name" {
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string("1e--2")
  debug_inspect(tokens, content="[LexName(\"1e--2\")]")
}

///|
test "lex_string parses huge integer as real" {
  let big = "999999999999999999999999999999999999999999"
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string(big)
  debug_inspect(tokens, content="[LexReal(1e+42)]")
}

///|
test "lex_string handles double dash numbers" {
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string("--5")
  debug_inspect(tokens, content="[LexInt(-5)]")
}
