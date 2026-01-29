///|
test "parse_glyphlist_line handles skipped cases" {
  assert_eq(parse_glyphlist_line(""), None)
  assert_eq(parse_glyphlist_line("NoSemicolonHere"), None)
  match parse_glyphlist_line("A; 0041  ZZZ 0042") {
    Some((name, codes)) => {
      assert_eq(name, "/A")
      assert_eq(codes, [0x41, 0x42])
    }
    None => fail("expected parsed glyphlist entry")
  }
}
