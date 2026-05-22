///|
test "parse_glyphlist_line handles skipped cases" {
  assert_true(parse_glyphlist_line("") == None)
  assert_true(parse_glyphlist_line("NoSemicolonHere") == None)
  match parse_glyphlist_line("A; 0041  ZZZ 0042") {
    Some((name, codes)) => {
      assert_true(name == "/A")
      assert_true(codes == [0x41, 0x42])
    }
    None => fail("expected parsed glyphlist entry")
  }
}
