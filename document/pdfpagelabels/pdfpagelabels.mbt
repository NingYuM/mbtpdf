///|
/// Styles for page labels.
pub(all) enum LabelStyle {
  DecimalArabic
  UppercaseRoman
  LowercaseRoman
  UppercaseLetters
  LowercaseLetters
  NoLabelPrefixOnly
} derive(Debug)

///|
/// Page label definition.
pub(all) struct PageLabel {
  labelstyle : LabelStyle
  labelprefix : String?
  startpage : Int
  startvalue : Int
} derive(Debug)

///|
pub let basic_label : PageLabel = {
  labelstyle: LabelStyle::DecimalArabic,
  labelprefix: None,
  startpage: 1,
  startvalue: 1,
}

///|
/// String of label style, e.g. DecimalArabic.
pub fn LabelStyle::to_string(self : LabelStyle) -> String {
  match self {
    LabelStyle::DecimalArabic => "DecimalArabic"
    LabelStyle::UppercaseRoman => "UppercaseRoman"
    LabelStyle::LowercaseRoman => "LowercaseRoman"
    LabelStyle::UppercaseLetters => "UppercaseLetters"
    LabelStyle::LowercaseLetters => "LowercaseLetters"
    LabelStyle::NoLabelPrefixOnly => "NoLabelPrefixOnly"
  }
}

///|
/// Debug string of a page label.
pub fn PageLabel::to_string(self : PageLabel) -> String {
  let prefix = match self.labelprefix {
    None => "None"
    Some(s) => s
  }
  "labelstyle: \{self.labelstyle.to_string()}\n" +
  "labelprefix: \{prefix}\n" +
  "startpage: \{self.startpage}\n" +
  "startvalue: \{self.startvalue}"
}

///|
fn label_of_range(
  pdf : @pdf.Pdf,
  range : (@pdf.PdfObject, @pdf.PdfObject),
) -> PageLabel {
  let (startpage_obj, thing) = range
  let startpage = match startpage_obj {
    @pdf.PdfObject::Integer(i) => i + 1
    _ => {
      @pdfe.log("Bad Number Tree\n")
      1
    }
  }
  let labelstyle = match @pdf.lookup_direct(pdf, "/S", thing) {
    Some(@pdf.PdfObject::Name("/D")) => LabelStyle::DecimalArabic
    Some(@pdf.PdfObject::Name("/R")) => LabelStyle::UppercaseRoman
    Some(@pdf.PdfObject::Name("/r")) => LabelStyle::LowercaseRoman
    Some(@pdf.PdfObject::Name("/A")) => LabelStyle::UppercaseLetters
    Some(@pdf.PdfObject::Name("/a")) => LabelStyle::LowercaseLetters
    _ => LabelStyle::NoLabelPrefixOnly
  }
  let labelprefix = match @pdf.lookup_direct(pdf, "/P", thing) {
    Some(@pdf.PdfObject::String(s)) => Some(s)
    _ => None
  }
  let startvalue = match @pdf.lookup_direct(pdf, "/St", thing) {
    Some(@pdf.PdfObject::Integer(i)) => i
    _ => 1
  }
  { labelstyle, labelprefix, startpage, startvalue }
}

///|
/// Read page labels from a document.
pub fn read(pdf : @pdf.Pdf) -> Array[PageLabel] raise {
  match @pdf.lookup_direct(pdf, "/PageLabels", @pdf.lookup_obj(pdf, pdf.root)) {
    None => []
    Some(labeltree) => {
      let labelranges = @pdf.contents_of_nametree(pdf, labeltree)
      let out = Array::new(capacity=labelranges.length())
      for range in labelranges {
        out.push(label_of_range(pdf, range))
      }
      out
    }
  }
}

///|
/// Return a list where every page has a label.
pub fn complete(labels : Array[PageLabel]) -> Array[PageLabel] {
  if labels.length() == 0 {
    [basic_label]
  } else if labels[0].startpage > 1 {
    concat_arrays([basic_label], labels)
  } else {
    labels
  }
}

///|
fn letter_string(n : Int) -> String {
  if n <= 0 {
    return ""
  }
  let count = (n - 1) / 26 + 1
  let code = (n - 1) % 26 + 65
  let c = code.unsafe_to_char()
  let sb = StringBuilder::new()
  for _ in 0..<count {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
fn roman_upper(n : Int) -> String {
  if n <= 0 {
    return ""
  }
  let symbols : Array[(Int, String)] = [
    (1000, "M"),
    (900, "CM"),
    (500, "D"),
    (400, "CD"),
    (100, "C"),
    (90, "XC"),
    (50, "L"),
    (40, "XL"),
    (10, "X"),
    (9, "IX"),
    (5, "V"),
    (4, "IV"),
    (1, "I"),
  ]
  let sb = StringBuilder::new()
  let mut value = n
  for pair in symbols {
    let (num, token) = pair
    while value >= num {
      sb.write_string(token)
      value = value - num
    }
  }
  sb.to_string()
}

///|
fn string_of_pagenumber(n : Int, style : LabelStyle) -> String {
  match style {
    LabelStyle::NoLabelPrefixOnly => ""
    LabelStyle::DecimalArabic => n.to_string()
    LabelStyle::UppercaseRoman => roman_upper(n)
    LabelStyle::LowercaseRoman => roman_upper(n).to_lower()
    LabelStyle::UppercaseLetters => letter_string(n)
    LabelStyle::LowercaseLetters => letter_string(n).to_lower()
  }
}

///|
fn pagelabeltext_of_single(n : Int, label : PageLabel) -> String {
  let realnumber = n - (label.startpage - label.startvalue)
  let prefix = match label.labelprefix {
    None => ""
    Some(s) => s
  }
  prefix + string_of_pagenumber(realnumber, label.labelstyle)
}

///|
/// Return the text for a page label.
pub fn pagelabeltext_of_pagenumber(
  n : Int,
  labels : Array[PageLabel],
) -> String raise {
  let idx = label_index_for_page(n, labels)
  match idx {
    Some(i) => pagelabeltext_of_single(n, labels[i])
    None => fail("Not_found")
  }
}

///|
fn pagelabel_of_single(n : Int, label : PageLabel) -> PageLabel {
  let realnumber = n - (label.startpage - label.startvalue)
  {
    labelstyle: label.labelstyle,
    labelprefix: label.labelprefix,
    startpage: realnumber,
    startvalue: realnumber,
  }
}

///|
/// Single label representing a given page.
pub fn pagelabel_of_pagenumber(
  n : Int,
  labels : Array[PageLabel],
) -> PageLabel raise {
  let idx = label_index_for_page(n, labels)
  match idx {
    Some(i) => pagelabel_of_single(n, labels[i])
    None => fail("Not_found")
  }
}

///|
fn label_index_for_page(n : Int, labels : Array[PageLabel]) -> Int? {
  if labels.length() == 0 {
    return None
  }
  let mut i = 0
  while i < labels.length() {
    if i + 1 == labels.length() || n < labels[i + 1].startpage {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Add a range starting at label.startpage, ending at endpage.
pub fn add_label(
  endpage : Int,
  labels : Array[PageLabel],
  label : PageLabel,
  range_end : Int,
) -> Array[PageLabel] {
  let (before_or_equal, after) = partition(labels, x => x.startpage <= range_end)
  let before_or_during = filter(before_or_equal, x => x.startpage !=
    label.startpage)
  let replica = if range_end == endpage {
    []
  } else if after.length() > 0 && after[0].startpage == range_end + 1 {
    []
  } else if before_or_equal.length() == 0 {
    []
  } else {
    match last(before_or_equal) {
      Some(lst) =>
        [
          {
            labelstyle: lst.labelstyle,
            labelprefix: lst.labelprefix,
            startpage: range_end + 1,
            startvalue: range_end + 1 + (lst.startvalue - lst.startpage),
          },
        ]
      None => []
    }
  }
  let before = filter(before_or_during, x => !(x.startpage > label.startpage &&
    x.startpage <= range_end))
  concat_arrays(concat_arrays(concat_arrays(before, [label]), replica), after)
}

///|
fn labelstyle_eq(a : LabelStyle, b : LabelStyle) -> Bool {
  match (a, b) {
    (LabelStyle::DecimalArabic, LabelStyle::DecimalArabic) => true
    (LabelStyle::UppercaseRoman, LabelStyle::UppercaseRoman) => true
    (LabelStyle::LowercaseRoman, LabelStyle::LowercaseRoman) => true
    (LabelStyle::UppercaseLetters, LabelStyle::UppercaseLetters) => true
    (LabelStyle::LowercaseLetters, LabelStyle::LowercaseLetters) => true
    (LabelStyle::NoLabelPrefixOnly, LabelStyle::NoLabelPrefixOnly) => true
    _ => false
  }
}

///|
fn option_string_eq(a : String?, b : String?) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(sa), Some(sb)) => sa == sb
    _ => false
  }
}

///|
/// Optimise page labels, removing any which are not required.
pub fn coalesce(labels : Array[PageLabel]) -> Array[PageLabel] {
  if labels.length() <= 1 {
    return labels
  }
  let out = Array::new()
  out.push(labels[0])
  for i in 1..<labels.length() {
    let current = labels[i]
    let prev = out[out.length() - 1]
    let same = labelstyle_eq(prev.labelstyle, current.labelstyle) &&
      option_string_eq(prev.labelprefix, current.labelprefix) &&
      current.startpage - current.startvalue == prev.startpage - prev.startvalue
    if !same {
      out.push(current)
    }
  }
  out
}

///|
/// Merge page labels for a set of PDFs and page ranges.
pub fn merge_pagelabels(
  pdfs : Array[@pdf.Pdf],
  ranges : Array[Array[Int]],
) -> Array[PageLabel] raise {
  let completed = Array::new(capacity=pdfs.length())
  for pdf in pdfs {
    completed.push(complete(read(pdf)))
  }
  let new_labels = Array::new(capacity=completed.length())
  for i in 0..<completed.length() {
    let labels = completed[i]
    let range = ranges[i]
    let mapped = Array::new(capacity=range.length())
    for page in range {
      mapped.push(pagelabel_of_pagenumber(page, labels))
    }
    new_labels.push(mapped)
  }
  let flattened_labels = flatten(new_labels)
  let flat_ranges = flatten(ranges)
  let indices = indices_for_length(flat_ranges.length())
  let changed = map2(flattened_labels, indices, (label, sp) => {
    labelstyle: label.labelstyle,
    labelprefix: label.labelprefix,
    startpage: sp,
    startvalue: label.startvalue,
  })
  coalesce(changed)
}

///|
/// Write page labels to a document, replacing any there.
pub fn write(pdf : @pdf.Pdf, labels : Array[PageLabel]) -> Unit raise {
  if labels.length() == 0 {
    remove(pdf)
  } else {
    let arr = Array::new()
    for label in labels {
      let entries = Array::new()
      match label.labelstyle {
        LabelStyle::NoLabelPrefixOnly => ()
        LabelStyle::DecimalArabic =>
          entries.push(("/S", @pdf.PdfObject::Name("/D")))
        LabelStyle::UppercaseRoman =>
          entries.push(("/S", @pdf.PdfObject::Name("/R")))
        LabelStyle::LowercaseRoman =>
          entries.push(("/S", @pdf.PdfObject::Name("/r")))
        LabelStyle::UppercaseLetters =>
          entries.push(("/S", @pdf.PdfObject::Name("/A")))
        LabelStyle::LowercaseLetters =>
          entries.push(("/S", @pdf.PdfObject::Name("/a")))
      }
      match label.labelprefix {
        Some(p) => entries.push(("/P", @pdf.PdfObject::String(p)))
        None => ()
      }
      if label.startvalue != 1 {
        entries.push(("/St", @pdf.PdfObject::Integer(label.startvalue)))
      }
      arr.push(@pdf.PdfObject::Integer(label.startpage - 1))
      arr.push(@pdf.PdfObject::Dictionary(entries))
    }
    let rootnum = pdf.root
    let root = @pdf.lookup_obj(pdf, rootnum)
    let updated_root = root.add_entry(
      "/PageLabels",
      @pdf.PdfObject::Dictionary([("/Nums", @pdf.PdfObject::Array(arr))]),
    )
    @pdf.addobj_given_num(pdf, (rootnum, updated_root))
    pdf.trailerdict = pdf.trailerdict.add_entry(
      "/Root",
      @pdf.PdfObject::Indirect(rootnum),
    )
  }
}

///|
/// Remove all page labels.
pub fn remove(pdf : @pdf.Pdf) -> Unit raise {
  let rootnum = pdf.root
  let root = @pdf.lookup_obj(pdf, rootnum)
  let updated_root = root.remove_entry("/PageLabels")
  @pdf.addobj_given_num(pdf, (rootnum, updated_root))
  pdf.trailerdict = pdf.trailerdict.add_entry(
    "/Root",
    @pdf.PdfObject::Indirect(rootnum),
  )
}

///|
fn[T] concat_arrays(a : Array[T], b : Array[T]) -> Array[T] {
  let out = Array::new(capacity=a.length() + b.length())
  for item in a {
    out.push(item)
  }
  for item in b {
    out.push(item)
  }
  out
}

///|
fn[T] filter(items : Array[T], pred : (T) -> Bool) -> Array[T] {
  let out = Array::new()
  for item in items {
    if pred(item) {
      out.push(item)
    }
  }
  out
}

///|
fn[T] partition(items : Array[T], pred : (T) -> Bool) -> (Array[T], Array[T]) {
  let yes = Array::new()
  let no = Array::new()
  for item in items {
    if pred(item) {
      yes.push(item)
    } else {
      no.push(item)
    }
  }
  (yes, no)
}

///|
fn[T] last(items : Array[T]) -> T? {
  if items.length() == 0 {
    None
  } else {
    Some(items[items.length() - 1])
  }
}

///|
fn[T] flatten(lists : Array[Array[T]]) -> Array[T] {
  let out = Array::new()
  for list in lists {
    for item in list {
      out.push(item)
    }
  }
  out
}

///|
fn indices_for_length(length : Int) -> Array[Int] {
  let out = Array::new(capacity=length)
  for i in 1..<=length {
    out.push(i)
  }
  out
}

///|
fn[A, B, C] map2(
  left : Array[A],
  right : Array[B],
  f : (A, B) -> C,
) -> Array[C] raise {
  if left.length() != right.length() {
    fail("map2: length mismatch")
  }
  let out = Array::new(capacity=left.length())
  for i in 0..<left.length() {
    out.push(f(left[i], right[i]))
  }
  out
}
