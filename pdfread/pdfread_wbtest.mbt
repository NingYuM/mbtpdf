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

///|
test "lex_next returns LexNone for unknown uppercase" {
  let input = @pdfio.input_of_string("T")
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let previous = Array::new()
  let dummy_lexobj = fn(_ : Int) -> Array[@pdfgenlex.Token] raise {
    Array::new()
  }
  let token = lex_next(
    dict_level, array_level, false, input, previous, true, dummy_lexobj,
  )
  match token {
    @pdfgenlex.Token::LexNone => ()
    _ => fail("expected LexNone")
  }
}

///|
test "lex_next recovers from lex errors" {
  let input = @pdfio.input_of_string("(")
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let previous = Array::new()
  let dummy_lexobj = fn(_ : Int) -> Array[@pdfgenlex.Token] raise {
    Array::new()
  }
  let token = lex_next(
    dict_level, array_level, false, input, previous, true, dummy_lexobj,
  )
  match token {
    @pdfgenlex.Token::StopLexing => ()
    _ => fail("expected StopLexing")
  }
}
