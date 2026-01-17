///|
test "pagelabeltext roman" {
  let labels = [
    {
      labelstyle: LabelStyle::LowercaseRoman,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
  ]
  let text = pagelabeltext_of_pagenumber(4, labels)
  assert_eq(text, "iv")
}

///|
test "pagelabel_of_pagenumber" {
  let labels = [
    {
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
  ]
  let label = pagelabel_of_pagenumber(5, labels)
  assert_eq(label.startpage, 5)
  assert_eq(label.startvalue, 5)
}

///|
test "coalesce labels" {
  let labels = [
    {
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
    {
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: None,
      startpage: 3,
      startvalue: 3,
    },
    {
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: Some("A"),
      startpage: 5,
      startvalue: 5,
    },
  ]
  let merged = coalesce(labels)
  assert_eq(merged.length(), 2)
  assert_eq(merged[0].startpage, 1)
  match merged[1].labelprefix {
    Some("A") => ()
    _ => fail("expected prefix A")
  }
}

///|
test "complete labels" {
  let labels = [
    {
      labelstyle: LabelStyle::DecimalArabic,
      labelprefix: None,
      startpage: 3,
      startvalue: 1,
    },
  ]
  let completed = complete(labels)
  assert_eq(completed.length(), 2)
  assert_eq(completed[0].startpage, 1)
}
