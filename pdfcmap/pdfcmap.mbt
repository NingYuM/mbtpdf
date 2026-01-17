///|
/// Parse /ToUnicode CMaps.

///|
pub struct CMap {
  map : Array[(Int, String)]
  wmode : Int?
}

///|
priv enum Section {
  BfChar(Array[Char])
  BfRange(Array[Char])
}

///|
fn is_whitespace(c : Char) -> Bool {
  let v = c.to_int()
  v == 0 || v == 9 || v == 10 || v == 12 || v == 13 || v == 32
}

///|
fn match_at(chars : Array[Char], index : Int, token : Array[Char]) -> Bool {
  if index + token.length() > chars.length() {
    return false
  }
  for i = 0; i < token.length(); i = i + 1 {
    if chars[index + i] != token[i] {
      return false
    }
  }
  true
}

///|
fn get_until(
  chars : Array[Char],
  start : Int,
  end_token : Array[Char],
) -> (Array[Char], Int) {
  let mut i = start
  while i + end_token.length() <= chars.length() {
    if match_at(chars, i, end_token) {
      return (chars[start:i].to_array(), i + end_token.length())
    }
    i = i + 1
  }
  (chars[start:].to_array(), chars.length())
}

///|
fn get_section(chars : Array[Char], start : Int) -> (Section, Int)? {
  let bfchar = "beginbfchar".to_array()
  let end_bfchar = "endbfchar".to_array()
  let bfrange = "beginbfrange".to_array()
  let end_bfrange = "endbfrange".to_array()
  let mut i = start
  while i < chars.length() {
    if match_at(chars, i, bfchar) {
      let (numbers, next) = get_until(chars, i + bfchar.length(), end_bfchar)
      return Some((Section::BfChar(numbers), next))
    }
    if match_at(chars, i, bfrange) {
      let (numbers, next) = get_until(chars, i + bfrange.length(), end_bfrange)
      return Some((Section::BfRange(numbers), next))
    }
    i = i + 1
  }
  None
}

///|
fn get_sections(chars : Array[Char]) -> Array[Section] {
  let sections = Array::new()
  let mut pos = 0
  while true {
    match get_section(chars, pos) {
      None => break
      Some((section, next)) => {
        sections.push(section)
        pos = next
      }
    }
  }
  sections
}

///|
fn skip_whitespace(chars : Array[Char], start : Int) -> Int {
  let mut i = start
  while i < chars.length() && is_whitespace(chars[i]) {
    i = i + 1
  }
  i
}

///|
fn read_number(chars : Array[Char], start : Int) -> (Int, Int) raise {
  let mut i = skip_whitespace(chars, start)
  if i >= chars.length() {
    fail("Not_found")
  }
  if chars[i] != '<' {
    raise @pdf.PdfError::Msg("Unknown number in /ToUnicode")
  }
  i = i + 1
  let hex_chars = Array::new()
  while i < chars.length() && chars[i] != '>' {
    hex_chars.push(chars[i])
    i = i + 1
  }
  if i >= chars.length() {
    raise @pdf.PdfError::Msg("Unknown number in /ToUnicode")
  }
  let hex_str = String::from_array(hex_chars)
  let value = @strconv.parse_int(hex_str, base=16)
  (value, i + 1)
}

///|
fn is_hex_digit(c : Char) -> Bool {
  c.is_ascii_hexdigit()
}

///|
fn read_unicode(chars : Array[Char], start : Int) -> (String, Int) raise {
  let mut i = skip_whitespace(chars, start)
  if i >= chars.length() || chars[i] != '<' {
    raise @pdf.PdfError::Msg("Bad unicode value")
  }
  i = i + 1
  let hex_chars = Array::new()
  while i < chars.length() && chars[i] != '>' {
    if !is_hex_digit(chars[i]) {
      raise @pdf.PdfError::Msg("Bad unicode value")
    }
    hex_chars.push(chars[i])
    i = i + 1
  }
  if i >= chars.length() {
    raise @pdf.PdfError::Msg("Bad unicode value")
  }
  if hex_chars.length() == 0 || hex_chars.length() % 2 != 0 {
    raise @pdf.PdfError::Msg("Bad unicode value")
  }
  let bytes = Array::new()
  let mut j = 0
  while j < hex_chars.length() {
    let hex_str = String::from_array(hex_chars[j:j + 2].to_array())
    let value = @strconv.parse_int(hex_str, base=16)
    bytes.push(value.to_byte())
    j = j + 2
  }
  (@pdfio.string_of_bytes(bytes), i + 1)
}

///|
fn read_number_opt(chars : Array[Char], start : Int) -> (Int, Int)? raise {
  Some(read_number(chars, start)) catch {
    Failure::Failure("Not_found") => None
    err => raise err
  }
}

///|
fn increment_final(code : String, delta : Int) -> String {
  if code.length() == 0 {
    return ""
  }
  let bytes = @pdfio.bytes_of_string(code)
  let last = bytes.length() - 1
  bytes[last] = (bytes[last].to_int() + delta).to_byte()
  @pdfio.string_of_bytes(bytes)
}

///|
fn pairs_of_section(section : Section) -> Array[(Int, String)] raise {
  match section {
    Section::BfChar(numbers) => {
      let results = Array::new()
      let mut pos = 0
      while true {
        match read_number_opt(numbers, pos) {
          None => break
          Some((number, rest)) => {
            let (str, rest2) = read_unicode(numbers, rest)
            results.push((number, str))
            pos = rest2
          }
        }
      }
      results
    }
    Section::BfRange(numbers) => {
      let results = Array::new()
      let mut pos = 0
      while true {
        match read_number_opt(numbers, pos) {
          None => break
          Some((src1, rest1)) => {
            let (src2, rest2) = read_number(numbers, rest1)
            if src1 > src2 {
              raise @pdf.PdfError::Msg("Bad /ToUnicode")
            }
            let mut rest = skip_whitespace(numbers, rest2)
            if rest >= numbers.length() {
              raise @pdf.PdfError::Msg("Bad BfRange")
            }
            match numbers[rest] {
              '<' => {
                let (code, rest3) = read_unicode(numbers, rest2)
                let mut d = 0
                while d <= src2 - src1 {
                  results.push((src1 + d, increment_final(code, d)))
                  d = d + 1
                }
                pos = rest3
              }
              '[' => {
                rest = rest + 1
                let mut d = 0
                while d <= src2 - src1 {
                  let (num, rest3) = read_unicode(numbers, rest)
                  results.push((src1 + d, num))
                  rest = rest3
                  d = d + 1
                }
                rest = skip_whitespace(numbers, rest)
                if rest < numbers.length() && numbers[rest] == ']' {
                  rest = rest + 1
                }
                pos = rest
              }
              _ => raise @pdf.PdfError::Msg("Bad BfRange")
            }
          }
        }
      }
      results
    }
  }
}

///|
fn extract_specifics(data : @pdfio.MutableBytes) -> Int? {
  let chars = @pdfio.charlist_of_bytes(data)
  let token = "/WMode ".to_array()
  let mut i = 0
  while i + token.length() <= chars.length() {
    if match_at(chars, i, token) {
      let mut j = i + token.length()
      let digits = Array::new()
      while j < chars.length() && chars[j].is_ascii_digit() {
        digits.push(chars[j])
        j = j + 1
      }
      if digits.length() > 0 {
        let parsed : Result[Int, Error] = try? @strconv.parse_int(
          String::from_array(digits),
          base=10,
        )
        match parsed {
          Ok(value) => return Some(value)
          Err(_) => return None
        }
      }
    }
    i = i + 1
  }
  None
}

///|
pub fn parse_cmap(pdf : @pdf.Pdf, cmap : @pdf.PdfObject) -> CMap raise {
  match cmap {
    @pdf.PdfObject::Stream(_) => {
      @pdfcodec.decode_pdfstream(pdf, cmap)
      match cmap {
        @pdf.PdfObject::Stream(r) => {
          let (dict, contents) = r.val
          match contents {
            @pdf.Stream::Got(data) => {
              let wmode = extract_specifics(data)
              let chars = @pdfio.charlist_of_bytes(data).filter(c => !is_whitespace(
                c,
              ))
              let sections = get_sections(chars)
              try {
                let pairs = Array::new()
                for section in sections {
                  pairs.append(pairs_of_section(section))
                }
                { map: pairs, wmode }
              } catch {
                err => {
                  @pdfe.log("/ToUnicode Parse Error\\n")
                  raise err
                }
              }
            }
            @pdf.Stream::ToGet(_) => {
              @pdf.getstream(cmap)
              parse_cmap(pdf, cmap)
            }
          }
        }
        _ => raise @pdf.PdfError::Msg("Bad /ToUnicode")
      }
    }
    _ =>
      raise @pdf.PdfError::Msg(
        "Bad /ToUnicode \{@pdfwrite.string_of_pdf(cmap)}",
      )
  }
}
