///|
test "lex_keyword rewinds endobj suffix" {
  let input = @pdfio.input_of_string("endobj123 0 obj")
  let token = lex_keyword(input)
  match token {
    @pdfgenlex.Token::LexEndObj => ()
    _ => fail("expected LexEndObj")
  }
  match lex_number(input) {
    @pdfgenlex.Token::LexInt(123) => ()
    _ => fail("expected 123")
  }
}
