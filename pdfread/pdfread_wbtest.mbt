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

///|
test "lex_hexstring rejects invalid hex" {
  let input = @pdfio.input_of_string("<G>")
  let res : Result[@pdfgenlex.Token, Error] = try? lex_hexstring(input)
  match res {
    Err(_) => ()
    _ => fail("expected lex_hexstring failure")
  }
}

///|
test "lex_hexstring pads odd nibble" {
  let input = @pdfio.input_of_string("<F>")
  let token = lex_hexstring(input)
  match token {
    @pdfgenlex.Token::LexString(s) => {
      let bytes = @pdfio.bytes_of_string(s)
      assert_eq(bytes.length(), 1)
      assert_eq(bytes[0].to_int(), 0xF0)
    }
    _ => fail("expected LexString")
  }
}

///|
test "lex_hexstring ignores whitespace" {
  let input = @pdfio.input_of_string("<0F 0A>")
  let token = lex_hexstring(input)
  match token {
    @pdfgenlex.Token::LexString(s) => {
      let bytes = @pdfio.bytes_of_string(s)
      assert_eq(bytes.length(), 2)
      assert_eq(bytes[0].to_int(), 0x0F)
      assert_eq(bytes[1].to_int(), 0x0A)
    }
    _ => fail("expected LexString")
  }
}

///|
test "lex_dictionary minus_one stops after closing dict" {
  let input = @pdfio.input_of_string("/Type /Example >> trailer")
  let tokens = lex_dictionary(true, input)
  if tokens.length() == 0 {
    fail("expected tokens")
  }
  let last = tokens[tokens.length() - 1]
  match last {
    @pdfgenlex.Token::LexRightDict => ()
    _ => fail("expected closing dict")
  }
}

///|
test "lex_name rejects invalid hex" {
  let input = @pdfio.input_of_string("/#GZ")
  let res : Result[@pdfgenlex.Token, Error] = try? lex_name(input)
  match res {
    Err(_) => ()
    _ => fail("expected lex_name failure")
  }
}

///|
test "lex_name rejects truncated hex" {
  let input = @pdfio.input_of_string("/#1")
  let res : Result[@pdfgenlex.Token, Error] = try? lex_name(input)
  match res {
    Err(_) => ()
    _ => fail("expected lex_name failure")
  }
}
