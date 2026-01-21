///|
priv enum ParseItem {
  Parsed(@pdf.PdfObject)
  Lexeme(@pdfgenlex.Token)
}

///|
fn parse_R(tokens : Array[@pdfgenlex.Token]) -> Array[ParseItem] {
  let out = Array::new()
  let mut i = 0
  while i < tokens.length() {
    if i + 2 < tokens.length() {
      match (tokens[i], tokens[i + 1], tokens[i + 2]) {
        (
          @pdfgenlex.Token::LexInt(o),
          @pdfgenlex.Token::LexInt(_),
          @pdfgenlex.Token::LexR,
        ) => {
          out.push(ParseItem::Parsed(@pdf.PdfObject::Indirect(o)))
          i = i + 3
          continue
        }
        _ => ()
      }
    }
    match tokens[i] {
      @pdfgenlex.Token::LexComment(_) => ()
      @pdfgenlex.Token::LexNull =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Null))
      @pdfgenlex.Token::LexBool(b) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Boolean(b)))
      @pdfgenlex.Token::LexInt(v) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Integer(v)))
      @pdfgenlex.Token::LexReal(v) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Real(v)))
      @pdfgenlex.Token::LexString(s) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::String(s)))
      @pdfgenlex.Token::LexName(n) =>
        out.push(ParseItem::Parsed(@pdf.PdfObject::Name(n)))
      other => out.push(ParseItem::Lexeme(other))
    }
    i = i + 1
  }
  out
}

///|
fn parse_dictionary(
  items : Array[ParseItem],
  start : Int,
) -> (ParseItem, Int) raise {
  let entries = Array::new()
  let mut i = start + 1
  while i < items.length() {
    match items[i] {
      ParseItem::Lexeme(@pdfgenlex.Token::LexRightDict) =>
        return (ParseItem::Parsed(@pdf.PdfObject::Dictionary(entries)), i + 1)
      _ => {
        let (key_item, next_i) = parse_value(items, i)
        let (val_item, next_i2) = parse_value(items, next_i)
        match (key_item, val_item) {
          (ParseItem::Parsed(@pdf.PdfObject::Name(k)), ParseItem::Parsed(v)) =>
            entries.push((k, v))
          _ => raise @pdf.PdfError::Msg("parse_dictionary")
        }
        i = next_i2
      }
    }
  }
  raise @pdf.PdfError::Msg("parse_dictionary")
}

///|
fn parse_array(items : Array[ParseItem], start : Int) -> (ParseItem, Int) raise {
  let values = Array::new()
  let mut i = start + 1
  while i < items.length() {
    match items[i] {
      ParseItem::Lexeme(@pdfgenlex.Token::LexRightSquare) =>
        return (ParseItem::Parsed(@pdf.PdfObject::Array(values)), i + 1)
      _ => {
        let (val_item, next_i) = parse_value(items, i)
        match val_item {
          ParseItem::Parsed(v) => values.push(v)
          _ => raise @pdf.PdfError::Msg("parse_array")
        }
        i = next_i
      }
    }
  }
  raise @pdf.PdfError::Msg("parse_array")
}

///|
fn parse_value(items : Array[ParseItem], start : Int) -> (ParseItem, Int) raise {
  if start >= items.length() {
    raise @pdf.PdfError::Msg("parse_value")
  }
  match items[start] {
    ParseItem::Lexeme(@pdfgenlex.Token::LexLeftDict) =>
      parse_dictionary(items, start)
    ParseItem::Lexeme(@pdfgenlex.Token::LexLeftSquare) =>
      parse_array(items, start)
    other => (other, start + 1)
  }
}

///|
fn parse_to_tree(items : Array[ParseItem]) -> Array[ParseItem] raise {
  let out = Array::new()
  let mut i = 0
  while i < items.length() {
    match items[i] {
      ParseItem::Lexeme(@pdfgenlex.Token::LexLeftDict) => {
        let (parsed, next_i) = parse_dictionary(items, i)
        out.push(parsed)
        i = next_i
      }
      ParseItem::Lexeme(@pdfgenlex.Token::LexLeftSquare) => {
        let (parsed, next_i) = parse_array(items, i)
        out.push(parsed)
        i = next_i
      }
      other => {
        out.push(other)
        i = i + 1
      }
    }
  }
  out
}

///|
fn parse_finish(
  items : Array[ParseItem],
  failure_is_ok : Bool,
) -> (Int, @pdf.PdfObject) raise {
  if items.length() == 1 {
    match items[0] {
      ParseItem::Parsed(obj) => return (0, obj)
      _ => raise @pdf.PdfError::Msg("Could not extract object")
    }
  }
  if items.length() >= 5 {
    if items.length() >= 7 {
      match
        (items[0], items[1], items[2], items[3], items[4], items[5], items[6]) {
        (
          ParseItem::Parsed(@pdf.PdfObject::Integer(o)),
          ParseItem::Parsed(@pdf.PdfObject::Integer(_)),
          ParseItem::Lexeme(@pdfgenlex.Token::LexObj),
          ParseItem::Parsed(@pdf.PdfObject::Dictionary(dict)),
          ParseItem::Lexeme(@pdfgenlex.Token::LexStream(stream)),
          ParseItem::Lexeme(@pdfgenlex.Token::LexEndStream),
          ParseItem::Lexeme(@pdfgenlex.Token::LexEndObj),
        ) =>
          return (
            o,
            @pdf.PdfObject::Stream(
              Ref::new((@pdf.PdfObject::Dictionary(dict), stream)),
            ),
          )
        _ => ()
      }
    }
    match (items[0], items[1], items[2], items[3], items[4]) {
      (
        ParseItem::Parsed(@pdf.PdfObject::Integer(o)),
        ParseItem::Parsed(@pdf.PdfObject::Integer(_)),
        ParseItem::Lexeme(@pdfgenlex.Token::LexObj),
        ParseItem::Parsed(obj),
        ParseItem::Lexeme(@pdfgenlex.Token::LexEndObj),
      ) => return (o, obj)
      _ => ()
    }
  }
  if items.length() >= 4 {
    match (items[0], items[1], items[2], items[3]) {
      (
        ParseItem::Parsed(@pdf.PdfObject::Integer(o)),
        ParseItem::Parsed(@pdf.PdfObject::Integer(_)),
        ParseItem::Lexeme(@pdfgenlex.Token::LexObj),
        ParseItem::Parsed(obj),
      ) => return (o, obj)
      (
        ParseItem::Parsed(@pdf.PdfObject::Integer(o)),
        ParseItem::Parsed(@pdf.PdfObject::Integer(_)),
        ParseItem::Lexeme(@pdfgenlex.Token::LexObj),
        ParseItem::Lexeme(@pdfgenlex.Token::LexEndObj),
      ) => return (o, @pdf.PdfObject::Null)
      _ => ()
    }
  }
  if failure_is_ok {
    (0, @pdf.PdfObject::Null)
  } else {
    raise @pdf.PdfError::Msg("Could not extract object")
  }
}

///|
/// Parse a PDF object from tokens.
pub fn parse(
  tokens : Array[@pdfgenlex.Token],
  failure_is_ok? : Bool = false,
) -> (Int, @pdf.PdfObject) raise {
  parse_finish(parse_to_tree(parse_R(tokens)), failure_is_ok) catch {
    err => if failure_is_ok { (0, @pdf.PdfObject::Null) } else { raise err }
  }
}
