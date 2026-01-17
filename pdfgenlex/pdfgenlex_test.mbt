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
