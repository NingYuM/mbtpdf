///|
test "lex_name decodes hex escapes" {
  let input = @pdfio.input_of_string("/A#20B")
  let token = @pdfread.lex_name(input)
  match token {
    @pdfgenlex.Token::LexName(name) => assert_eq(name, "/A B")
    _ => fail("expected LexName")
  }
}

///|
test "lex_number parses int and real" {
  let int_input = @pdfio.input_of_string("123 ")
  match @pdfread.lex_number(int_input) {
    @pdfgenlex.Token::LexInt(123) => ()
    _ => fail("expected LexInt 123")
  }
  let real_input = @pdfio.input_of_string("-3.5")
  match @pdfread.lex_number(real_input) {
    @pdfgenlex.Token::LexReal(v) => assert_true((v - -3.5).abs() < 0.000001)
    _ => fail("expected LexReal -3.5")
  }
}

///|
test "lex_string handles escapes and nesting" {
  let input = @pdfio.input_of_string("(a\\n(b))")
  let token = @pdfread.lex_string(input)
  match token {
    @pdfgenlex.Token::LexString(value) => assert_eq(value, "a\n(b)")
    _ => fail("expected LexString")
  }
}

///|
test "lex_hexstring reads hex bytes" {
  let input = @pdfio.input_of_string("<48656c6c6f>")
  let token = @pdfread.lex_hexstring(input)
  match token {
    @pdfgenlex.Token::LexString(value) => assert_eq(value, "Hello")
    _ => fail("expected LexString")
  }
}
