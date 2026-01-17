///|
/// The 14 Standard PDF Fonts (Widths and Kerns).

///|
type AfmTables = (
  Map[String, String],
  Map[Int, Int],
  Map[(Int, Int), Int],
  Map[String, Int],
)

///|
fn read_afm(afm : Array[Byte]) -> AfmTables raise {
  let decompressed = @pdfio.string_of_bytes(@pdfcodec.decode_flate(afm))
  let (headers, ws, ks, ws_prime) = @pdfafm.read(
    @pdfio.input_of_string(decompressed),
  )
  (
    @pdfutil.hashtable_of_dictionary(headers),
    @pdfutil.hashtable_of_dictionary(ws),
    @pdfutil.hashtable_of_dictionary(ks.map(pair => ((pair.0, pair.1), pair.2))),
    @pdfutil.hashtable_of_dictionary(ws_prime),
  )
}

///|
let tables : Array[(@pdftext.StandardFont, () -> AfmTables raise)] = [
  (
    @pdftext.StandardFont::TimesRoman,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.times_roman_afm())),
  ),
  (
    @pdftext.StandardFont::TimesBold,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.times_bold_afm())),
  ),
  (
    @pdftext.StandardFont::TimesItalic,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.times_italic_afm())),
  ),
  (
    @pdftext.StandardFont::TimesBoldItalic,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.times_bold_italic_afm())),
  ),
  (
    @pdftext.StandardFont::Helvetica,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.helvetica_afm())),
  ),
  (
    @pdftext.StandardFont::HelveticaBold,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.helvetica_bold_afm())),
  ),
  (
    @pdftext.StandardFont::HelveticaOblique,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.helvetica_oblique_afm())),
  ),
  (
    @pdftext.StandardFont::HelveticaBoldOblique,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.helvetica_bold_oblique_afm())),
  ),
  (
    @pdftext.StandardFont::Courier,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.courier_afm())),
  ),
  (
    @pdftext.StandardFont::CourierBold,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.courier_bold_afm())),
  ),
  (
    @pdftext.StandardFont::CourierOblique,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.courier_oblique_afm())),
  ),
  (
    @pdftext.StandardFont::CourierBoldOblique,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.courier_bold_oblique_afm())),
  ),
  (
    @pdftext.StandardFont::Symbol,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.symbol_afm())),
  ),
  (
    @pdftext.StandardFont::ZapfDingbats,
    @pdfutil.memoize(() => read_afm(@pdfafmdata.zapf_dingbats_afm())),
  ),
]

///|
fn lookup_tables(font : @pdftext.StandardFont) -> AfmTables raise {
  for entry in tables {
    if entry.0 == font {
      return (entry.1)()
    }
  }
  fail("standard14: missing font data")
}

///|
pub fn baseline_adjustment(font : @pdftext.StandardFont) -> Int {
  match font {
    @pdftext.StandardFont::TimesRoman => 662 / 2
    @pdftext.StandardFont::TimesBold => 676 / 2
    @pdftext.StandardFont::TimesItalic => 653 / 2
    @pdftext.StandardFont::TimesBoldItalic => 669 / 2
    @pdftext.StandardFont::Helvetica => 718 / 2
    @pdftext.StandardFont::HelveticaBold => 718 / 2
    @pdftext.StandardFont::HelveticaOblique => 718 / 2
    @pdftext.StandardFont::HelveticaBoldOblique => 718 / 2
    @pdftext.StandardFont::Courier => 562 / 2
    @pdftext.StandardFont::CourierBold => 562 / 2
    @pdftext.StandardFont::CourierOblique => 562 / 2
    @pdftext.StandardFont::CourierBoldOblique => 562 / 2
    @pdftext.StandardFont::Symbol => 673 / 2
    @pdftext.StandardFont::ZapfDingbats => 705 / 2
  }
}

///|
fn find_kern(kerns : Map[(Int, Int), Int], key : (Int, Int)) -> Int {
  match kerns.get(key) {
    Some(value) => value
    None => 0
  }
}

///|
fn find_width(
  widths : Map[Int, Int],
  charname_to_width : Map[String, Int],
  encoding : @pdftext.Encoding,
  encoding_table : Map[Int, String],
  code : Int,
) -> Int raise {
  match encoding {
    @pdftext.Encoding::ImplicitInFontFile =>
      match widths.get(code) {
        Some(value) => value
        None => 0
      }
    _ => {
      let charname = match encoding_table.get(code) {
        Some(value) => value
        None => "/space"
      }
      let stripped = match charname.get_char(0) {
        Some('/') => charname[1:].to_string()
        _ => charname
      }
      match charname_to_width.get(stripped) {
        Some(value) => value
        None => 0
      }
    }
  }
}

///|
fn width(
  dokern : Bool,
  widths : Map[Int, Int],
  charname_to_width : Map[String, Int],
  encoding : @pdftext.Encoding,
  encoding_table : Map[Int, String],
  kerns : Map[(Int, Int), Int],
  codes : Array[Int],
) -> Int raise {
  if codes.length() == 0 {
    return 0
  }
  let mut total = 0
  for i = 0; i < codes.length(); i = i + 1 {
    let h = codes[i]
    total = total +
      find_width(widths, charname_to_width, encoding, encoding_table, h)
    if dokern && i + 1 < codes.length() {
      total = total + find_kern(kerns, (h, codes[i + 1]))
    }
  }
  total
}

///|
pub fn textwidth(
  dokern : Bool,
  encoding : @pdftext.Encoding,
  font : @pdftext.StandardFont,
  s : String,
) -> Int raise {
  let (_, widths, kerns, charname_to_width) = lookup_tables(font)
  let encoding_table = @pdftext.table_of_encoding(encoding)
  let codes = s.to_array().map(c => c.to_int())
  width(
    dokern, widths, charname_to_width, encoding, encoding_table, kerns, codes,
  )
}

///|
pub fn afm_data(font : @pdftext.StandardFont) -> AfmTables raise {
  lookup_tables(font)
}

///|
pub fn stemv_of_standard_font(font : @pdftext.StandardFont) -> Int {
  match font {
    @pdftext.StandardFont::TimesRoman => 116
    @pdftext.StandardFont::TimesBold => 122
    @pdftext.StandardFont::TimesItalic => 105
    @pdftext.StandardFont::TimesBoldItalic => 108
    @pdftext.StandardFont::Helvetica => 114
    @pdftext.StandardFont::HelveticaBold => 123
    @pdftext.StandardFont::HelveticaOblique => 127
    @pdftext.StandardFont::HelveticaBoldOblique => 136
    @pdftext.StandardFont::Courier => 88
    @pdftext.StandardFont::CourierBold => 93
    @pdftext.StandardFont::CourierOblique => 100
    @pdftext.StandardFont::CourierBoldOblique => 104
    @pdftext.StandardFont::Symbol => 0
    @pdftext.StandardFont::ZapfDingbats => 125
  }
}

///|
pub fn flags_of_standard_font(font : @pdftext.StandardFont) -> Int {
  match font {
    @pdftext.StandardFont::Symbol => 65541
    @pdftext.StandardFont::ZapfDingbats => 4
    @pdftext.StandardFont::Courier
    | @pdftext.StandardFont::CourierBold
    | @pdftext.StandardFont::CourierOblique
    | @pdftext.StandardFont::CourierBoldOblique => 33
    _ => 32
  }
}
