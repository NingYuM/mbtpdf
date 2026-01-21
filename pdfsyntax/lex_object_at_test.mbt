///|
fn lex_from_string(
  oneonly : Bool,
  source : String,
) -> Array[@pdfgenlex.Token] raise {
  let input = @pdfio.input_of_string(source)
  lex_object_at(oneonly, input, true, fn(
    _ : Int,
  ) -> Array[@pdfgenlex.Token] raise {
    Array::new()
  })
}

///|
test "lex_object_at stops at atom when oneonly" {
  let tokens = lex_from_string(true, "123 456")
  match tokens {
    [@pdfgenlex.Token::LexInt(123)] => ()
    _ => fail("expected single integer lexeme")
  }
}

///|
test "lex_object_at captures array tokens" {
  let tokens = lex_from_string(true, "[1 2]")
  let rendered : Array[String] = Array::new()
  for token in tokens {
    rendered.push(string_of_lexeme(token))
  }
  assert_eq(rendered, ["[", "1", "2", "]"])
}

///|
test "lex_object_at captures dictionary tokens" {
  let tokens = lex_from_string(true, "<< /Type /Example /Count 2 >>")
  let rendered : Array[String] = Array::new()
  for token in tokens {
    rendered.push(string_of_lexeme(token))
  }
  assert_eq(rendered, ["<<", "/Type", "/Example", "/Count", "2", ">>"])
}
