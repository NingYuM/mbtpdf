///|
test "lex quoted string with escaped quote" {
  let tokens = @pdfgenlex.lex_string("\"a\\\"b\"")
  if tokens.length() != 1 {
    fail("expected single token")
  }
  match tokens[0] {
    @pdfgenlex.Token::LexString(s) => assert_eq(s, "a\"b")
    _ => fail("expected LexString token")
  }
}

///|
test "string_of_tokens formats values" {
  let tokens = [
    @pdfgenlex.Token::LexInt(1),
    @pdfgenlex.Token::LexReal(1.5),
    @pdfgenlex.Token::LexName("abc"),
  ]
  let rendered = @pdfgenlex.string_of_tokens(tokens)
  assert_true(rendered.contains("Int 1"))
  assert_true(rendered.contains("Float 1.5"))
  assert_true(rendered.contains("Ident abc"))
}

///|
test "lex_string parses numbers and names" {
  let tokens = @pdfgenlex.lex_string("10 -5 3.14 -2.5e2 name")
  assert_eq(tokens.length(), 5)
  match tokens[0] {
    @pdfgenlex.Token::LexInt(10) => ()
    _ => fail("expected LexInt 10")
  }
  match tokens[1] {
    @pdfgenlex.Token::LexInt(-5) => ()
    _ => fail("expected LexInt -5")
  }
  match tokens[2] {
    @pdfgenlex.Token::LexReal(v) => assert_true((v - 3.14).abs() < 0.000001)
    _ => fail("expected LexReal 3.14")
  }
  match tokens[3] {
    @pdfgenlex.Token::LexReal(v) => assert_true((v - -250.0).abs() < 0.000001)
    _ => fail("expected LexReal -250.0")
  }
  match tokens[4] {
    @pdfgenlex.Token::LexName("name") => ()
    _ => fail("expected LexName name")
  }
}

///|
test "lex_string ignores whitespace-only input" {
  let tokens = @pdfgenlex.lex_string(" \n\t ")
  assert_eq(tokens.length(), 0)
}
