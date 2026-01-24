///|
/// Parsing PDF graphics content stream operators.
///
pub(all) enum Op {
  Opw(Double)
  OpJ(Int)
  Opj(Int)
  OpM(Double)
  Opd(Array[Double], Double)
  Opri(String)
  Opi(Int)
  Opgs(String)
  Opq
  OpQ
  Opcm(@pdftransform.TransformMatrix)
  Opm(Double, Double)
  Opl(Double, Double)
  Opc(Double, Double, Double, Double, Double, Double)
  Opv(Double, Double, Double, Double)
  Opy(Double, Double, Double, Double)
  Oph
  Opre(Double, Double, Double, Double)
  OpS
  Ops
  Opf
  OpF
  OpfStar
  OpB
  OpBStar
  Opb
  OpbStar
  Opn
  OpW
  OpWStar
  OpBT
  OpET
  OpTc(Double)
  OpTw(Double)
  OpTz(Double)
  OpTL(Double)
  OpTf(String, Double)
  OpTr(Int)
  OpTs(Double)
  OpTd(Double, Double)
  OpTD(Double, Double)
  OpTm(@pdftransform.TransformMatrix)
  OpTStar
  OpTj(String)
  OpTJ(@pdf.PdfObject)
  OpSingleQuote(String)
  OpDoubleQuote(Double, Double, String)
  Opd0(Double, Double)
  Opd1(Double, Double, Double, Double, Double, Double)
  OpCS(String)
  Opcs(String)
  OpSC(Array[Double])
  Opsc(Array[Double])
  OpSCN(Array[Double])
  Opscn(Array[Double])
  OpSCNName(String, Array[Double])
  OpscnName(String, Array[Double])
  OpG(Double)
  Opg(Double)
  OpRG(Double, Double, Double)
  Oprg(Double, Double, Double)
  OpK(Double, Double, Double, Double)
  Opk(Double, Double, Double, Double)
  Opsh(String)
  InlineImage((@pdf.PdfObject, @pdf.PdfObject?, @pdfio.MutableBytes))
  OpDo(String)
  OpMP(String)
  OpDP(String, @pdf.PdfObject)
  OpBMC(String)
  OpBDC(String, @pdf.PdfObject)
  OpEMC
  OpBX
  OpEX
  OpUnknown(String)
  OpComment(String)
}

///|
priv enum Lexeme {
  Op(String)
  Obj(@pdfgenlex.Token)
  PdfObj(@pdf.PdfObject)
  LexInlineImage((@pdf.PdfObject, @pdf.PdfObject?, @pdfio.MutableBytes))
  LexComment
}

///|
priv suberror LexingEnd

///|
priv suberror CouldntHandleContent

///|
let debug : Ref[Bool] = { val: false }

///|
let write_comments : Ref[Bool] = { val: false }

///|
let whitespace : Ref[String] = { val: " " }

///|
let always_add_whitespace : Ref[Bool] = { val: false }

///|
pub let begin_artifact : Op = Op::OpBMC("/Artifact")

///|
pub let end_artifact : Op = Op::OpEMC

///|
fn lexemes_of_op(op : Op) -> Array[Lexeme] {
  let out : Array[Lexeme] = Array::new()
  fn push(lexeme : Lexeme) -> Unit {
    out.push(lexeme)
  }

  match op {
    Op::Opw(w) => {
      push(Obj(@pdfgenlex.Token::LexReal(w)))
      push(Op("w"))
    }
    Op::OpJ(j) => {
      push(Obj(@pdfgenlex.Token::LexInt(j)))
      push(Op("J"))
    }
    Op::Opj(j) => {
      push(Obj(@pdfgenlex.Token::LexInt(j)))
      push(Op("j"))
    }
    Op::OpM(m) => {
      push(Obj(@pdfgenlex.Token::LexReal(m)))
      push(Op("M"))
    }
    Op::Opd(values, phase) => {
      push(Obj(@pdfgenlex.Token::LexLeftSquare))
      for value in values {
        push(Obj(@pdfgenlex.Token::LexReal(value)))
      }
      push(Obj(@pdfgenlex.Token::LexRightSquare))
      push(Obj(@pdfgenlex.Token::LexReal(phase)))
      push(Op("d"))
    }
    Op::Opri(name) => {
      push(Obj(@pdfgenlex.Token::LexName(name)))
      push(Op("ri"))
    }
    Op::Opi(value) => {
      push(Obj(@pdfgenlex.Token::LexInt(value)))
      push(Op("i"))
    }
    Op::Opgs(name) => {
      push(Obj(@pdfgenlex.Token::LexName(name)))
      push(Op("gs"))
    }
    Op::Opq => push(Op("q"))
    Op::OpQ => push(Op("Q"))
    Op::Opcm(t) => {
      push(Obj(@pdfgenlex.Token::LexReal(t.a)))
      push(Obj(@pdfgenlex.Token::LexReal(t.b)))
      push(Obj(@pdfgenlex.Token::LexReal(t.c)))
      push(Obj(@pdfgenlex.Token::LexReal(t.d)))
      push(Obj(@pdfgenlex.Token::LexReal(t.e)))
      push(Obj(@pdfgenlex.Token::LexReal(t.f)))
      push(Op("cm"))
    }
    Op::Opm(x, y) => {
      push(Obj(@pdfgenlex.Token::LexReal(x)))
      push(Obj(@pdfgenlex.Token::LexReal(y)))
      push(Op("m"))
    }
    Op::Opl(x, y) => {
      push(Obj(@pdfgenlex.Token::LexReal(x)))
      push(Obj(@pdfgenlex.Token::LexReal(y)))
      push(Op("l"))
    }
    Op::Opc(x1, y1, x2, y2, x3, y3) => {
      push(Obj(@pdfgenlex.Token::LexReal(x1)))
      push(Obj(@pdfgenlex.Token::LexReal(y1)))
      push(Obj(@pdfgenlex.Token::LexReal(x2)))
      push(Obj(@pdfgenlex.Token::LexReal(y2)))
      push(Obj(@pdfgenlex.Token::LexReal(x3)))
      push(Obj(@pdfgenlex.Token::LexReal(y3)))
      push(Op("c"))
    }
    Op::Opv(x2, y2, x3, y3) => {
      push(Obj(@pdfgenlex.Token::LexReal(x2)))
      push(Obj(@pdfgenlex.Token::LexReal(y2)))
      push(Obj(@pdfgenlex.Token::LexReal(x3)))
      push(Obj(@pdfgenlex.Token::LexReal(y3)))
      push(Op("v"))
    }
    Op::Opy(x1, y1, x3, y3) => {
      push(Obj(@pdfgenlex.Token::LexReal(x1)))
      push(Obj(@pdfgenlex.Token::LexReal(y1)))
      push(Obj(@pdfgenlex.Token::LexReal(x3)))
      push(Obj(@pdfgenlex.Token::LexReal(y3)))
      push(Op("y"))
    }
    Op::Oph => push(Op("h"))
    Op::Opre(x, y, w, h) => {
      push(Obj(@pdfgenlex.Token::LexReal(x)))
      push(Obj(@pdfgenlex.Token::LexReal(y)))
      push(Obj(@pdfgenlex.Token::LexReal(w)))
      push(Obj(@pdfgenlex.Token::LexReal(h)))
      push(Op("re"))
    }
    Op::OpS => push(Op("S"))
    Op::Ops => push(Op("s"))
    Op::Opf => push(Op("f"))
    Op::OpF => push(Op("F"))
    Op::OpfStar => push(Op("f*"))
    Op::OpB => push(Op("B"))
    Op::OpBStar => push(Op("B*"))
    Op::Opb => push(Op("b"))
    Op::OpbStar => push(Op("b*"))
    Op::Opn => push(Op("n"))
    Op::OpW => push(Op("W"))
    Op::OpWStar => push(Op("W*"))
    Op::OpBT => push(Op("BT"))
    Op::OpET => push(Op("ET"))
    Op::OpTc(value) => {
      push(Obj(@pdfgenlex.Token::LexReal(value)))
      push(Op("Tc"))
    }
    Op::OpTw(value) => {
      push(Obj(@pdfgenlex.Token::LexReal(value)))
      push(Op("Tw"))
    }
    Op::OpTz(value) => {
      push(Obj(@pdfgenlex.Token::LexReal(value)))
      push(Op("Tz"))
    }
    Op::OpTL(value) => {
      push(Obj(@pdfgenlex.Token::LexReal(value)))
      push(Op("TL"))
    }
    Op::OpTf(name, size) => {
      push(Obj(@pdfgenlex.Token::LexName(name)))
      push(Obj(@pdfgenlex.Token::LexReal(size)))
      push(Op("Tf"))
    }
    Op::OpTr(value) => {
      push(Obj(@pdfgenlex.Token::LexInt(value)))
      push(Op("Tr"))
    }
    Op::OpTs(value) => {
      push(Obj(@pdfgenlex.Token::LexReal(value)))
      push(Op("Ts"))
    }
    Op::OpTd(tx, ty) => {
      push(Obj(@pdfgenlex.Token::LexReal(tx)))
      push(Obj(@pdfgenlex.Token::LexReal(ty)))
      push(Op("Td"))
    }
    Op::OpTD(tx, ty) => {
      push(Obj(@pdfgenlex.Token::LexReal(tx)))
      push(Obj(@pdfgenlex.Token::LexReal(ty)))
      push(Op("TD"))
    }
    Op::OpTm(t) => {
      push(Obj(@pdfgenlex.Token::LexReal(t.a)))
      push(Obj(@pdfgenlex.Token::LexReal(t.b)))
      push(Obj(@pdfgenlex.Token::LexReal(t.c)))
      push(Obj(@pdfgenlex.Token::LexReal(t.d)))
      push(Obj(@pdfgenlex.Token::LexReal(t.e)))
      push(Obj(@pdfgenlex.Token::LexReal(t.f)))
      push(Op("Tm"))
    }
    Op::OpTStar => push(Op("T*"))
    Op::OpTj(text) => {
      push(Obj(@pdfgenlex.Token::LexString(text)))
      push(Op("Tj"))
    }
    Op::OpTJ(obj) => {
      push(Lexeme::PdfObj(obj))
      push(Op("TJ"))
    }
    Op::OpSingleQuote(text) => {
      push(Obj(@pdfgenlex.Token::LexString(text)))
      push(Op("'"))
    }
    Op::OpDoubleQuote(word, char, text) => {
      push(Obj(@pdfgenlex.Token::LexReal(word)))
      push(Obj(@pdfgenlex.Token::LexReal(char)))
      push(Obj(@pdfgenlex.Token::LexString(text)))
      push(Op("\""))
    }
    Op::Opd0(wx, wy) => {
      push(Obj(@pdfgenlex.Token::LexReal(wx)))
      push(Obj(@pdfgenlex.Token::LexReal(wy)))
      push(Op("d0"))
    }
    Op::Opd1(wx, wy, llx, lly, urx, ury) => {
      push(Obj(@pdfgenlex.Token::LexReal(wx)))
      push(Obj(@pdfgenlex.Token::LexReal(wy)))
      push(Obj(@pdfgenlex.Token::LexReal(llx)))
      push(Obj(@pdfgenlex.Token::LexReal(lly)))
      push(Obj(@pdfgenlex.Token::LexReal(urx)))
      push(Obj(@pdfgenlex.Token::LexReal(ury)))
      push(Op("d1"))
    }
    Op::OpCS(name) => {
      push(Obj(@pdfgenlex.Token::LexName(name)))
      push(Op("CS"))
    }
    Op::Opcs(name) => {
      push(Obj(@pdfgenlex.Token::LexName(name)))
      push(Op("cs"))
    }
    Op::OpSC(values) => {
      for value in values {
        push(Obj(@pdfgenlex.Token::LexReal(value)))
      }
      push(Op("SC"))
    }
    Op::Opsc(values) => {
      for value in values {
        push(Obj(@pdfgenlex.Token::LexReal(value)))
      }
      push(Op("sc"))
    }
    Op::OpSCN(values) => {
      for value in values {
        push(Obj(@pdfgenlex.Token::LexReal(value)))
      }
      push(Op("SCN"))
    }
    Op::Opscn(values) => {
      for value in values {
        push(Obj(@pdfgenlex.Token::LexReal(value)))
      }
      push(Op("scn"))
    }
    Op::OpSCNName(name, values) => {
      for value in values {
        push(Obj(@pdfgenlex.Token::LexReal(value)))
      }
      push(Obj(@pdfgenlex.Token::LexName(name)))
      push(Op("SCN"))
    }
    Op::OpscnName(name, values) => {
      for value in values {
        push(Obj(@pdfgenlex.Token::LexReal(value)))
      }
      push(Obj(@pdfgenlex.Token::LexName(name)))
      push(Op("scn"))
    }
    Op::OpG(value) => {
      push(Obj(@pdfgenlex.Token::LexReal(value)))
      push(Op("G"))
    }
    Op::Opg(value) => {
      push(Obj(@pdfgenlex.Token::LexReal(value)))
      push(Op("g"))
    }
    Op::OpRG(r, g, b) => {
      push(Obj(@pdfgenlex.Token::LexReal(r)))
      push(Obj(@pdfgenlex.Token::LexReal(g)))
      push(Obj(@pdfgenlex.Token::LexReal(b)))
      push(Op("RG"))
    }
    Op::Oprg(r, g, b) => {
      push(Obj(@pdfgenlex.Token::LexReal(r)))
      push(Obj(@pdfgenlex.Token::LexReal(g)))
      push(Obj(@pdfgenlex.Token::LexReal(b)))
      push(Op("rg"))
    }
    Op::OpK(c, m, y, k) => {
      push(Obj(@pdfgenlex.Token::LexReal(c)))
      push(Obj(@pdfgenlex.Token::LexReal(m)))
      push(Obj(@pdfgenlex.Token::LexReal(y)))
      push(Obj(@pdfgenlex.Token::LexReal(k)))
      push(Op("K"))
    }
    Op::Opk(c, m, y, k) => {
      push(Obj(@pdfgenlex.Token::LexReal(c)))
      push(Obj(@pdfgenlex.Token::LexReal(m)))
      push(Obj(@pdfgenlex.Token::LexReal(y)))
      push(Obj(@pdfgenlex.Token::LexReal(k)))
      push(Op("k"))
    }
    Op::Opsh(name) => {
      push(Obj(@pdfgenlex.Token::LexName(name)))
      push(Op("sh"))
    }
    Op::InlineImage(data) => push(Lexeme::LexInlineImage(data))
    Op::OpDo(name) => {
      push(Obj(@pdfgenlex.Token::LexName(name)))
      push(Op("Do"))
    }
    Op::OpMP(name) => {
      push(Obj(@pdfgenlex.Token::LexName(name)))
      push(Op("MP"))
    }
    Op::OpDP(name, obj) => {
      push(Obj(@pdfgenlex.Token::LexName(name)))
      push(Lexeme::PdfObj(obj))
      push(Op("DP"))
    }
    Op::OpBMC(name) => {
      push(Obj(@pdfgenlex.Token::LexName(name)))
      push(Op("BMC"))
    }
    Op::OpBDC(name, obj) => {
      push(Obj(@pdfgenlex.Token::LexName(name)))
      push(Lexeme::PdfObj(obj))
      push(Op("BDC"))
    }
    Op::OpEMC => push(Op("EMC"))
    Op::OpBX => push(Op("BX"))
    Op::OpEX => push(Op("EX"))
    Op::OpUnknown(_) => ()
    Op::OpComment(text) =>
      if write_comments.val {
        push(Obj(@pdfgenlex.Token::LexComment(text)))
      } else {
        ()
      }
  }
  out
}

///|
fn lexemes_of_ops(ops : Array[Op]) -> Array[Lexeme] {
  let out : Array[Lexeme] = Array::new()
  for op in ops {
    let lexemes = lexemes_of_op(op)
    for lexeme in lexemes {
      out.push(lexeme)
    }
  }
  out
}

///|
fn lexemelists_of_ops(ops : Array[Op]) -> Array[Array[Lexeme]] {
  let out : Array[Array[Lexeme]] = Array::new(capacity=ops.length())
  for op in ops {
    out.push(lexemes_of_op(op))
  }
  out
}

///|
fn filterspecial(filters : Array[@pdf.PdfObject]) -> Bool {
  for filter in filters {
    match filter {
      @pdf.PdfObject::Name(
        "/ASCIIHexDecode"
        | "/ASCII85Decode"
        | "/AHx"
        | "/A85"
      ) => return true
      _ => ()
    }
  }
  false
}

///|
fn is_delimiter_char(chr : Char) -> Bool {
  match chr {
    '(' | ')' | '<' | '>' | '[' | ']' | '{' | '}' | '/' | '%' => true
    _ => false
  }
}

///|
fn is_inline_image_whitespace(chr : Char) -> Bool {
  let v = chr.to_int()
  v == 0 || v == 9 || v == 10 || v == 12 || v == 13 || v == 32
}

///|
fn is_inline_image_delimiter(chr : Char) -> Bool {
  is_inline_image_whitespace(chr) || is_delimiter_char(chr)
}

///|
fn inline_image_end_ahead(input : @pdfio.Input) -> Bool {
  let pos = (input.pos_in)()
  let b1 = (input.input_byte)()
  let b2 = (input.input_byte)()
  let b3 = (input.input_byte)()
  (input.seek_in)(pos)
  if b1 == @pdfio.no_more || b2 == @pdfio.no_more {
    return false
  }
  if b1 != 'E'.to_int() || b2 != 'I'.to_int() {
    return false
  }
  if b3 == @pdfio.no_more {
    return true
  }
  match b3.to_char() {
    Some(ch) => is_inline_image_delimiter(ch)
    None => false
  }
}

///|
fn read_inline_image_encoded_data(
  input : @pdfio.Input,
) -> @pdfio.MutableBytes raise {
  let (output, data) = @pdfio.input_output_of_bytes(4096)
  let mut done = false
  while !done {
    let pos = (input.pos_in)()
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      raise @pdf.PdfError::Msg(
        "Could not read inline image data - end of stream",
      )
    }
    match b.to_char() {
      Some(ch) if is_inline_image_whitespace(ch) =>
        if inline_image_end_ahead(input) {
          (input.seek_in)(pos)
          done = true
        } else {
          (output.output_byte)(b)
        }
      _ => (output.output_byte)(b)
    }
  }
  @pdfio.extract_bytes_from_input_output(output, data)
}

///|
fn string_first_char(value : String) -> Char? {
  value.get_char(0)
}

///|
fn string_last_char(value : String) -> Char? {
  let length = value.length()
  if length <= 0 {
    None
  } else {
    value.get_char(length - 1)
  }
}

///|
fn strip_dict_markers(value : String) -> String {
  if value.length() < 4 {
    value
  } else {
    try value[2:value.length() - 2] catch {
      _ => value
    } noraise {
      view => view.to_string()
    }
  }
}

///|
fn string_of_lexeme(lexeme : Lexeme) -> String raise {
  match lexeme {
    Lexeme::LexComment => ""
    Lexeme::Obj(token) => @pdfsyntax.string_of_lexeme(token)
    Lexeme::Op(op) => op
    Lexeme::PdfObj(obj) => @pdf.string_of_pdfobj(obj)
    Lexeme::LexInlineImage((dict, dp, data)) => {
      let dict_data = match
        @pdf.lookup_direct_orelse(@pdf.empty(), "/F", "/Filter", dict) {
        None | Some(@pdf.PdfObject::Array([])) => {
          let _ = dp
          let dict = @pdf.add_dict_entry(
            dict,
            "/F",
            @pdf.PdfObject::Name("/Fl"),
          )
          let encoded = @pdfcodec.encode_flate(data)
          (dict, encoded)
        }
        _ => (dict, data)
      }
      let dict = dict_data.0
      let data = dict_data.1
      let dict = @pdf.add_dict_entry(
        dict,
        "/L",
        @pdf.PdfObject::Integer(@pdfio.bytes_size(data)),
      )
      let dict_string = @pdf.string_of_pdfobj(dict)
      let dict_body = strip_dict_markers(dict_string)
      let filters = match
        @pdf.lookup_direct_orelse(@pdf.empty(), "/F", "/Filter", dict) {
        Some(@pdf.PdfObject::Array(items)) => items
        Some(@pdf.PdfObject::Name(name)) => [@pdf.PdfObject::Name(name)]
        _ => []
      }
      let space = if filterspecial(filters) { "" } else { " " }
      let sb = StringBuilder::new()
      sb.write_string("BI\n")
      sb.write_string(dict_body)
      sb.write_string(" ID")
      sb.write_string(space)
      sb.write_string(@pdfio.string_of_bytes(data))
      sb.write_string("\nEI\n")
      sb.to_string()
    }
  }
}

///|
fn string_of_lexemes(lexemes : Array[Lexeme]) -> String raise {
  let sb = StringBuilder::new()
  let mut last_char : Char? = None
  for lexeme in lexemes {
    let text = string_of_lexeme(lexeme)
    if text.length() > 0 {
      let first = string_first_char(text)
      if last_char is Some(prev) && first is Some(curr) {
        if !is_delimiter_char(prev) && !is_delimiter_char(curr) {
          sb.write_char(' ')
        }
      }
      sb.write_string(text)
      last_char = string_last_char(text)
    }
  }
  sb.to_string()
}

///|
/// Make a string of several operators (debug only).
pub fn string_of_ops(ops : Array[Op]) -> String raise {
  string_of_lexemes(lexemes_of_ops(ops))
}

///|
/// Make a string of a single operator (debug only).
pub fn string_of_op(op : Op) -> String raise {
  string_of_ops([op])
}

///|
/// Concatenate byte streams with whitespace between them.
pub fn concat_bytess(ss : Array[@pdfio.MutableBytes]) -> @pdfio.MutableBytes {
  let mut total = 0
  for bytes in ss {
    total = total + @pdfio.bytes_size(bytes)
  }
  let out = @pdfio.mkbytes(total + ss.length())
  let mut pos = 0
  for bytes in ss {
    let len = @pdfio.bytes_size(bytes)
    for i in 0..<len {
      @pdfio.bset_unsafe(out, pos, @pdfio.bget_unsafe(bytes, i))
      pos = pos + 1
    }
    @pdfio.bset_unsafe(out, pos, ' '.to_int())
    pos = pos + 1
  }
  out
}

///|
fn stream_of_lexemes(
  oplists : Array[Array[Lexeme]],
) -> @pdfio.MutableBytes raise {
  let sb = StringBuilder::new()
  let mut prev : String = ""
  for oplist in oplists {
    let text = string_of_lexemes(oplist)
    if !sb.is_empty() {
      let prev_len = prev.length()
      let curr_len = text.length()
      let mut insert = true
      if !always_add_whitespace.val {
        let prev_delim = if prev_len > 0 {
          match string_last_char(prev) {
            Some(chr) => is_delimiter_char(chr)
            None => false
          }
        } else {
          false
        }
        let curr_delim = if curr_len > 0 {
          match string_first_char(text) {
            Some(chr) => is_delimiter_char(chr)
            None => false
          }
        } else {
          false
        }
        if prev_delim || curr_delim {
          insert = false
        }
      }
      if insert {
        sb.write_string(whitespace.val)
      }
    }
    sb.write_string(text)
    prev = text
  }
  @pdfio.bytes_of_string(sb.to_string())
}

///|
/// Flatten a list of operators to an uncompressed PDF stream.
pub fn stream_of_ops(ops : Array[Op]) -> @pdf.PdfObject raise {
  let data = stream_of_lexemes(lexemelists_of_ops(ops))
  @pdf.PdfObject::Stream(
    Ref::new(
      (
        @pdf.PdfObject::Dictionary([
          ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(data))),
        ]),
        @pdf.Stream::Got(data),
      ),
    ),
  )
}

///|

///|
fn lex_name(input : @pdfio.Input) -> Lexeme raise {
  @pdfio.nudge(input)
  Lexeme::Obj(
    @pdfgenlex.Token::LexName(
      "/" + @pdfsyntax.getuntil_white_or_delimiter_string(input),
    ),
  )
}

///|
fn nocontent(input : @pdfio.Input) -> Unit raise {
  @pdfe.log("Failed to understand content on page\n")
  if @pdfe.read_debug.val {
    @pdfio.debug_next_n_chars(20, input)
  }
  raise CouldntHandleContent
}

///|
fn lex_number(input : @pdfio.Input) -> Lexeme raise {
  match (@pdfsyntax.lex_number(input) : @pdfgenlex.Token) {
    LexReal(value) => Obj(@pdfgenlex.Token::LexReal(value))
    LexInt(value) => Obj(@pdfgenlex.Token::LexReal(Double::from_int(value)))
    _ => {
      nocontent(input)
      Obj(@pdfgenlex.Token::LexReal(0.0))
    }
  }
}

///|
fn get_dictionary(input : @pdfio.Input) -> Lexeme raise {
  Lexeme::PdfObj(@pdfsyntax.parse(@pdfsyntax.lex_dictionary(false, input)).1)
}

///|
/// Given a colourspace and bits per component, return bytes per pixel.
pub fn components(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  space : @pdf.PdfObject,
) -> Int raise {
  match space {
    @pdf.PdfObject::Name(name) => {
      if name == "/CalGray" || name == "/DeviceGray" || name == "/G" {
        return 1
      }
      if name == "/CalRGB" || name == "/DeviceRGB" || name == "/RGB" {
        return 3
      }
      if name == "/CalCMYK" || name == "/DeviceCMYK" || name == "/CMYK" {
        return 4
      }
      if name == "/Pattern" {
        raise @pdf.PdfError::Msg("Can't use /Pattern here")
      }
      match @pdf.lookup_direct(pdf, "/ColorSpace", resources) {
        Some(csdict) =>
          match @pdf.lookup_direct(pdf, name, csdict) {
            Some(space_next) => components(pdf, resources, space_next)
            None => raise @pdf.PdfError::Msg("ColorSpace not found")
          }
        None => raise @pdf.PdfError::Msg("ColorSpace dict not found")
      }
    }
    @pdf.PdfObject::Array(items) => {
      if items.length() >= 2 {
        match items[0] {
          @pdf.PdfObject::Name(name) =>
            match name {
              "/Lab" => if items.length() == 2 { return 3 }
              "/ICCBased" =>
                if items.length() == 2 {
                  let iccstream = items[1]
                  match @pdf.lookup_direct(pdf, "/N", iccstream) {
                    Some(@pdf.PdfObject::Integer(n)) => return n
                    _ => raise @pdf.PdfError::Msg("Bad iccstream")
                  }
                }
              "/DeviceN" =>
                match items[1] {
                  @pdf.PdfObject::Array(names) => return names.length()
                  _ => ()
                }
              "/Separation" => if items.length() == 4 { return 1 }
              "/Indexed" => return 1
              "/I" => return 1
              "/CalRGB" => if items.length() == 2 { return 3 }
              "/CalCMYK" => if items.length() == 2 { return 4 }
              "/CalGray" => if items.length() == 2 { return 1 }
              "/Pattern" =>
                if items.length() == 2 {
                  return components(pdf, resources, @pdf.direct(pdf, items[1]))
                }
              _ => ()
            }
          _ => ()
        }
      }
      @pdfe.log("\{@pdf.string_of_pdfobj(space)}\n")
      raise @pdf.PdfError::Msg("Unknown colourspace")
    }
    other => {
      @pdfe.log("\{@pdf.string_of_pdfobj(other)}\n")
      raise @pdf.PdfError::Msg("Unknown colourspace")
    }
  }
}

///|
fn get_jpeg_data(input : @pdfio.Input) -> @pdfio.MutableBytes raise {
  let (output, data) = @pdfio.input_output_of_bytes(4096)
  let mut finished = false
  let mut last = 0
  while !finished {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      raise @pdf.PdfError::Msg("Could not read JPEG data - end of stream")
    }
    if b == 0xD9 {
      if last == 0xFF {
        finished = true
      } else {
        last = 0xD9
      }
      (output.output_byte)(0xD9)
    } else {
      last = b
      (output.output_byte)(b)
    }
  }
  @pdfio.extract_bytes_from_input_output(output, data)
}

///|
fn lex_inline_image(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  input : @pdfio.Input,
) -> (@pdf.PdfObject, @pdf.PdfObject?, @pdfio.MutableBytes) raise {
  if debug.val {
    @pdfe.log("lex_inline_image at \{(input.pos_in)()}\n")
  }
  try {
    let lexemes = @pdfsyntax.lex_dictionary(true, input)
    let tokens : Array[@pdfgenlex.Token] = Array::new(
      capacity=lexemes.length() + 2,
    )
    tokens.push(@pdfgenlex.Token::LexLeftDict)
    for token in lexemes {
      match token {
        @pdfgenlex.Token::StopLexing => ()
        _ => tokens.push(token)
      }
    }
    tokens.push(@pdfgenlex.Token::LexRightDict)
    let dict = @pdfsyntax.parse(tokens).1
    if debug.val {
      @pdfe.log("dict was \{@pdf.string_of_pdfobj(dict)}\n")
    }
    @pdfsyntax.dropwhite(input)
    let c = (input.input_byte)()
    let c2 = (input.input_byte)()
    if c != 'I'.to_int() || c2 != 'D'.to_int() {
      @pdfe.log("Did not recognise beginning of inline image ID\n")
      nocontent(input)
    }
    let filters = match @pdf.lookup_direct_orelse(pdf, "/F", "/Filter", dict) {
      Some(@pdf.PdfObject::Array(items)) => items
      Some(@pdf.PdfObject::Name(name)) => [@pdf.PdfObject::Name(name)]
      _ => []
    }
    let toskip = !filterspecial(filters)
    if toskip {
      ignore((input.input_byte)())
    }
    if debug.val {
      @pdfe.log("**got ID header, skipped possible byte\n")
    }
    let bpc = match
      @pdf.lookup_direct_orelse(pdf, "/BPC", "/BitsPerComponent", dict) {
      Some(@pdf.PdfObject::Integer(value)) => value
      _ => {
        @pdfe.log("no BPC\n")
        nocontent(input)
        0
      }
    }
    let cspace = match
      @pdf.lookup_direct_orelse(pdf, "/CS", "/ColorSpace", dict) {
      Some(@pdf.PdfObject::Name(name)) =>
        if name == "/DeviceGray" ||
          name == "/DeviceRGB" ||
          name == "/DeviceCMYK" ||
          name == "/G" ||
          name == "/RGB" ||
          name == "/CMYK" {
          @pdf.PdfObject::Name(name)
        } else {
          if debug.val {
            @pdfe.log("resources is \{@pdf.string_of_pdfobj(resources)}\n")
          }
          match @pdf.lookup_direct(pdf, "/ColorSpace", resources) {
            Some(@pdf.PdfObject::Dictionary(_) as d) =>
              match @pdf.lookup_direct(pdf, name, d) {
                Some(space) => space
                None => {
                  @pdfe.log("no colourspace A\n")
                  nocontent(input)
                  @pdf.PdfObject::Null
                }
              }
            _ => {
              @pdfe.log("no colourspace B\n")
              nocontent(input)
              @pdf.PdfObject::Null
            }
          }
        }
      Some(@pdf.PdfObject::Array(_) as n) => n
      None =>
        match @pdf.lookup_direct_orelse(pdf, "/IM", "/ImageMask", dict) {
          Some(@pdf.PdfObject::Boolean(true)) =>
            @pdf.PdfObject::Name("/DeviceGray")
          _ => {
            @pdfe.log("no colourspace C\n")
            nocontent(input)
            @pdf.PdfObject::Null
          }
        }
      _ => {
        @pdfe.log("no colourspace D\n")
        nocontent(input)
        @pdf.PdfObject::Null
      }
    }
    let width = match @pdf.lookup_direct_orelse(pdf, "/W", "/Width", dict) {
      Some(@pdf.PdfObject::Integer(value)) => value
      _ => {
        @pdfe.log("no or malformed /W")
        nocontent(input)
        0
      }
    }
    let height = match @pdf.lookup_direct_orelse(pdf, "/H", "/Height", dict) {
      Some(@pdf.PdfObject::Integer(value)) => value
      _ => {
        @pdfe.log("no or malformed /H")
        nocontent(input)
        0
      }
    }
    let bitwidth = components(pdf, resources, cspace) * bpc * width
    let bytewidth = if bitwidth % 8 == 0 {
      bitwidth / 8
    } else {
      bitwidth / 8 + 1
    }
    let bytes = bytewidth * height
    let filter_opt = @pdf.lookup_direct_orelse(
      @pdf.empty(),
      "/F",
      "/Filter",
      dict,
    )
    let data = match filter_opt {
      None | Some(@pdf.PdfObject::Array([])) => {
        let out = @pdfio.mkbytes(bytes)
        for i in 0..<bytes {
          @pdfio.bset_unsafe(out, i, (input.input_byte)())
        }
        out
      }
      Some(@pdf.PdfObject::Name(name)) =>
        if name == "/DCT" || name == "/DCTDecode" {
          get_jpeg_data(input)
        } else {
          let encoded = read_inline_image_encoded_data(input)
          match @pdfcodec.decode_from_bytes(encoded, dict) {
            Some(decoded) => decoded
            None => {
              @pdfe.log("decode_from_bytes failed\n")
              nocontent(input)
              @pdfio.mkbytes(0)
            }
          }
        }
      Some(@pdf.PdfObject::Array(items)) =>
        if items.length() == 1 {
          match items[0] {
            @pdf.PdfObject::Name(name) =>
              if name == "/DCT" || name == "/DCTDecode" {
                get_jpeg_data(input)
              } else {
                let encoded = read_inline_image_encoded_data(input)
                match @pdfcodec.decode_from_bytes(encoded, dict) {
                  Some(decoded) => decoded
                  None => {
                    @pdfe.log("decode_from_bytes failed\n")
                    nocontent(input)
                    @pdfio.mkbytes(0)
                  }
                }
              }
            _ => {
              let encoded = read_inline_image_encoded_data(input)
              match @pdfcodec.decode_from_bytes(encoded, dict) {
                Some(decoded) => decoded
                None => {
                  @pdfe.log("decode_from_bytes failed\n")
                  nocontent(input)
                  @pdfio.mkbytes(0)
                }
              }
            }
          }
        } else {
          let encoded = read_inline_image_encoded_data(input)
          match @pdfcodec.decode_from_bytes(encoded, dict) {
            Some(decoded) => decoded
            None => {
              @pdfe.log("decode_from_bytes failed\n")
              nocontent(input)
              @pdfio.mkbytes(0)
            }
          }
        }
      Some(_) => {
        let encoded = read_inline_image_encoded_data(input)
        match @pdfcodec.decode_from_bytes(encoded, dict) {
          Some(decoded) => decoded
          None => {
            @pdfe.log("decode_from_bytes failed\n")
            nocontent(input)
            @pdfio.mkbytes(0)
          }
        }
      }
    }
    @pdfsyntax.dropwhite(input)
    let end1 = (input.input_byte)()
    let end2 = (input.input_byte)()
    if end1 != 'E'.to_int() || end2 != 'I'.to_int() {
      @pdfe.log("warning: bad end to inline image \{end1}, \{end2}\n")
      @pdfsyntax.ignoreuntil(true, chr => chr == 'E', input)
      @pdfsyntax.ignoreuntil(true, chr => chr == 'I', input)
      @pdfio.nudge(input)
      @pdfsyntax.dropwhite(input)
    }
    let dict_clean = match filter_opt {
      Some(@pdf.PdfObject::Name(name)) =>
        if name == "/DCT" || name == "/DCTDecode" {
          dict
        } else {
          let mut cleaned = dict
          for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
            cleaned = @pdf.remove_dict_entry(cleaned, key)
          }
          cleaned
        }
      Some(@pdf.PdfObject::Array(items)) =>
        if items.length() == 1 {
          match items[0] {
            @pdf.PdfObject::Name(name) =>
              if name == "/DCT" || name == "/DCTDecode" {
                dict
              } else {
                let mut cleaned = dict
                for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
                  cleaned = @pdf.remove_dict_entry(cleaned, key)
                }
                cleaned
              }
            _ => {
              let mut cleaned = dict
              for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
                cleaned = @pdf.remove_dict_entry(cleaned, key)
              }
              cleaned
            }
          }
        } else {
          let mut cleaned = dict
          for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
            cleaned = @pdf.remove_dict_entry(cleaned, key)
          }
          cleaned
        }
      _ => {
        let mut cleaned = dict
        for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
          cleaned = @pdf.remove_dict_entry(cleaned, key)
        }
        cleaned
      }
    }
    let dp = @pdf.lookup_direct_orelse(
      @pdf.empty(),
      "/DP",
      "/DecodeParms",
      dict,
    )
    (dict_clean, dp, data)
  } catch {
    err => {
      @pdfe.log("inline image reading failed: \{err}\n")
      nocontent(input)
      (@pdf.PdfObject::Null, None, @pdfio.mkbytes(0))
    }
  }
}

///|
fn lex_keyword(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  input : @pdfio.Input,
) -> Lexeme raise {
  match @pdfsyntax.getuntil_white_or_delimiter_string(input) {
    "true" => Obj(@pdfgenlex.Token::LexBool(true))
    "false" => Obj(@pdfgenlex.Token::LexBool(false))
    "BI" => LexInlineImage(lex_inline_image(pdf, resources, input))
    "ID" | "EI" | "" => {
      nocontent(input)
      Op("")
    }
    opstring => Op(opstring)
  }
}

///|
fn lex_string(input : @pdfio.Input) -> Lexeme raise {
  match (@pdfsyntax.lex_string(input) : @pdfgenlex.Token) {
    LexString(text) => Obj(@pdfgenlex.Token::LexString(text))
    _ => {
      nocontent(input)
      Obj(@pdfgenlex.Token::LexString(""))
    }
  }
}

///|
fn lex_hexstring(input : @pdfio.Input) -> Lexeme raise {
  match (@pdfsyntax.lex_hexstring(input) : @pdfgenlex.Token) {
    LexString(text) => Obj(@pdfgenlex.Token::LexString(text))
    _ => {
      nocontent(input)
      Obj(@pdfgenlex.Token::LexString(""))
    }
  }
}

///|
fn lex_next(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  input : @pdfio.Input,
) -> Lexeme raise {
  try {
    @pdfsyntax.dropwhite(input)
    let next = @pdfio.peek_byte(input)
    if next == @pdfio.no_more {
      raise LexingEnd
    }
    let chr_opt = next.to_char()
    match chr_opt {
      Some('/') => lex_name(input)
      Some('+' | '-' | '.' | '0'..='9') => lex_number(input)
      Some('A'..='Z' | 'a'..='z') => lex_keyword(pdf, resources, input)
      Some('\'') | Some('\"') => lex_keyword(pdf, resources, input)
      Some('(') => lex_string(input)
      Some('[') => {
        @pdfio.nudge(input)
        Obj(@pdfgenlex.Token::LexLeftSquare)
      }
      Some(']') => {
        @pdfio.nudge(input)
        Obj(@pdfgenlex.Token::LexRightSquare)
      }
      Some('<') => {
        @pdfio.nudge(input)
        let next_char = @pdfio.peek_char(input)
        @pdfio.rewind(input)
        match next_char {
          Some('<') => get_dictionary(input)
          _ => lex_hexstring(input)
        }
      }
      Some('%') => {
        ignore(@pdfsyntax.lex_comment(input))
        LexComment
      }
      _ => raise @pdf.PdfError::Msg("Lexing failure in content stream")
    }
  } catch {
    @pdf.PdfError::Msg(message) =>
      raise @pdf.PdfError::Msg("Pdfpages.lex_next => \{message}")
    CouldntHandleContent => raise @pdf.PdfError::Msg("Malformed page content")
    err => raise err
  }
}

///|
fn lex_stream(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  input : @pdfio.Input,
) -> Array[Lexeme] raise {
  let lexemes : Array[Lexeme] = Array::new()
  try {
    while true {
      let lexeme = lex_next(pdf, resources, input)
      match lexeme {
        Lexeme::LexComment => ()
        _ => lexemes.push(lexeme)
      }
    }
    lexemes
  } catch {
    LexingEnd => lexemes
    err => raise err
  }
}

///|
fn split_lexemes(lexemes : Array[Lexeme], start : Int) -> (Array[Lexeme], Int) {
  let section : Array[Lexeme] = Array::new()
  let mut i = start
  let len = lexemes.length()
  while i < len {
    let lexeme = lexemes[i]
    section.push(lexeme)
    match lexeme {
      Lexeme::Op(_) | Lexeme::LexInlineImage(_) => return (section, i + 1)
      _ => ()
    }
    i = i + 1
  }
  (section, i)
}

///|
fn lexeme_real(lexeme : Lexeme) -> Double? {
  match lexeme {
    Obj(LexReal(value)) => Some(value)
    Obj(LexInt(value)) => Some(Double::from_int(value))
    _ => None
  }
}

///|
fn lexeme_int(lexeme : Lexeme) -> Int? {
  match lexeme {
    Obj(LexInt(value)) => Some(value)
    Obj(LexReal(value)) => Some(value.to_int())
    _ => None
  }
}

///|
fn lexeme_name(lexeme : Lexeme) -> String? {
  match lexeme {
    Obj(LexName(name)) => Some(name)
    _ => None
  }
}

///|
fn lexeme_string(lexeme : Lexeme) -> String? {
  match lexeme {
    Obj(LexString(text)) => Some(text)
    _ => None
  }
}

///|
fn lexeme_pdfobj(lexeme : Lexeme) -> @pdf.PdfObject? raise {
  match lexeme {
    Lexeme::PdfObj(obj) => Some(obj)
    Lexeme::Obj(token) => Some(@pdfsyntax.parse([token]).1)
    _ => None
  }
}

///|
fn reals_of_lexemes(
  lexemes : ArrayView[Lexeme],
  errtext : String,
) -> Array[Double] {
  let out : Array[Double] = Array::new()
  for lexeme in lexemes {
    match lexeme_real(lexeme) {
      Some(value) => out.push(value)
      None => {
        @pdfe.log(errtext + "\n")
        return [0.0, 0.0, 0.0]
      }
    }
  }
  out
}

///|
fn parse_dash_op(section : Array[Lexeme]) -> Op raise {
  if section.length() < 4 {
    raise @pdf.PdfError::Msg("malformed 'd' op")
  }
  let op = section[section.length() - 1]
  if op is Lexeme::Op("d") {
    let phase = lexeme_real(section[section.length() - 2])
    if phase is None {
      raise @pdf.PdfError::Msg("malformed 'd' op")
    }
    let right = section[section.length() - 3]
    if right is Obj(LexRightSquare) {
      let mut left_index = -1
      for i in 0..<(section.length() - 3) {
        match section[i] {
          Obj(LexLeftSquare) => left_index = i
          _ => ()
        }
      }
      if left_index < 0 {
        raise @pdf.PdfError::Msg("malformed 'd' op")
      }
      let values : Array[Double] = Array::new()
      for idx in (left_index + 1)..<(section.length() - 3) {
        match lexeme_real(section[idx]) {
          Some(value) => values.push(value)
          None => raise @pdf.PdfError::Msg("malformed 'd' op")
        }
      }
      match phase {
        Some(value) => return Op::Opd(values, value)
        None => raise @pdf.PdfError::Msg("malformed 'd' op")
      }
    }
  }
  raise @pdf.PdfError::Msg("malformed 'd' op")
}

///|
fn parse_tj_op(section : Array[Lexeme]) -> Op raise {
  let op = section[section.length() - 1]
  if op is Lexeme::Op("TJ") {
    if section.length() < 3 {
      raise @pdf.PdfError::Msg("malformed TJ op")
    }
    let right = section[section.length() - 2]
    if right is Obj(LexRightSquare) {
      let mut left_index = -1
      for i in 0..<(section.length() - 2) {
        match section[i] {
          Obj(LexLeftSquare) => left_index = i
          _ => ()
        }
      }
      if left_index < 0 {
        raise @pdf.PdfError::Msg("malformed TJ op")
      }
      let elements : Array[@pdf.PdfObject] = Array::new()
      for idx in (left_index + 1)..<(section.length() - 2) {
        match section[idx] {
          Obj(LexReal(value)) => elements.push(@pdf.PdfObject::Real(value))
          Obj(LexInt(value)) =>
            elements.push(@pdf.PdfObject::Real(Double::from_int(value)))
          Obj(LexString(text)) => elements.push(@pdf.PdfObject::String(text))
          _ => @pdfe.log("Warning: malformed TJ element; skipping\n")
        }
      }
      return Op::OpTJ(@pdf.PdfObject::Array(elements))
    }
  }
  raise @pdf.PdfError::Msg("malformed TJ op")
}

///|
fn parse_operator(
  compatibility : Ref[Int],
  lexemes : Array[Lexeme],
  start : Int,
) -> (Op, Int) raise {
  if start >= lexemes.length() {
    return (Op::OpUnknown(""), start)
  }
  match lexemes[start] {
    Lexeme::LexInlineImage(data) => return (Op::InlineImage(data), start + 1)
    _ => ()
  }
  let (section, next_index) = split_lexemes(lexemes, start)
  if section.length() == 0 {
    return (Op::OpUnknown(""), next_index)
  }
  let op_lexeme = section[section.length() - 1]
  match op_lexeme {
    Lexeme::LexInlineImage(data) => return (Op::InlineImage(data), next_index)
    Lexeme::Op(op) => {
      let operand_count = section.length() - 1
      fn as_real(index : Int) -> Double? {
        if index < operand_count {
          lexeme_real(section[index])
        } else {
          None
        }
      }

      fn as_int(index : Int) -> Int? {
        if index < operand_count {
          lexeme_int(section[index])
        } else {
          None
        }
      }

      fn as_name(index : Int) -> String? {
        if index < operand_count {
          lexeme_name(section[index])
        } else {
          None
        }
      }

      fn as_string(index : Int) -> String? {
        if index < operand_count {
          lexeme_string(section[index])
        } else {
          None
        }
      }

      match op {
        "W" => return (Op::OpW, next_index)
        "W*" => return (Op::OpWStar, next_index)
        "q" => return (Op::Opq, next_index)
        "Q" => return (Op::OpQ, next_index)
        "h" => return (Op::Oph, next_index)
        "n" => return (Op::Opn, next_index)
        "f*" => return (Op::OpfStar, next_index)
        "f" => return (Op::Opf, next_index)
        "F" => return (Op::OpF, next_index)
        "BT" => return (Op::OpBT, next_index)
        "ET" => return (Op::OpET, next_index)
        "B" => return (Op::OpB, next_index)
        "B*" => return (Op::OpBStar, next_index)
        "b" => return (Op::Opb, next_index)
        "b*" => return (Op::OpbStar, next_index)
        "S" => return (Op::OpS, next_index)
        "s" => return (Op::Ops, next_index)
        "T*" => return (Op::OpTStar, next_index)
        "BX" => {
          compatibility.val = compatibility.val + 1
          return (Op::OpBX, next_index)
        }
        "EX" => {
          compatibility.val = compatibility.val - 1
          return (Op::OpEX, next_index)
        }
        "Td" =>
          if operand_count == 2 {
            let tx = as_real(0)
            let ty = as_real(1)
            if tx is Some(x) && ty is Some(y) {
              return (Op::OpTd(x, y), next_index)
            }
          }
        "TD" =>
          if operand_count == 2 {
            let tx = as_real(0)
            let ty = as_real(1)
            if tx is Some(x) && ty is Some(y) {
              return (Op::OpTD(x, y), next_index)
            }
          }
        "w" =>
          if operand_count == 1 {
            let w = as_real(0)
            if w is Some(value) {
              return (Op::Opw(value), next_index)
            }
          }
        "J" =>
          if operand_count == 1 {
            let cap = as_int(0)
            if cap is Some(value) {
              return (Op::OpJ(value), next_index)
            }
          }
        "j" =>
          if operand_count == 1 {
            let join = as_int(0)
            if join is Some(value) {
              return (Op::Opj(value), next_index)
            }
          }
        "m" =>
          if operand_count == 2 {
            let x = as_real(0)
            let y = as_real(1)
            if x is Some(xv) && y is Some(yv) {
              return (Op::Opm(xv, yv), next_index)
            }
          }
        "l" =>
          if operand_count == 2 {
            let x = as_real(0)
            let y = as_real(1)
            if x is Some(xv) && y is Some(yv) {
              return (Op::Opl(xv, yv), next_index)
            }
          }
        "TL" =>
          if operand_count == 1 {
            let leading = as_real(0)
            if leading is Some(value) {
              return (Op::OpTL(value), next_index)
            }
          }
        "Tf" =>
          if operand_count == 2 {
            let name = as_name(0)
            let size = as_real(1)
            if name is Some(n) && size is Some(s) {
              return (Op::OpTf(n, s), next_index)
            }
          }
        "Tj" =>
          if operand_count == 1 {
            let text = as_string(0)
            if text is Some(value) {
              return (Op::OpTj(value), next_index)
            }
          }
        "RG" =>
          if operand_count == 3 {
            let r = as_real(0)
            let g = as_real(1)
            let b = as_real(2)
            if r is Some(rv) && g is Some(gv) && b is Some(bv) {
              return (Op::OpRG(rv, gv, bv), next_index)
            }
          }
        "rg" =>
          if operand_count == 3 {
            let r = as_real(0)
            let g = as_real(1)
            let b = as_real(2)
            if r is Some(rv) && g is Some(gv) && b is Some(bv) {
              return (Op::Oprg(rv, gv, bv), next_index)
            }
          }
        "G" =>
          if operand_count == 1 {
            let g = as_real(0)
            if g is Some(value) {
              return (Op::OpG(value), next_index)
            }
          }
        "g" =>
          if operand_count == 1 {
            let g = as_real(0)
            if g is Some(value) {
              return (Op::Opg(value), next_index)
            }
          }
        "k" =>
          if operand_count == 4 {
            let c = as_real(0)
            let m = as_real(1)
            let y = as_real(2)
            let k = as_real(3)
            if c is Some(cv) && m is Some(mv) && y is Some(yv) && k is Some(kv) {
              return (Op::Opk(cv, mv, yv, kv), next_index)
            }
          }
        "K" =>
          if operand_count == 4 {
            let c = as_real(0)
            let m = as_real(1)
            let y = as_real(2)
            let k = as_real(3)
            if c is Some(cv) && m is Some(mv) && y is Some(yv) && k is Some(kv) {
              return (Op::OpK(cv, mv, yv, kv), next_index)
            }
          }
        "cm" =>
          if operand_count == 6 {
            let a = as_real(0)
            let b = as_real(1)
            let c = as_real(2)
            let d = as_real(3)
            let e = as_real(4)
            let f = as_real(5)
            if a is Some(av) &&
              b is Some(bv) &&
              c is Some(cv) &&
              d is Some(dv) &&
              e is Some(ev) &&
              f is Some(fv) {
              return (
                Op::Opcm({ a: av, b: bv, c: cv, d: dv, e: ev, f: fv }),
                next_index,
              )
            }
          }
        "Tm" =>
          if operand_count == 6 {
            let a = as_real(0)
            let b = as_real(1)
            let c = as_real(2)
            let d = as_real(3)
            let e = as_real(4)
            let f = as_real(5)
            if a is Some(av) &&
              b is Some(bv) &&
              c is Some(cv) &&
              d is Some(dv) &&
              e is Some(ev) &&
              f is Some(fv) {
              return (
                Op::OpTm({ a: av, b: bv, c: cv, d: dv, e: ev, f: fv }),
                next_index,
              )
            }
          }
        "MP" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::OpMP(value), next_index)
            }
          }
        "DP" =>
          if operand_count == 2 {
            let name = as_name(0)
            if name is Some(value) {
              match lexeme_pdfobj(section[1]) {
                Some(obj) => return (Op::OpDP(value, obj), next_index)
                None => ()
              }
            }
          }
        "BMC" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::OpBMC(value), next_index)
            }
          }
        "BDC" =>
          if operand_count == 2 {
            let name = as_name(0)
            if name is Some(value) {
              match lexeme_pdfobj(section[1]) {
                Some(obj) => return (Op::OpBDC(value, obj), next_index)
                None => ()
              }
            }
          }
        "EMC" => return (Op::OpEMC, next_index)
        "gs" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::Opgs(value), next_index)
            }
          }
        "Do" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::OpDo(value), next_index)
            }
          }
        "CS" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::OpCS(value), next_index)
            }
          }
        "cs" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::Opcs(value), next_index)
            }
          }
        "c" =>
          if operand_count == 6 {
            let x1 = as_real(0)
            let y1 = as_real(1)
            let x2 = as_real(2)
            let y2 = as_real(3)
            let x3 = as_real(4)
            let y3 = as_real(5)
            if x1 is Some(x1v) &&
              y1 is Some(y1v) &&
              x2 is Some(x2v) &&
              y2 is Some(y2v) &&
              x3 is Some(x3v) &&
              y3 is Some(y3v) {
              return (Op::Opc(x1v, y1v, x2v, y2v, x3v, y3v), next_index)
            }
          }
        "v" =>
          if operand_count == 4 {
            let x2 = as_real(0)
            let y2 = as_real(1)
            let x3 = as_real(2)
            let y3 = as_real(3)
            if x2 is Some(x2v) &&
              y2 is Some(y2v) &&
              x3 is Some(x3v) &&
              y3 is Some(y3v) {
              return (Op::Opv(x2v, y2v, x3v, y3v), next_index)
            }
          }
        "y" =>
          if operand_count == 4 {
            let x1 = as_real(0)
            let y1 = as_real(1)
            let x3 = as_real(2)
            let y3 = as_real(3)
            if x1 is Some(x1v) &&
              y1 is Some(y1v) &&
              x3 is Some(x3v) &&
              y3 is Some(y3v) {
              return (Op::Opy(x1v, y1v, x3v, y3v), next_index)
            }
          }
        "re" =>
          if operand_count == 4 {
            let x = as_real(0)
            let y = as_real(1)
            let w = as_real(2)
            let h = as_real(3)
            if x is Some(xv) && y is Some(yv) && w is Some(wv) && h is Some(hv) {
              return (Op::Opre(xv, yv, wv, hv), next_index)
            }
          }
        "ri" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::Opri(value), next_index)
            }
          }
        "i" =>
          if operand_count == 1 {
            let value = as_int(0)
            if value is Some(v) {
              return (Op::Opi(v), next_index)
            }
          }
        "M" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (Op::OpM(v), next_index)
            }
          }
        "'" =>
          if operand_count == 1 {
            let text = as_string(0)
            if text is Some(value) {
              return (Op::OpSingleQuote(value), next_index)
            }
          }
        "\"" =>
          if operand_count == 3 {
            let aw = as_real(0)
            let ac = as_real(1)
            let text = as_string(2)
            if aw is Some(awp) && ac is Some(acp) && text is Some(txt) {
              return (Op::OpDoubleQuote(awp, acp, txt), next_index)
            }
          }
        "d0" =>
          if operand_count == 2 {
            let wx = as_real(0)
            let wy = as_real(1)
            if wx is Some(wxv) && wy is Some(wyv) {
              return (Op::Opd0(wxv, wyv), next_index)
            }
          }
        "d1" =>
          if operand_count == 6 {
            let wx = as_real(0)
            let wy = as_real(1)
            let llx = as_real(2)
            let lly = as_real(3)
            let urx = as_real(4)
            let ury = as_real(5)
            if wx is Some(wxv) &&
              wy is Some(wyv) &&
              llx is Some(llxv) &&
              lly is Some(llyv) &&
              urx is Some(urxv) &&
              ury is Some(uryv) {
              return (Op::Opd1(wxv, wyv, llxv, llyv, urxv, uryv), next_index)
            }
          }
        "sh" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::Opsh(value), next_index)
            }
          }
        "Tc" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (Op::OpTc(v), next_index)
            }
          }
        "Tw" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (Op::OpTw(v), next_index)
            }
          }
        "Tz" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (Op::OpTz(v), next_index)
            }
          }
        "Tr" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (Op::OpTr(v.to_int()), next_index)
            }
          }
        "Ts" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (Op::OpTs(v), next_index)
            }
          }
        "sc" =>
          return (
            Op::Opsc(
              reals_of_lexemes(section[0:operand_count], "Malformed 'sc'"),
            ),
            next_index,
          )
        "SC" =>
          return (
            Op::OpSC(
              reals_of_lexemes(section[0:operand_count], "Malformed 'SC'"),
            ),
            next_index,
          )
        "scn" =>
          if operand_count > 0 {
            match lexeme_name(section[operand_count - 1]) {
              Some(name) => {
                let values = reals_of_lexemes(
                  section[0:operand_count - 1],
                  "scn",
                )
                return (Op::OpscnName(name, values), next_index)
              }
              None => {
                let values = reals_of_lexemes(
                  section[0:operand_count],
                  "Malformed 'scn'",
                )
                return (Op::Opscn(values), next_index)
              }
            }
          }
        "SCN" =>
          if operand_count > 0 {
            match lexeme_name(section[operand_count - 1]) {
              Some(name) => {
                let values = reals_of_lexemes(
                  section[0:operand_count - 1],
                  "SCN",
                )
                return (Op::OpSCNName(name, values), next_index)
              }
              None => {
                let values = reals_of_lexemes(
                  section[0:operand_count],
                  "Malformed 'SCN'",
                )
                return (Op::OpSCN(values), next_index)
              }
            }
          }
        "d" => return (parse_dash_op(section), next_index)
        "TJ" => return (parse_tj_op(section), next_index)
        _ => ()
      }
      @pdfe.log(
        "Empty or malformed graphics operation \{string_of_lexemes(section)}.\n",
      )
      (Op::OpUnknown(string_of_lexemes(section)), next_index)
    }
    _ => {
      @pdfe.log(
        "Empty or malformed graphics operation \{string_of_lexemes(section)}.\n",
      )
      (Op::OpUnknown(string_of_lexemes(section)), next_index)
    }
  }
}

///|
fn parse_lexemes(
  compatibility : Ref[Int],
  lexemes : Array[Lexeme],
) -> Array[Op] raise {
  let ops : Array[Op] = Array::new()
  let mut index = 0
  while index < lexemes.length() {
    let (op, next_index) = parse_operator(compatibility, lexemes, index)
    ops.push(op)
    index = next_index
  }
  ops
}

///|
/// Parse a single byte stream to an operator list.
pub fn parse_single_stream(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  stream : @pdfio.MutableBytes,
) -> Array[Op] raise {
  let input = @pdfio.input_of_bytes(stream)
  let lexemes = lex_stream(pdf, resources, input)
  parse_lexemes({ val: 0 }, lexemes)
}

///|
/// Parse a list of byte streams to an operator list.
pub fn parse_stream(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  streams : Array[@pdfio.MutableBytes],
) -> Array[Op] raise {
  let stream = if streams.length() == 1 {
    streams[0]
  } else {
    concat_bytess(streams)
  }
  parse_single_stream(pdf, resources, stream)
}

///|
/// Parse the operators in content streams.
pub fn parse_operators(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  streams : Array[@pdf.PdfObject],
) -> Array[Op] raise {
  let rawstreams : Array[@pdfio.MutableBytes] = Array::new()
  for stream in streams {
    let direct = @pdf.direct(pdf, stream)
    @pdfcodec.decode_pdfstream(pdf, direct)
    @pdf.getstream(direct)
    match direct {
      @pdf.PdfObject::Stream(r) =>
        match r.val {
          (_, @pdf.Stream::Got(data)) => rawstreams.push(data)
          _ => raise @pdf.PdfError::Msg("Malformed stream")
        }
      _ => raise @pdf.PdfError::Msg("Malformed stream")
    }
  }
  parse_stream(pdf, resources, rawstreams)
}
