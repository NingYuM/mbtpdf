///|
/// Core error used across the PDF surface.
pub(all) suberror PdfError {
  Msg(String)
}

///|
/// PDF whitespace predicate.
pub fn is_whitespace(c : Char) -> Bool {
  let v = c.to_int()
  v == 0 || v == 9 || v == 10 || v == 12 || v == 13 || v == 32
}

///|
/// Snapshot of encryption settings used for re-encryption.
pub type EncryptionValues = (
  @pdfcryptprimitives.Encryption,
  String,
  String,
  Int,
  String,
  String?,
  String?,
)

///|
/// Saved encryption metadata used by recrypt helpers.
pub(all) struct SavedEncryption {
  from_get_encryption_values : EncryptionValues
  encrypt_metadata : Bool
  perms : String
}

///|
/// Deferred crypt settings for stream materialization.
pub(all) struct DeferredEncryption {
  crypt_type : @pdfcryptprimitives.Encryption
  file_encryption_key : String?
  obj : Int
  gen : Int
  key : Array[Int]
  keylength : Int
  r : Int
}

///|
/// Indicates whether a stream needs decryption when materialized.
pub(all) enum ToGetCrypt {
  NoChange
  ToDecrypt(DeferredEncryption)
}

///|
/// Stream descriptor when bytes are not yet materialized.
pub(all) struct ToGet {
  input : @pdfio.Input
  position : Int
  length : Int
  crypt : ToGetCrypt
}

///|
pub fn ToGet::new(
  input : @pdfio.Input,
  position : Int,
  length : Int,
  crypt? : ToGetCrypt = ToGetCrypt::NoChange,
) -> ToGet {
  { input, position, length, crypt }
}

///|
pub fn ToGet::length(self : ToGet) -> Int {
  self.length
}

///|
/// Stream payload, either in memory or deferred.
pub(all) enum Stream {
  Got(@pdfio.MutableBytes)
  ToGet(ToGet)
}

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
  Dictionary(Array[(String, PdfObject)])
  Stream(Ref[(PdfObject, Stream)])
  Indirect(Int)
}

///|
/// Deferred stringification hook.
pub let string_of_pdf : Ref[(PdfObject) -> String] = Ref::new((_ : PdfObject) => "")

///|
/// Hook called after reading each page during PDF parsing.
pub let endpage : Ref[(Pdf) -> Int] = { val: _ => 0 }

///|
/// Object data state during parsing or decryption.
pub(all) enum ObjectData {
  Parsed(PdfObject)
  ParsedAlreadyDecrypted(PdfObject)
  ToParse
  ToParseFromObjectStream(
    Map[Int, Array[Int]],
    Int,
    Int,
    (Int, Array[Int]) -> Array[(Int, (Ref[ObjectData], Int))]
  )
}

///|
type PdfObjMapKey = Int

///|
type PdfObjMapEntry = (Ref[ObjectData], Int)

///|
pub type PdfObjMap = Map[Int, (Ref[ObjectData], Int)]

///|
/// Container for document objects.
pub(all) struct PdfObjects {
  mut max_obj_num : Int
  parse : ((PdfObjMapKey) -> PdfObject)?
  objects : PdfObjMap
  object_stream_ids : Map[Int, Int]
}

///|
/// In-memory PDF document.
pub(all) struct Pdf {
  major : Int
  minor : Int
  root : Int
  objects : PdfObjects
  mut trailerdict : PdfObject
  was_linearized : Bool
  mut saved_encryption : SavedEncryption?
}

///|
pub fn pdfobjmap_empty() -> PdfObjMap {
  Map::new()
}

///|
pub fn pdfobjmap_find(
  key : PdfObjMapKey,
  map : PdfObjMap,
) -> PdfObjMapEntry raise {
  match map.get(key) {
    Some(entry) => entry
    None => fail("Not_found")
  }
}

///|
pub fn pdfobjmap_bindings(
  map : PdfObjMap,
) -> Array[(PdfObjMapKey, PdfObjMapEntry)] {
  map.to_array()
}

///|
/// The empty document (PDF 2.0, no objects, no root, empty trailer dictionary).
pub fn Pdf::empty() -> Pdf {
  {
    major: 2,
    minor: 0,
    root: 0,
    objects: {
      max_obj_num: 0,
      parse: None,
      objects: pdfobjmap_empty(),
      object_stream_ids: Map::new(),
    },
    trailerdict: Dictionary([]),
    was_linearized: false,
    saved_encryption: None,
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
      let out = entries.filter(pair => pair.0 != key)
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
pub fn replace_dict_entry(
  dict : PdfObject,
  key : String,
  value : PdfObject,
) -> PdfObject raise {
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
pub fn add_dict_entry(
  dict : PdfObject,
  key : String,
  value : PdfObject,
) -> PdfObject raise {
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
    Some((obj_ref, _gen)) =>
      match obj_ref.val {
        Parsed(obj) | ParsedAlreadyDecrypted(obj) => obj
        ToParse =>
          match pdf.objects.parse {
            None => Null
            Some(parser) => {
              let obj = parser(objnum)
              obj_ref.val = Parsed(obj)
              obj
            }
          }
        ToParseFromObjectStream(themap, streamobjnum, _index, objstreamparser) =>
          parse_delayed_object_stream(
            themap, objnum, streamobjnum, pdf, objstreamparser,
          )
      }
  }
}

///|
fn parse_delayed_object_stream(
  themap : Map[Int, Array[Int]],
  objnum : Int,
  streamobjnum : Int,
  pdf : Pdf,
  parser : (Int, Array[Int]) -> Array[(Int, (Ref[ObjectData], Int))],
) -> PdfObject {
  let indexes = match themap.get(objnum) {
    Some(value) => value
    None => return Null
  }
  let objects_from_stream = parser(streamobjnum, indexes)
  let mut found = false
  for pair in objects_from_stream {
    if pair.0 == objnum {
      found = true
    }
    pdf.objects.objects.set(pair.0, pair.1)
  }
  removeobj(pdf, streamobjnum)
  if found {
    lookup_obj(pdf, objnum)
  } else {
    Null
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
  let entry = match dict_obj {
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
  match entry {
    None => None
    Some(value) => Some(direct(pdf, value))
  }
}

///|
/// Lookup the key without following indirects at either source or destination.
pub fn lookup_immediate(key : String, dict : PdfObject) -> PdfObject? {
  match dict {
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
/// Parse array index keys of the form "/[<digits>]".
fn array_index_from_key(key : String) -> Int? {
  if !key.has_prefix("/[") {
    return None
  }
  let rest = try key[2:] catch {
    _ => return None
  } noraise {
    view => view
  }
  let mut value = 0
  let mut seen = false
  for ch in rest {
    if ch >= '0' && ch <= '9' {
      value = value * 10 + (ch.to_int() - '0'.to_int())
      seen = true
    } else {
      break
    }
  }
  if seen {
    Some(value)
  } else {
    None
  }
}

///|
/// Lookup a key, allowing array index chains.
fn lookup_direct_or_array(
  pdf : Pdf,
  key : String,
  obj : PdfObject,
) -> PdfObject? {
  match array_index_from_key(key) {
    Some(index) =>
      match obj {
        Array(items) => Some(direct(pdf, items[index]))
        _ => None
      }
    None => lookup_direct(pdf, key, obj)
  }
}

///|
/// Lookup a key in a nested dictionary chain.
pub fn lookup_chain(
  pdf : Pdf,
  start : PdfObject,
  keys : ArrayView[String],
) -> PdfObject? {
  let mut current = start
  for key in keys {
    match lookup_direct_or_array(pdf, key, current) {
      None => return None
      Some(next) => current = next
    }
  }
  Some(current)
}

///|
/// Replace or insert a chain from the trailer dictionary.
pub fn replace_chain(
  pdf : Pdf,
  chain : ArrayView[String],
  obj : PdfObject,
) -> Unit raise {
  fn replace_in_obj(
    pdf : Pdf,
    current : PdfObject,
    chain : ArrayView[String],
    obj : PdfObject,
  ) -> PdfObject raise {
    if chain.length() == 0 {
      return obj
    }
    let key = chain[0]
    let rest = chain.sub(start=1)
    match array_index_from_key(key) {
      Some(index) =>
        match current {
          Array(items) => {
            if index < 0 || index >= items.length() {
              raise PdfError::Msg("replace_chain: array index out of range")
            }
            let updated = if rest.length() == 0 {
              obj
            } else {
              replace_in_obj(pdf, items[index], rest, obj)
            }
            let out = items.copy()
            out[index] = updated
            Array(out)
          }
          _ => raise PdfError::Msg("replace_chain: bad array chain")
        }
      None =>
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
  }

  pdf.trailerdict = replace_in_obj(pdf, pdf.trailerdict, chain, obj)
}

///|
/// Return the object number of an indirect dictionary object, if it is indirect.
pub fn indirect_number(pdf : Pdf, key : String, dict : PdfObject) -> Int? {
  match direct(pdf, dict) {
    Dictionary(entries) =>
      match entries.search_by(pair => pair.0 == key) {
        None => None
        Some(i) =>
          match entries[i].1 {
            Indirect(objnum) => Some(objnum)
            _ => None
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
pub fn lookup_direct_orelse(
  pdf : Pdf,
  key : String,
  alt : String,
  dict : PdfObject,
) -> PdfObject? {
  match lookup_direct(pdf, key, dict) {
    Some(obj) => Some(obj)
    None => lookup_direct(pdf, alt, dict)
  }
}

///|
/// Name tree helpers.
fn compare_string(a : String, b : String) -> Int {
  let ac = a.to_array()
  let bc = b.to_array()
  let min_len = if ac.length() < bc.length() {
    ac.length()
  } else {
    bc.length()
  }
  for i in 0..<min_len {
    if ac[i] != bc[i] {
      return ac[i].to_int() - bc[i].to_int()
    }
  }
  ac.length() - bc.length()
}

///|
fn key_compare(a : PdfObject, b : PdfObject) -> Int? {
  match (a, b) {
    (String(sa), String(sb)) => Some(compare_string(sa, sb))
    (Integer(ia), Integer(ib)) => Some(ia - ib)
    _ => None
  }
}

///|
fn key_eq(a : PdfObject, b : PdfObject) -> Bool {
  match key_compare(a, b) {
    Some(0) => true
    _ => false
  }
}

///|
fn array_lookup(key : PdfObject, array : PdfObject) -> PdfObject? raise {
  match array {
    Array(elts) => {
      for i = 0; i + 1 < elts.length(); i = i + 2 {
        if key_eq(key, elts[i]) {
          return Some(elts[i + 1])
        }
      }
      None
    }
    _ => raise PdfError::Msg("Bad lookup array")
  }
}

///|
fn nametree_lookup_kids(
  pdf : Pdf,
  key : PdfObject,
  kids : PdfObject,
) -> PdfObject? raise {
  match kids {
    Array(values) => {
      for kid in values {
        match nametree_lookup(pdf, key, kid) {
          Some(result) => return Some(result)
          None => ()
        }
      }
      None
    }
    _ => raise PdfError::Msg("nametree_lookup_kids: malformed name tree")
  }
}

///|
/// Look something up in a name tree.
pub fn nametree_lookup(
  pdf : Pdf,
  key : PdfObject,
  dict : PdfObject,
) -> PdfObject? raise {
  match lookup_direct(pdf, "/Limits", dict) {
    Some(Array([l, r])) => {
      match key_compare(key, l) {
        Some(cmp) if cmp < 0 => return None
        _ => ()
      }
      match key_compare(key, r) {
        Some(cmp) if cmp > 0 => return None
        _ => ()
      }
      match lookup_direct(pdf, "/Kids", dict) {
        Some(kids) => nametree_lookup_kids(pdf, key, kids)
        None =>
          match lookup_direct_orelse(pdf, "/Names", "/Nums", dict) {
            Some(names) => array_lookup(key, names)
            None => raise PdfError::Msg("Malformed name tree entry")
          }
      }
    }
    None =>
      match lookup_direct(pdf, "/Kids", dict) {
        Some(kids) => nametree_lookup_kids(pdf, key, kids)
        None =>
          match lookup_direct_orelse(pdf, "/Names", "/Nums", dict) {
            Some(names) => array_lookup(key, names)
            None => raise PdfError::Msg("Missing name tree entry")
          }
      }
    _ => raise PdfError::Msg("Malformed name tree")
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
/// Return an ordered list of all (k, v) pairs in a name tree.
pub fn contents_of_nametree(
  pdf : Pdf,
  tree : PdfObject,
) -> Array[(PdfObject, PdfObject)] raise {
  match lookup_direct_orelse(pdf, "/Names", "/Nums", tree) {
    Some(Array(names)) => {
      let out = Array::new()
      for i = 0; i + 1 < names.length(); i = i + 2 {
        out.push((names[i], names[i + 1]))
      }
      if names.length() % 2 == 1 {
        @pdfe.log("warning: contents_of_nametree: odd number of /Names\n")
      }
      out
    }
    _ =>
      match lookup_direct(pdf, "/Kids", tree) {
        Some(Array(kids)) =>
          flatten(kids.map(kid => contents_of_nametree(pdf, kid)))
        _ => raise PdfError::Msg("contents_of_nametree: neither names nor kids")
      }
  }
}

///|
/// Get a stream from disk if it hasn't already been got.
fn process_deferred_cryption(
  crypt : ToGetCrypt,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise {
  match crypt {
    ToGetCrypt::NoChange => data
    ToGetCrypt::ToDecrypt(saved) =>
      @pdfcryptprimitives.decrypt_stream_data(
        saved.crypt_type,
        false,
        saved.file_encryption_key,
        saved.obj,
        saved.gen,
        saved.key,
        saved.keylength,
        saved.r,
        data,
      )
  }
}

///|
/// Get a stream from disk if it hasn't already been got.
pub fn getstream(obj : PdfObject) -> Unit raise {
  match obj {
    Stream(r) =>
      match r.val {
        (dict, Stream::ToGet(toget)) => {
          let data = try {
            let raw = toget.input.bytes_of_input(toget.position, toget.length)
            process_deferred_cryption(toget.crypt, raw)
          } catch {
            _ => raise PdfError::Msg("getstream: can't read stream")
          }
          let dict_updated = match dict {
            Dictionary(_) =>
              replace_dict_entry(
                dict,
                "/Length",
                Integer(@pdfio.bytes_size(data)),
              )
            _ => dict
          }
          r.val = (dict_updated, Stream::Got(data))
        }
        _ => ()
      }
    _ => raise PdfError::Msg("getstream: not a stream")
  }
}

///|
/// Find the contents of a stream as bytes.
pub fn bigarray_of_stream(obj : PdfObject) -> @pdfio.MutableBytes raise {
  getstream(obj)
  match obj {
    Stream(r) =>
      match r.val {
        (_, Stream::Got(bytes)) => bytes
        _ => raise PdfError::Msg("couldn't extract raw stream")
      }
    _ => raise PdfError::Msg("couldn't extract raw stream")
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
pub fn parse_rectangle(
  pdf : Pdf,
  obj : PdfObject,
) -> (Double, Double, Double, Double) raise {
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
/// Parse a transform matrix, or return the identity if missing.
pub fn parse_matrix(
  pdf : Pdf,
  key : String,
  dict : PdfObject,
) -> @pdftransform.TransformMatrix raise {
  match lookup_direct(pdf, key, dict) {
    None | Some(Null) => @pdftransform.TransformMatrix::identity()
    Some(Array(vals)) =>
      if vals.length() != 6 {
        raise PdfError::Msg("Malformed matrix")
      } else {
        let a = getnum(pdf, vals[0])
        let b = getnum(pdf, vals[1])
        let c = getnum(pdf, vals[2])
        let d = getnum(pdf, vals[3])
        let e = getnum(pdf, vals[4])
        let f = getnum(pdf, vals[5])
        { a, b, c, d, e, f }
      }
    _ => raise PdfError::Msg("Malformed matrix")
  }
}

///|
/// Build a matrix object.
pub fn make_matrix(tr : @pdftransform.TransformMatrix) -> PdfObject {
  Array([Real(tr.a), Real(tr.b), Real(tr.c), Real(tr.d), Real(tr.e), Real(tr.f)])
}

///|
fn fmin(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn fmax(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Transform a rectangle by a matrix, returning the bounding rectangle.
pub fn transform_rect(
  pdf : Pdf,
  transform : @pdftransform.TransformMatrix,
  rect : PdfObject,
) -> PdfObject raise {
  let (minx, miny, maxx, maxy) = parse_rectangle(pdf, rect)
  let (x0, y0) = transform.apply((minx, miny))
  let (x1, y1) = transform.apply((maxx, maxy))
  let (x2, y2) = transform.apply((minx, maxy))
  let (x3, y3) = transform.apply((maxx, miny))
  let minx = fmin(fmin(x0, x1), fmin(x2, x3))
  let miny = fmin(fmin(y0, y1), fmin(y2, y3))
  let maxx = fmax(fmax(x0, x1), fmax(x2, x3))
  let maxy = fmax(fmax(y0, y1), fmax(y2, y3))
  Array([Real(minx), Real(miny), Real(maxx), Real(maxy)])
}

///|
fn transform_quadpoint_single(
  pdf : Pdf,
  transform : @pdftransform.TransformMatrix,
  qp : Array[PdfObject],
) -> Array[PdfObject] raise {
  if qp.length() != 8 {
    @pdfe.log("Malformed /QuadPoints format: must be a multiple of 8 entries\n")
    return qp
  }
  let x1 = getnum(pdf, qp[0])
  let y1 = getnum(pdf, qp[1])
  let x2 = getnum(pdf, qp[2])
  let y2 = getnum(pdf, qp[3])
  let x3 = getnum(pdf, qp[4])
  let y3 = getnum(pdf, qp[5])
  let x4 = getnum(pdf, qp[6])
  let y4 = getnum(pdf, qp[7])
  let (x1, y1) = transform.apply((x1, y1))
  let (x2, y2) = transform.apply((x2, y2))
  let (x3, y3) = transform.apply((x3, y3))
  let (x4, y4) = transform.apply((x4, y4))
  [
    Real(x1),
    Real(y1),
    Real(x2),
    Real(y2),
    Real(x3),
    Real(y3),
    Real(x4),
    Real(y4),
  ]
}

///|
fn[T] split_into(values : Array[T], size : Int) -> Array[Array[T]] {
  let out = Array::new()
  for i = 0; i < values.length(); i = i + size {
    let part = Array::new(capacity=size)
    for j in 0..<size {
      if i + j < values.length() {
        part.push(values[i + j])
      }
    }
    out.push(part)
  }
  out
}

///|
/// Transform quadpoints by a matrix.
pub fn transform_quadpoints(
  pdf : Pdf,
  transform : @pdftransform.TransformMatrix,
  qp : PdfObject,
) -> PdfObject raise {
  match qp {
    Array(qps) => {
      let out = Array::new()
      for chunk in split_into(qps, 8) {
        out.append(transform_quadpoint_single(pdf, transform, chunk))
      }
      Array(out)
    }
    _ => {
      @pdfe.log("Unknown or malformed /QuadPoints format\n")
      qp
    }
  }
}

///|
/// Return the size of the object map.
pub fn Pdf::objcard(self : Pdf) -> Int {
  self.objects.objects.length()
}

///|
/// Return the object numbers in ascending order.
pub fn Pdf::objnumbers(self : Pdf) -> Array[Int] {
  let entries = self.objects.objects.to_array()
  entries.sort_by((a, b) => a.0 - b.0)
  entries.map(pair => pair.0)
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
pub fn lookup_fail(
  errtext : String,
  pdf : Pdf,
  key : String,
  dict : PdfObject,
) -> PdfObject raise {
  match lookup_direct(pdf, key, dict) {
    Some(obj) => obj
    None => raise PdfError::Msg(errtext)
  }
}

///|
/// Find the indirect reference given by the value associated with a key.
pub fn find_indirect(key : String, dict : PdfObject) -> Int? raise {
  match dict {
    Dictionary(_) =>
      match lookup_immediate(key, dict) {
        Some(Indirect(i)) => Some(i)
        _ => None
      }
    _ => raise PdfError::Msg("find_indirect: not a dictionary")
  }
}

///|
/// Return the document catalog.
pub fn catalog_of_pdf(pdf : Pdf) -> PdfObject raise {
  let obj = lookup_obj(pdf, pdf.root)
  match obj {
    Null => raise PdfError::Msg("No catalog")
    _ => obj
  }
}

///|
/// Recursively rebuild an array.
pub fn recurse_array(
  f : (PdfObject) -> PdfObject,
  elts : Array[PdfObject],
) -> PdfObject {
  Array(elts.map(f))
}

///|
/// Recursively rebuild a dictionary.
fn recurse_dict(
  f : (PdfObject) -> PdfObject,
  elts : Array[(String, PdfObject)],
  preserve_order? : Bool = false,
) -> PdfObject {
  let _ = preserve_order
  let out = Array::new(capacity=elts.length())
  for entry in elts {
    out.push((entry.0, f(entry.1)))
  }
  Dictionary(out)
}

///|
/// Iterate over all objects in a document.
pub fn objiter(f : (Int, PdfObject) -> Unit raise?, pdf : Pdf) -> Unit raise? {
  let entries = pdf.objects.objects.to_array()
  entries.sort_by((a, b) => a.0 - b.0)
  for entry in entries {
    let key = entry.0
    f(key, lookup_obj(pdf, key))
  }
}

///|
/// Iterate over all objects in a document, ordered by object number.
pub fn objiter_inorder(
  f : (Int, PdfObject) -> Unit raise?,
  pdf : Pdf,
) -> Unit raise? {
  objiter(f, pdf)
}

///|
/// Iterate over all objects in a document with generation numbers.
pub fn objiter_gen(
  f : (Int, Int, PdfObject) -> Unit raise?,
  pdf : Pdf,
) -> Unit raise? {
  let entries = pdf.objects.objects.to_array()
  entries.sort_by((a, b) => a.0 - b.0)
  for entry in entries {
    let key = entry.0
    let (_obj_ref, gen) = entry.1
    f(key, gen, lookup_obj(pdf, key))
  }
}

///|
/// Map a function over all objects in a document.
pub fn objselfmap(
  f : (PdfObject) -> PdfObject raise?,
  pdf : Pdf,
) -> Unit raise? {
  let entries = pdf.objects.objects.to_array()
  entries.sort_by((a, b) => a.0 - b.0)
  for entry in entries {
    let key = entry.0
    let obj = lookup_obj(pdf, key)
    let updated = f(obj)
    let (obj_ref, _gen) = entry.1
    match obj_ref.val {
      ParsedAlreadyDecrypted(_) => obj_ref.val = ParsedAlreadyDecrypted(updated)
      _ => obj_ref.val = Parsed(updated)
    }
  }
}

///|
/// Select objects matching a predicate and return their numbers.
pub fn objselect(
  f : (PdfObject) -> Bool raise?,
  pdf : Pdf,
) -> Array[Int] raise? {
  let out = Array::new()
  objiter((num, obj) => if f(obj) { out.push(num) }, pdf)
  out
}

///|
fn refset_empty() -> Map[Int, Bool] {
  Map::new()
}

///|
fn refset_add(n : Int, rs : Map[Int, Bool]) -> Unit {
  rs.set(n, true)
}

///|
fn refset_mem(n : Int, rs : Map[Int, Bool]) -> Bool {
  rs.contains(n)
}

///|
fn refset_elts(rs : Map[Int, Bool]) -> Array[Int] {
  let out = Array::new()
  for key in rs.keys() {
    out.push(key)
  }
  out
}

///|
fn contains_string(xs : Array[String], key : String) -> Bool {
  for entry in xs {
    if entry == key {
      return true
    }
  }
  false
}

///|
fn dict_contains_name_entry(
  dict : Array[(String, PdfObject)],
  entry : (String, PdfObject),
) -> Bool {
  let (key, value) = entry
  match value {
    Name(name) => {
      for pair in dict {
        let (k, v) = pair
        match v {
          Name(vname) if k == key && vname == name => return true
          _ => ()
        }
      }
      false
    }
    _ => false
  }
}

///|
fn tocontinue(
  no_follow_entries : Array[String],
  no_follow_contains : Array[(String, PdfObject)],
  dict : Array[(String, PdfObject)],
) -> Bool {
  if no_follow_entries.length() == 0 && no_follow_contains.length() == 0 {
    return true
  }
  for entry in no_follow_contains {
    if dict_contains_name_entry(dict, entry) {
      return false
    }
  }
  true
}

///|
fn referenced_pdfobj(
  no_follow_entries : Array[String],
  no_follow_contains : Array[(String, PdfObject)],
  pdf : Pdf,
  found : Map[Int, Bool],
  obj : PdfObject,
) -> Unit {
  match obj {
    Indirect(j) =>
      if !refset_mem(j, found) {
        let target = lookup_obj(pdf, j)
        match target {
          Dictionary(d) =>
            if tocontinue(no_follow_entries, no_follow_contains, d) {
              refset_add(j, found)
              referenced_pdfobj(
                no_follow_entries, no_follow_contains, pdf, found, target,
              )
            }
          _ => {
            refset_add(j, found)
            referenced_pdfobj(
              no_follow_entries, no_follow_contains, pdf, found, target,
            )
          }
        }
      }
    Dictionary(d) =>
      for pair in d {
        let (k, v) = pair
        if no_follow_entries.length() == 0 ||
          !contains_string(no_follow_entries, k) {
          referenced_pdfobj(
            no_follow_entries, no_follow_contains, pdf, found, v,
          )
        }
      }
    Array(values) =>
      for value in values {
        referenced_pdfobj(
          no_follow_entries, no_follow_contains, pdf, found, value,
        )
      }
    Stream(r) => {
      let (dict, _) = r.val
      referenced_pdfobj(no_follow_entries, no_follow_contains, pdf, found, dict)
    }
    _ => ()
  }
}

///|
/// Find the objects reachable from the given object.
pub fn objects_referenced(
  no_follow_entries : Array[String],
  no_follow_contains : Array[(String, PdfObject)],
  pdf : Pdf,
  pdfobject : PdfObject,
) -> Array[Int] {
  let found = refset_empty()
  referenced_pdfobj(
    no_follow_entries, no_follow_contains, pdf, found, pdfobject,
  )
  refset_elts(found)
}

///|
fn nullify_deleted_page_references(pdf : Pdf) -> Unit raise {
  fn nullify(numbers : Map[Int, Bool], obj : PdfObject) -> PdfObject {
    match obj {
      Indirect(i) => if numbers.contains(i) { Null } else { obj }
      Array(elts) => recurse_array(v => nullify(numbers, v), elts)
      Dictionary(elts) => recurse_dict(v => nullify(numbers, v), elts)
      Stream(r) => {
        let (dict, stream) = r.val
        r.val = (nullify(numbers, dict), stream)
        Stream(r)
      }
      _ => obj
    }
  }

  let page_object_numbers = Array::new()
  objiter(
    (objnum, obj) => match obj {
      Dictionary(_) =>
        match lookup_direct(pdf, "/Type", obj) {
          Some(Name("/Page")) => page_object_numbers.push(objnum)
          _ => ()
        }
      _ => ()
    },
    pdf,
  )
  let refnums = page_reference_numbers(pdf)
  if refnums.length() != page_object_numbers.length() {
    let table = Map::new()
    for num in page_object_numbers {
      table.set(num, true)
    }
    for num in refnums {
      table.remove(num)
    }
    objselfmap(obj => nullify(table, obj), pdf)
  }
}

///|
/// Remove any unreferenced objects.
pub fn remove_unreferenced(pdf : Pdf) -> Unit raise {
  nullify_deleted_page_references(pdf)
  let found = refset_empty()
  referenced_pdfobj([], [], pdf, found, lookup_obj(pdf, pdf.root))
  referenced_pdfobj([], [], pdf, found, pdf.trailerdict)
  refset_add(pdf.root, found)
  let eltnumbers = refset_elts(found)
  let elements = eltnumbers.map(num => lookup_obj(pdf, num))
  pdf.objects.max_obj_num = 0
  pdf.objects.objects.clear()
  pdf.objects.object_stream_ids.clear()
  for i, num in eltnumbers {
    addobj_given_num(pdf, (num, elements[i]))
  }
}

///|
fn page_reference_numbers_inner(
  pdf : Pdf,
  pages_node : PdfObject,
  node_number : Int,
) -> Array[Int] {
  match lookup_direct(pdf, "/Type", pages_node) {
    Some(Name("/Page")) => [node_number]
    _ =>
      match lookup_direct(pdf, "/Kids", pages_node) {
        Some(Array(elts)) => {
          let out = Array::new()
          for elt in elts {
            match elt {
              Indirect(i) =>
                out.append(
                  page_reference_numbers_inner(pdf, direct(pdf, Indirect(i)), i)[:],
                )
              _ => ()
            }
          }
          out
        }
        _ => [node_number]
      }
  }
}

///|
/// Return the page reference numbers in order.
pub fn page_reference_numbers(pdf : Pdf) -> Array[Int] raise {
  let root = lookup_obj(pdf, pdf.root)
  let pages_node = match lookup_direct(pdf, "/Pages", root) {
    Some(p) => p
    None => raise PdfError::Msg("No /Pages found in /Root")
  }
  page_reference_numbers_inner(pdf, pages_node, -1)
}

///|
/// Renumber indirect references using a change table.
pub fn renumber_object_parsed(
  pdf : Pdf,
  changes : Map[Int, Int],
  obj : PdfObject,
  preserve_order? : Bool = false,
) -> PdfObject {
  let _ = pdf
  match obj {
    Indirect(i) =>
      match changes.get(i) {
        Some(x) => Indirect(x)
        None => Indirect(i)
      }
    Array(values) =>
      Array(
        values.map(v => renumber_object_parsed(pdf, changes, v, preserve_order~)),
      )
    Dictionary(entries) =>
      recurse_dict(
        v => renumber_object_parsed(pdf, changes, v, preserve_order~),
        entries,
        preserve_order~,
      )
    Stream(r) => {
      let (dict, stream) = r.val
      let dict_updated = renumber_object_parsed(
        pdf,
        changes,
        dict,
        preserve_order~,
      )
      r.val = (dict_updated, stream)
      Stream(r)
    }
    _ => obj
  }
}

///|
fn check_object_contains_renumbering(
  changes : Map[Int, Int],
  obj : PdfObject,
) -> Bool {
  match obj {
    Indirect(i) => changes.get(i) is Some(_)
    Array(values) =>
      values.any(v => check_object_contains_renumbering(changes, v))
    Dictionary(entries) =>
      entries.any(pair => check_object_contains_renumbering(changes, pair.1))
    Stream(r) => {
      let (dict, _) = r.val
      check_object_contains_renumbering(changes, dict)
    }
    _ => false
  }
}

///|
/// Calculate the change table required to renumber objects 1..n.
pub fn changes(pdf : Pdf) -> Map[Int, Int] {
  let keys = pdf.objnumbers()
  let table : Map[Int, Int] = Map::new(capacity=keys.length())
  let mut num = 1
  for key in keys {
    table.set(key, num)
    num = num + 1
  }
  table
}

///|
/// Renumber a PDF's objects using a change table.
pub fn renumber(
  change_table : Map[Int, Int],
  pdf : Pdf,
  preserve_order? : Bool = false,
) -> Pdf {
  let root = match change_table.get(pdf.root) {
    Some(value) => value
    None => pdf.root
  }
  let trailerdict = if check_object_contains_renumbering(
      change_table,
      pdf.trailerdict,
    ) {
    renumber_object_parsed(pdf, change_table, pdf.trailerdict, preserve_order~)
  } else {
    pdf.trailerdict
  }
  let entries = pdf.objects.objects.to_array()
  entries.sort_by((a, b) => a.0 - b.0)
  let objects : PdfObjMap = Map::new(capacity=entries.length())
  let mut max_obj_num = 0
  for entry in entries {
    let old_num = entry.0
    let new_num = match change_table.get(old_num) {
      Some(value) => value
      None => old_num
    }
    let obj = lookup_obj(pdf, old_num)
    let updated = if check_object_contains_renumbering(change_table, obj) {
      renumber_object_parsed(pdf, change_table, obj, preserve_order~)
    } else {
      obj
    }
    objects.set(new_num, ({ val: ObjectData::Parsed(updated) }, 0))
    if new_num > max_obj_num {
      max_obj_num = new_num
    }
  }
  let object_stream_ids = Map::new()
  for key, value in pdf.objects.object_stream_ids {
    match change_table.get(key) {
      Some(new_key) => object_stream_ids.set(new_key, value)
      None => ()
    }
  }
  {
    major: pdf.major,
    minor: pdf.minor,
    root,
    objects: {
      max_obj_num,
      parse: pdf.objects.parse,
      objects,
      object_stream_ids,
    },
    trailerdict,
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
}

///|
/// Renumber a list of PDFs so their object numbers are mutually exclusive.
pub fn renumber_pdfs(pdfs : Array[Pdf]) -> Array[Pdf] {
  let out = Array::new(capacity=pdfs.length())
  let mut base = 1
  for pdf in pdfs {
    let keys = pdf.objnumbers()
    let changes : Map[Int, Int] = Map::new(capacity=keys.length())
    let mut i = 0
    for key in keys {
      changes.set(key, base + i)
      i = i + 1
    }
    base = base + keys.length()
    out.push(renumber(changes, pdf))
  }
  out
}

///|
fn copy_bytes(bytes : @pdfio.MutableBytes) -> @pdfio.MutableBytes {
  let out = Array::new(capacity=bytes.length())
  out.append(bytes[:])
  out
}

///|
fn deep_copy_pdfobject(obj : PdfObject) -> PdfObject {
  match obj {
    Array(values) => Array(values.map(v => deep_copy_pdfobject(v)))
    Dictionary(entries) =>
      Dictionary(entries.map(pair => (pair.0, deep_copy_pdfobject(pair.1))))
    Stream(r) => {
      let (dict, stream) = r.val
      let dict_copy = deep_copy_pdfobject(dict)
      let stream_copy = match stream {
        Stream::Got(bytes) => Stream::Got(copy_bytes(bytes))
        Stream::ToGet(toget) => Stream::ToGet(toget)
      }
      Stream(Ref::new((dict_copy, stream_copy)))
    }
    _ => obj
  }
}

///|
fn deep_copy_objdata(objdata : ObjectData) -> ObjectData {
  match objdata {
    Parsed(obj) => Parsed(deep_copy_pdfobject(obj))
    ParsedAlreadyDecrypted(obj) =>
      ParsedAlreadyDecrypted(deep_copy_pdfobject(obj))
    ToParse => ToParse
    ToParseFromObjectStream(themap, x, y, func) =>
      ToParseFromObjectStream(themap, x, y, func)
  }
}

///|
fn deep_copy_pdfobjects(from : Pdf) -> PdfObjMap {
  let out = pdfobjmap_empty()
  for objnum, entry in from.objects.objects {
    let (obj_ref, gen) = entry
    out.set(objnum, (Ref::new(deep_copy_objdata(obj_ref.val)), gen))
  }
  out
}

///|
/// Create a deep copy of a PDF document.
pub fn deep_copy(from : Pdf) -> Pdf {
  let object_stream_ids = Map::new()
  for key, value in from.objects.object_stream_ids {
    object_stream_ids.set(key, value)
  }
  {
    major: from.major,
    minor: from.minor,
    root: from.root,
    objects: {
      max_obj_num: from.objects.max_obj_num,
      parse: from.objects.parse,
      objects: deep_copy_pdfobjects(from),
      object_stream_ids,
    },
    trailerdict: deep_copy_pdfobject(from.trailerdict),
    was_linearized: from.was_linearized,
    saved_encryption: from.saved_encryption,
  }
}

///|

///|
/// Generate an /ID entry for a document.
pub fn generate_id(
  pdf : Pdf,
  path : String,
  gettime : () -> Double,
) -> PdfObject {
  let _ = pdf
  let stamp = gettime().to_string()
  let id = path + stamp
  PdfObject::Array([PdfObject::String(id), PdfObject::String(id)])
}

///|
/// Replace the /ID entry in the trailer dictionary.
pub fn change_id(pdf : Pdf, path : String) -> Unit raise {
  match pdf.trailerdict {
    Dictionary(_) =>
      pdf.trailerdict = add_dict_entry(
        pdf.trailerdict,
        "/ID",
        generate_id(pdf, path, () => @env.now().to_double()),
      )
    _ => raise PdfError::Msg("Bad trailer dictionary")
  }
}
