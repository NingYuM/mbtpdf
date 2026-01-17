///|
/// Core error used across the PDF surface.
pub suberror PdfError {
  Msg(String)
}

///|
/// Placeholder for saved encryption metadata.
pub struct SavedEncryption {
  placeholder : Unit
}

///|
/// Placeholder for deferred encryption metadata.
pub struct DeferredEncryption {
  placeholder : Unit
}

///|
/// Indicates whether a stream needs decryption when materialized.
pub enum ToGetCrypt {
  NoChange
  ToDecrypt(DeferredEncryption)
}

///|
/// Stream descriptor when bytes are not yet materialized.
pub struct ToGet {
  input : @pdfio.Input
  position : Int
  length : Int
  crypt : ToGetCrypt
}

///|
/// Stream payload, either in memory or deferred.
pub enum Stream {
  Got(@pdfio.MutableBytes)
  ToGet(ToGet)
}

///|
/// Core PDF object tree.
pub enum PdfObject {
  Null
  Boolean(Bool)
  Integer(Int)
  Real(Double)
  String(String)
  Name(String)
  Array(Array[PdfObject])
  Dictionary(Array[(String, PdfObject)])
  Stream(Ref[(PdfObject, Stream)])
  Indirect(Int)
}

///|
/// Object data state during parsing or decryption.
pub enum ObjectData {
  Parsed(PdfObject)
  ParsedAlreadyDecrypted(PdfObject)
  ToParse
  ToParseFromObjectStream(
    Map[Int, Array[Int]],
    Int,
    Int,
    (Int, Array[Int]) -> Array[(Int, (Ref[ObjectData], Int))],
  )
}

///|
pub type PdfObjMapKey = Int

///|
pub type PdfObjMapEntry = (Ref[ObjectData], Int)

///|
pub type PdfObjMap = Map[PdfObjMapKey, PdfObjMapEntry]

///|
/// Container for document objects.
pub struct PdfObjects {
  mut max_obj_num : Int
  parse : ((PdfObjMapKey) -> PdfObject)?
  objects : PdfObjMap
  object_stream_ids : Map[Int, Int]
}

///|
/// In-memory PDF document.
pub struct Pdf {
  major : Int
  minor : Int
  root : Int
  objects : PdfObjects
  mut trailerdict : PdfObject
  was_linearized : Bool
  saved_encryption : SavedEncryption?
}

///|
pub fn pdfobjmap_empty() -> PdfObjMap {
  Map::new()
}

///|
pub fn pdfobjmap_find(key : PdfObjMapKey, map : PdfObjMap) -> PdfObjMapEntry raise {
  match map.get(key) {
    Some(entry) => entry
    None => fail("Not_found")
  }
}

///|
pub fn pdfobjmap_add(key : PdfObjMapKey, entry : PdfObjMapEntry, map : PdfObjMap) -> PdfObjMap {
  map.set(key, entry)
  map
}

///|
pub fn pdfobjmap_remove(key : PdfObjMapKey, map : PdfObjMap) -> PdfObjMap {
  map.remove(key)
  map
}

///|
pub fn pdfobjmap_bindings(map : PdfObjMap) -> Array[(PdfObjMapKey, PdfObjMapEntry)] {
  map.to_array()
}

///|
/// The empty document (PDF 2.0, no objects, no root, empty trailer dictionary).
pub fn empty() -> Pdf {
  {
    major : 2,
    minor : 0,
    root : 0,
    objects : {
      max_obj_num : 0,
      parse : None,
      objects : pdfobjmap_empty(),
      object_stream_ids : Map::new(),
    },
    trailerdict : Dictionary([]),
    was_linearized : false,
    saved_encryption : None,
  }
}

///|
/// Build an error string which includes the input source and position.
pub fn input_pdferror(input : @pdfio.Input, message : String) -> String {
  "\{message} whilst reading file \{input.source} at position \{(input.pos_in)()}"
}

///|
/// Remove a dictionary entry (also works for streams).
pub fn remove_dict_entry(dict : PdfObject, key : String) -> PdfObject raise {
  match dict {
    Dictionary(entries) => {
      let out = entries.filter((pair) => pair.0 != key)
      Dictionary(out)
    }
    Stream(r) => {
      let (inner, stream) = r.val
      r.val = (remove_dict_entry(inner, key), stream)
      Stream(r)
    }
    _ => raise PdfError::Msg("remove_dict_entry: not a dictionary")
  }
}

///|
/// Replace a dictionary entry, raising if it's not present (also works for streams).
pub fn replace_dict_entry(dict : PdfObject, key : String, value : PdfObject) -> PdfObject raise {
  match dict {
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
        raise PdfError::Msg("replace_dict_entry: key not found")
      }
      Dictionary(out)
    }
    Stream(r) => {
      let (inner, stream) = r.val
      r.val = (replace_dict_entry(inner, key, value), stream)
      Stream(r)
    }
    _ => raise PdfError::Msg("replace_dict_entry: not a dictionary")
  }
}

///|
/// Add a dictionary entry, replacing if already present (also works for streams).
pub fn add_dict_entry(dict : PdfObject, key : String, value : PdfObject) -> PdfObject raise {
  match dict {
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
      r.val = (add_dict_entry(inner, key, value), stream)
      Stream(r)
    }
    _ => raise PdfError::Msg("add_dict_entry: not a dictionary")
  }
}

///|
/// Lookup an object in a document, parsing it if required.
pub fn lookup_obj(pdf : Pdf, objnum : Int) -> PdfObject {
  match pdf.objects.objects.get(objnum) {
    None => Null
    Some((obj_ref, _gen)) => {
      match obj_ref.val {
        Parsed(obj) | ParsedAlreadyDecrypted(obj) => obj
        ToParse => {
          match pdf.objects.parse {
            None => Null
            Some(parser) => {
              let obj = parser(objnum)
              obj_ref.val = Parsed(obj)
              obj
            }
          }
        }
        ToParseFromObjectStream(_, _, _, _) => Null
      }
    }
  }
}

///|
/// Make a PDF object direct -- that is, follow any indirect links.
pub fn direct(pdf : Pdf, obj : PdfObject) -> PdfObject {
  match obj {
    Indirect(i) => direct(pdf, lookup_obj(pdf, i))
    _ => obj
  }
}

///|
/// Lookup the key, resolving indirections at source and destination.
pub fn lookup_direct(pdf : Pdf, key : String, dict : PdfObject) -> PdfObject? {
  let dict_obj = direct(pdf, dict)
  let entry =
    match dict_obj {
      Dictionary(entries) => {
        match entries.search_by((pair) => pair.0 == key) {
          None => None
          Some(i) => Some(entries[i].1)
        }
      }
      Stream(r) => {
        let (inner, _) = r.val
        match inner {
          Dictionary(entries) =>
            match entries.search_by((pair) => pair.0 == key) {
              None => None
              Some(i) => Some(entries[i].1)
            }
          _ => None
        }
      }
      _ => None
    }
  match entry {
    None => None
    Some(value) => Some(direct(pdf, value))
  }
}

///|
/// Lookup the key without following indirects at either source or destination.
pub fn lookup_immediate(key : String, dict : PdfObject) -> PdfObject? {
  match dict {
    Dictionary(entries) => {
      match entries.search_by((pair) => pair.0 == key) {
        None => None
        Some(i) => Some(entries[i].1)
      }
    }
    Stream(r) => {
      let (inner, _) = r.val
      match inner {
        Dictionary(entries) =>
          match entries.search_by((pair) => pair.0 == key) {
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
/// Lookup a key in a nested dictionary chain.
pub fn lookup_chain(pdf : Pdf, start : PdfObject, keys : ArrayView[String]) -> PdfObject? {
  let mut current = start
  for key in keys {
    match lookup_direct(pdf, key, current) {
      None => return None
      Some(next) => current = next
    }
  }
  Some(current)
}

///|
/// Replace or insert a chain from the trailer dictionary.
pub fn replace_chain(pdf : Pdf, chain : ArrayView[String], obj : PdfObject) -> Unit raise {
  fn replace_in_obj(
    pdf : Pdf,
    current : PdfObject,
    chain : ArrayView[String],
    obj : PdfObject
  ) -> PdfObject raise {
    if chain.length() == 0 {
      return obj
    }
    let key = chain[0]
    let rest = chain.sub(start=1)
    match current {
      Null => {
        let child = replace_in_obj(pdf, Dictionary([]), rest, obj)
        Dictionary([(key, child)])
      }
      Dictionary(entries) => {
        let mut found = false
        let out = Array::new(capacity=entries.length() + 1)
        for entry in entries {
          let (k, v) = entry
          if k == key {
            let child = replace_in_obj(pdf, v, rest, obj)
            out.push((k, child))
            found = true
          } else {
            out.push((k, v))
          }
        }
        if !found {
          let child = replace_in_obj(pdf, Dictionary([]), rest, obj)
          out.push((key, child))
        }
        Dictionary(out)
      }
      Stream(r) => {
        let (inner, stream) = r.val
        let updated = replace_in_obj(pdf, inner, chain, obj)
        r.val = (updated, stream)
        Stream(r)
      }
      _ => raise PdfError::Msg("replace_chain: not a dictionary")
    }
  }
  pdf.trailerdict = replace_in_obj(pdf, pdf.trailerdict, chain, obj)
}

///|
/// Remove the object at the given chain. Returns true if removed.
pub fn remove_chain(pdf : Pdf, chain : ArrayView[String]) -> Bool raise {
  fn remove_in_obj(current : PdfObject, chain : ArrayView[String]) -> (PdfObject, Bool) raise {
    if chain.length() == 0 {
      return (current, false)
    }
    let key = chain[0]
    let rest = chain.sub(start=1)
    match current {
      Dictionary(entries) => {
        let mut removed = false
        let out = Array::new(capacity=entries.length())
        for entry in entries {
          let (k, v) = entry
          if k == key {
            if rest.length() == 0 {
              removed = true
            } else {
              let (updated, child_removed) = remove_in_obj(v, rest)
              out.push((k, updated))
              removed = child_removed
            }
          } else {
            out.push((k, v))
          }
        }
        (Dictionary(out), removed)
      }
      Stream(r) => {
        let (inner, stream) = r.val
        let (updated, removed) = remove_in_obj(inner, chain)
        r.val = (updated, stream)
        (Stream(r), removed)
      }
      _ => raise PdfError::Msg("remove_chain: not a dictionary")
    }
  }
  let (updated, removed) = remove_in_obj(pdf.trailerdict, chain)
  pdf.trailerdict = updated
  removed
}

///|
/// Return the object number of an indirect dictionary object, if it is indirect.
pub fn indirect_number(pdf : Pdf, key : String, dict : PdfObject) -> Int? {
  match direct(pdf, dict) {
    Dictionary(entries) => {
      match entries.search_by((pair) => pair.0 == key) {
        None => None
        Some(i) => {
          match entries[i].1 {
            Indirect(objnum) => Some(objnum)
            _ => None
          }
        }
      }
    }
    Stream(r) => {
      let (inner, _) = r.val
      indirect_number(pdf, key, inner)
    }
    _ => None
  }
}

///|
/// Same as lookup_direct, but allow a second alternative key.
pub fn lookup_direct_orelse(pdf : Pdf, key : String, alt : String, dict : PdfObject) -> PdfObject? {
  match lookup_direct(pdf, key, dict) {
    Some(obj) => Some(obj)
    None => lookup_direct(pdf, alt, dict)
  }
}

///|
/// Get a stream from disk if it hasn't already been got.
pub fn getstream(obj : PdfObject) -> Unit raise {
  match obj {
    Stream(r) => {
      match r.val {
        (dict, Stream::ToGet(toget)) => {
          let data = @pdfio.bytes_of_input(toget.input, toget.position, toget.length)
          let dict_updated =
            match dict {
              Dictionary(_) => replace_dict_entry(dict, "/Length", Integer(@pdfio.bytes_size(data)))
              _ => dict
            }
          r.val = (dict_updated, Stream::Got(data))
        }
        _ => ()
      }
    }
    _ => raise PdfError::Msg("getstream: not a stream")
  }
}

///|
/// Return a float from a PDF number.
pub fn getnum(pdf : Pdf, obj : PdfObject) -> Double raise {
  match obj {
    Real(a) => a
    Integer(a) => Double::from_int(a)
    Indirect(i) => getnum(pdf, lookup_obj(pdf, i))
    _ => raise PdfError::Msg("getnum: not a number")
  }
}

///|
/// Parse a PDF rectangle structure into min x, min y, max x, max y.
pub fn parse_rectangle(pdf : Pdf, obj : PdfObject) -> (Double, Double, Double, Double) raise {
  match obj {
    Array(vals) =>
      if vals.length() == 4 {
        let x = getnum(pdf, vals[0])
        let y = getnum(pdf, vals[1])
        let x2 = getnum(pdf, vals[2])
        let y2 = getnum(pdf, vals[3])
        let min_x = if x < x2 { x } else { x2 }
        let min_y = if y < y2 { y } else { y2 }
        let max_x = if x > x2 { x } else { x2 }
        let max_y = if y > y2 { y } else { y2 }
        (min_x, min_y, max_x, max_y)
      } else {
        raise PdfError::Msg("parse_rectangle: expected 4 elements")
      }
    _ => raise PdfError::Msg("parse_rectangle: not an array")
  }
}

///|
/// Return the size of the object map.
pub fn objcard(pdf : Pdf) -> Int {
  pdf.objects.objects.length()
}

///|
/// Remove the given object.
pub fn removeobj(pdf : Pdf, objnum : Int) -> Unit {
  pdf.objects.objects.remove(objnum)
}

///|
/// Add an object. Returns the number chosen.
pub fn addobj(pdf : Pdf, obj : PdfObject) -> Int {
  let next = pdf.objects.max_obj_num + 1
  addobj_given_num(pdf, (next, obj))
  next
}

///|
/// Same as addobj, but pick a number ourselves.
pub fn addobj_given_num(pdf : Pdf, pair : (Int, PdfObject)) -> Unit {
  let (num, obj) = pair
  if num > pdf.objects.max_obj_num {
    pdf.objects.max_obj_num = num
  }
  pdf.objects.objects.set(num, ({ val: Parsed(obj) }, 0))
}

///|
/// Lookup an object, failing if not found.
pub fn lookup_fail(errtext : String, pdf : Pdf, key : String, dict : PdfObject) -> PdfObject raise {
  match lookup_direct(pdf, key, dict) {
    Some(obj) => obj
    None => raise PdfError::Msg(errtext)
  }
}

///|
/// Same as lookup_fail, but with a customized exception.
pub fn lookup_exception(err : Error, pdf : Pdf, key : String, dict : PdfObject) -> PdfObject raise {
  match lookup_direct(pdf, key, dict) {
    Some(obj) => obj
    None => raise err
  }
}
