///|
/// Core PDF object tree.
pub(all) enum PdfObject {
  Null
  Boolean(Bool)
  Integer(Int)
  Real(Double)
  String(String)
  Name(String)
  Array(Array[PdfObject])
  // Use an Array of (key, value) pairs instead of Map:
  // - Allows representing malformed PDFs with duplicate keys.
  // - Preserves "first match wins" semantics used by lookup_* (search_by).
  // - Keeps insertion order stable for serialization.
  Dictionary(Array[(String, PdfObject)])
  Stream(Ref[(PdfObject, Stream)])
  Indirect(Int)
}

///|
/// Convert primitive numeric types into PDF numeric objects.
///
/// This is intentionally narrow (only Int/Double) so callers don't have to
/// choose between PDF Strings vs Names, etc.
pub trait ToPdfNumber {
  to_pdf_number(Self) -> PdfObject
}

///|
pub impl ToPdfNumber for Int with to_pdf_number(self : Int) -> PdfObject {
  PdfObject::Integer(self)
}

///|
pub impl ToPdfNumber for Double with to_pdf_number(self : Double) -> PdfObject {
  PdfObject::Real(self)
}

///|
/// Remove a dictionary entry (also works for streams).
pub fn PdfObject::remove_entry(
  self : PdfObject,
  key : String,
) -> PdfObject raise {
  match self {
    Dictionary(entries) => {
      let out = entries.filter(pair => pair.0 != key)
      Dictionary(out)
    }
    Stream(r) => {
      let (inner, stream) = r.val
      r.val = (inner.remove_entry(key), stream)
      Stream(r)
    }
    _ => raise PdfError::Msg("remove_entry: not a dictionary")
  }
}

///|
/// Replace a dictionary entry, raising if it's not present (also works for streams).
pub fn PdfObject::replace_entry(
  self : PdfObject,
  key : String,
  value : PdfObject,
) -> PdfObject raise {
  match self {
    Null => Dictionary([(key, value)])
    Dictionary(entries) => {
      let mut replaced = false
      let out = Array::new(capacity=entries.length())
      for entry in entries {
        let (k, v) = entry
        if k == key {
          out.push((k, value))
          replaced = true
        } else {
          out.push((k, v))
        }
      }
      if !replaced {
        raise PdfError::Msg("replace_entry: key not found")
      }
      Dictionary(out)
    }
    Stream(r) => {
      let (inner, stream) = r.val
      r.val = (inner.replace_entry(key, value), stream)
      Stream(r)
    }
    _ => raise PdfError::Msg("replace_entry: not a dictionary")
  }
}

///|
/// Add a dictionary entry, replacing if already present (also works for streams).
pub fn PdfObject::add_entry(
  self : PdfObject,
  key : String,
  value : PdfObject,
) -> PdfObject raise {
  match self {
    Null => Dictionary([(key, value)])
    Dictionary(entries) => {
      let mut replaced = false
      let out = Array::new(capacity=entries.length() + 1)
      for entry in entries {
        let (k, v) = entry
        if k == key {
          out.push((k, value))
          replaced = true
        } else {
          out.push((k, v))
        }
      }
      if !replaced {
        out.push((key, value))
      }
      Dictionary(out)
    }
    Stream(r) => {
      let (inner, stream) = r.val
      r.val = (inner.add_entry(key, value), stream)
      Stream(r)
    }
    _ => raise PdfError::Msg("add_entry: not a dictionary")
  }
}

///|
/// Lookup the key without following indirects at either source or destination.
pub fn PdfObject::lookup_immediate(
  self : PdfObject,
  key : String,
) -> PdfObject? {
  match self {
    Dictionary(entries) =>
      match entries.search_by(pair => pair.0 == key) {
        None => None
        Some(i) => Some(entries[i].1)
      }
    Stream(r) => {
      let (inner, _) = r.val
      match inner {
        Dictionary(entries) =>
          match entries.search_by(pair => pair.0 == key) {
            None => None
            Some(i) => Some(entries[i].1)
          }
        _ => None
      }
    }
    _ => None
  }
}

///|
/// Find the indirect reference given by the value associated with a key.
pub fn PdfObject::find_indirect(self : PdfObject, key : String) -> Int? raise {
  match self {
    Dictionary(_) =>
      match self.lookup_immediate(key) {
        Some(Indirect(i)) => Some(i)
        _ => None
      }
    _ => raise PdfError::Msg("find_indirect: not a dictionary")
  }
}
