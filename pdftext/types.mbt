///|
/// PDF font and encoding types.

///|
pub struct Type3Glyphs {
  fontbbox : (Double, Double, Double, Double)
  fontmatrix : @pdftransform.TransformMatrix
  charprocs : Array[(String, @pdf.PdfObject)]
  type3_resources : @pdf.PdfObject
}

///|
pub enum SimpleFontType {
  Type1
  MMType1
  Type3(Type3Glyphs)
  Truetype
}

///|
pub type FontMetrics = Array[Double]

///|
pub enum FontFile {
  FontFile(Int)
  FontFile2(Int)
  FontFile3(Int)
}

///|
pub struct FontDescriptor {
  ascent : Double
  descent : Double
  avgwidth : Double
  maxwidth : Double
  flags : Int
  fontbbox : (Double, Double, Double, Double)
  italicangle : Double
  capheight : Double
  xheight : Double
  stemv : Double
  fontfile : FontFile?
  charset : Array[String]?
  tounicode : Map[Int, String]?
}

///|
pub type Differences = Array[(String, Int)]

///|
pub enum Encoding {
  ImplicitInFontFile
  StandardEncoding
  MacRomanEncoding
  WinAnsiEncoding
  MacExpertEncoding
  CustomEncoding(Encoding, Differences)
  FillUndefinedWithStandard(Encoding)
}

///|
pub struct SimpleFont {
  fonttype : SimpleFontType
  basefont : String
  firstchar : Int
  lastchar : Int
  widths : Array[Int]
  fontdescriptor : FontDescriptor?
  fontmetrics : FontMetrics?
  encoding : Encoding
}

///|
pub(all) enum StandardFont {
  TimesRoman
  TimesBold
  TimesItalic
  TimesBoldItalic
  Helvetica
  HelveticaBold
  HelveticaOblique
  HelveticaBoldOblique
  Courier
  CourierBold
  CourierOblique
  CourierBoldOblique
  Symbol
  ZapfDingbats
} derive(Eq)

///|
pub fn string_of_standard_font(font : StandardFont) -> String {
  match font {
    StandardFont::TimesRoman => "Times-Roman"
    StandardFont::TimesBold => "Times-Bold"
    StandardFont::TimesItalic => "Times-Italic"
    StandardFont::TimesBoldItalic => "Times-BoldItalic"
    StandardFont::Helvetica => "Helvetica"
    StandardFont::HelveticaBold => "Helvetica-Bold"
    StandardFont::HelveticaOblique => "Helvetica-Oblique"
    StandardFont::HelveticaBoldOblique => "Helvetica-BoldOblique"
    StandardFont::Courier => "Courier"
    StandardFont::CourierBold => "Courier-Bold"
    StandardFont::CourierOblique => "Courier-Oblique"
    StandardFont::CourierBoldOblique => "Courier-BoldOblique"
    StandardFont::Symbol => "Symbol"
    StandardFont::ZapfDingbats => "ZapfDingbats"
  }
}

///|
pub struct CIDSystemInfo {
  registry : String
  ordering : String
  supplement : Int
}

///|
pub struct CompositeCIDFont {
  cid_system_info : CIDSystemInfo
  cid_basefont : String
  cid_fontdescriptor : FontDescriptor
  cid_widths : Array[(Int, Double)]
  cid_default_width : Int
}

///|
pub enum CMapEncoding {
  Predefined(String)
  CMap(Int)
}

///|
pub enum Font {
  StandardFont(StandardFont, Encoding)
  SimpleFont(SimpleFont)
  CIDKeyedFont(String, CompositeCIDFont, CMapEncoding)
}

///|
pub fn string_of_fonttype(fonttype : SimpleFontType) -> String {
  match fonttype {
    SimpleFontType::Type1 => "Type 1"
    SimpleFontType::MMType1 => "MM Type 1"
    SimpleFontType::Type3(glyphs) =>
      "Type 3: charprocs for" + glyphs.charprocs.map(pair => pair.0).join("")
    SimpleFontType::Truetype => "Truetype"
  }
}

///|
pub fn string_of_encoding(encoding : Encoding) -> String {
  match encoding {
    Encoding::ImplicitInFontFile => "ImplicitInFontFile"
    Encoding::StandardEncoding => "StandardEncoding"
    Encoding::MacRomanEncoding => "MacRomanEncoding"
    Encoding::WinAnsiEncoding => "WinAnsiEncoding"
    Encoding::MacExpertEncoding => "MacExpertEncoding"
    Encoding::CustomEncoding(enc, diff) =>
      "CustomEncoding with base " +
      string_of_encoding(enc) +
      " and differences " +
      diff.map(pair => "\{pair.1} -> \{pair.0}, ").join("")
    Encoding::FillUndefinedWithStandard(enc) =>
      "FillUndefinedWithStandard " + string_of_encoding(enc)
  }
}

///|
pub fn string_of_simple_font(font : SimpleFont) -> String {
  "fonttype = " +
  string_of_fonttype(font.fonttype) +
  "\nbasefont " +
  font.basefont +
  "\nencoding is " +
  string_of_encoding(font.encoding) +
  "\n"
}

///|
pub fn string_of_font(font : Font) -> String {
  match font {
    Font::StandardFont(standard, _) =>
      "StandardFont " + string_of_standard_font(standard)
    Font::SimpleFont(simple) => "SimpleFont " + string_of_simple_font(simple)
    Font::CIDKeyedFont(name, _, _) => "CIDKeyedFont " + name
  }
}
