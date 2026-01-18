///|
test "lookup_chain handles array keys" {
  let pdf = empty()
  pdf.trailerdict = Dictionary([("/A", Array([Integer(10), Integer(20)]))])
  let keys = ["/A", "/[1]"]
  match lookup_chain(pdf, pdf.trailerdict, keys[:]) {
    Some(Integer(value)) => assert_eq(value, 20)
    _ => fail("expected array element")
  }
}

///|
test "replace_chain updates array elements" {
  let pdf = empty()
  pdf.trailerdict = Dictionary([("/A", Array([Integer(1), Integer(2)]))])
  let chain = ["/A", "/[0]"]
  replace_chain(pdf, chain[:], Integer(99))
  match lookup_chain(pdf, pdf.trailerdict, chain[:]) {
    Some(Integer(value)) => assert_eq(value, 99)
    _ => fail("expected replaced array element")
  }
}
