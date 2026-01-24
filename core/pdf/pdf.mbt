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
/// Lookup an object in a document, parsing it if required.
#as_free_fn(lookup_obj, deprecated="Use Pdf::lookup_obj instead")
pub fn Pdf::lookup_obj(self : Pdf, objnum : Int) -> PdfObject {
  match self.objects.objects.get(objnum) {
    None => Null
    Some((obj_ref, _gen)) =>
      match obj_ref.val {
        Parsed(obj) | ParsedAlreadyDecrypted(obj) => obj
        ToParse =>
          match self.objects.parse {
            None => Null
            Some(parser) => {
              let obj = parser(objnum)
              obj_ref.val = Parsed(obj)
              obj
            }
          }
        ToParseFromObjectStream(themap, streamobjnum, _index, objstreamparser) =>
          self.parse_delayed_object_stream(
            themap, objnum, streamobjnum, objstreamparser,
          )
      }
  }
}

///|
fn Pdf::parse_delayed_object_stream(
  self : Pdf,
  themap : Map[Int, Array[Int]],
  objnum : Int,
  streamobjnum : Int,
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
    self.objects.objects.set(pair.0, pair.1)
  }
  self.removeobj(streamobjnum)
  if found {
    self.lookup_obj(objnum)
  } else {
    Null
  }
}

///|
/// Make a PDF object direct -- that is, follow any indirect links.
#as_free_fn(direct, deprecated="Use Pdf::direct instead")
pub fn Pdf::direct(self : Pdf, obj : PdfObject) -> PdfObject {
  match obj {
    Indirect(i) => self.direct(self.lookup_obj(i))
    _ => obj
  }
}

///|
/// Lookup the key, resolving indirections at source and destination.
#as_free_fn(lookup_direct, deprecated="Use Pdf::lookup_direct instead")
pub fn Pdf::lookup_direct(
  self : Pdf,
  key : String,
  dict : PdfObject,
) -> PdfObject? {
  let dict_obj = self.direct(dict)
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
    Some(value) => Some(self.direct(value))
  }
}

///|
/// Lookup the key without following indirects at either source or destination.
#as_free_fn(lookup_immediate, deprecated="Use PdfObject::lookup_immediate instead")
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
fn Pdf::lookup_direct_or_array(
  self : Pdf,
  key : String,
  obj : PdfObject,
) -> PdfObject? {
  match array_index_from_key(key) {
    Some(index) =>
      match obj {
        Array(items) => Some(self.direct(items[index]))
        _ => None
      }
    None => self.lookup_direct(key, obj)
  }
}

///|
/// Lookup a key in a nested dictionary chain.
#as_free_fn(lookup_chain, deprecated="Use Pdf::lookup_chain instead")
pub fn Pdf::lookup_chain(
  self : Pdf,
  start : PdfObject,
  keys : ArrayView[String],
) -> PdfObject? {
  let mut current = start
  for key in keys {
    match self.lookup_direct_or_array(key, current) {
      None => return None
      Some(next) => current = next
    }
  }
  Some(current)
}

///|
/// Replace or insert a chain from the trailer dictionary.
#as_free_fn(replace_chain, deprecated="Use Pdf::replace_chain instead")
pub fn Pdf::replace_chain(
  self : Pdf,
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

  self.trailerdict = replace_in_obj(self, self.trailerdict, chain, obj)
}

///|
/// Return the object number of an indirect dictionary object, if it is indirect.
#as_free_fn(indirect_number, deprecated="Use Pdf::indirect_number instead")
pub fn Pdf::indirect_number(self : Pdf, key : String, dict : PdfObject) -> Int? {
  match self.direct(dict) {
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
      self.indirect_number(key, inner)
    }
    _ => None
  }
}

///|
/// Same as lookup_direct, but allow a second alternative key.
#as_free_fn(lookup_direct_orelse, deprecated="Use Pdf::lookup_direct_orelse instead")
pub fn Pdf::lookup_direct_orelse(
  self : Pdf,
  key : String,
  alt : String,
  dict : PdfObject,
) -> PdfObject? {
  match self.lookup_direct(key, dict) {
    Some(obj) => Some(obj)
    None => self.lookup_direct(alt, dict)
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
fn Pdf::nametree_lookup_kids(
  self : Pdf,
  key : PdfObject,
  kids : PdfObject,
) -> PdfObject? raise {
  match kids {
    Array(values) => {
      for kid in values {
        match self.nametree_lookup(key, kid) {
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
#as_free_fn(nametree_lookup, deprecated="Use Pdf::nametree_lookup instead")
pub fn Pdf::nametree_lookup(
  self : Pdf,
  key : PdfObject,
  dict : PdfObject,
) -> PdfObject? raise {
  match self.lookup_direct("/Limits", dict) {
    Some(Array([l, r])) => {
      match key_compare(key, l) {
        Some(cmp) if cmp < 0 => return None
        _ => ()
      }
      match key_compare(key, r) {
        Some(cmp) if cmp > 0 => return None
        _ => ()
      }
      match self.lookup_direct("/Kids", dict) {
        Some(kids) => self.nametree_lookup_kids(key, kids)
        None =>
          match self.lookup_direct_orelse("/Names", "/Nums", dict) {
            Some(names) => array_lookup(key, names)
            None => raise PdfError::Msg("Malformed name tree entry")
          }
      }
    }
    None =>
      match self.lookup_direct("/Kids", dict) {
        Some(kids) => self.nametree_lookup_kids(key, kids)
        None =>
          match self.lookup_direct_orelse("/Names", "/Nums", dict) {
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
#as_free_fn(contents_of_nametree, deprecated="Use Pdf::contents_of_nametree instead")
pub fn Pdf::contents_of_nametree(
  self : Pdf,
  tree : PdfObject,
) -> Array[(PdfObject, PdfObject)] raise {
  match self.lookup_direct_orelse("/Names", "/Nums", tree) {
    Some(Array(names)) => {
      let out = Array::new()
      for i = 0; i + 1 < names.length(); i = i + 2 {
        out.push((names[i], names[i + 1]))
      }
      if names.length() % 2 == 1 {
        @pdfe.Pdfe::new().log(
          "warning: contents_of_nametree: odd number of /Names\n",
        )
      }
      out
    }
    _ =>
      match self.lookup_direct("/Kids", tree) {
        Some(Array(kids)) =>
          flatten(kids.map(kid => self.contents_of_nametree(kid)))
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
      @pdfcryptprimitives.PdfCryptPrimitives::new().decrypt_stream_data(
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
#as_free_fn(getstream, deprecated="Use PdfObject::getstream instead")
pub fn PdfObject::getstream(self : PdfObject) -> Unit raise {
  match self {
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
              dict.replace_entry("/Length", Integer(@pdfio.bytes_size(data)))
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
#as_free_fn(bigarray_of_stream, deprecated="Use PdfObject::bigarray_of_stream instead")
pub fn PdfObject::bigarray_of_stream(
  self : PdfObject,
) -> @pdfio.MutableBytes raise {
  self.getstream()
  match self {
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
#as_free_fn(getnum, deprecated="Use Pdf::getnum instead")
pub fn Pdf::getnum(self : Pdf, obj : PdfObject) -> Double raise {
  match obj {
    Real(a) => a
    Integer(a) => Double::from_int(a)
    Indirect(i) => self.getnum(self.lookup_obj(i))
    _ => raise PdfError::Msg("getnum: not a number")
  }
}

///|
/// Parse a PDF rectangle structure into min x, min y, max x, max y.
#as_free_fn(parse_rectangle, deprecated="Use Pdf::parse_rectangle instead")
pub fn Pdf::parse_rectangle(
  self : Pdf,
  obj : PdfObject,
) -> (Double, Double, Double, Double) raise {
  match obj {
    Array(vals) =>
      if vals.length() == 4 {
        let x = self.getnum(vals[0])
        let y = self.getnum(vals[1])
        let x2 = self.getnum(vals[2])
        let y2 = self.getnum(vals[3])
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
#as_free_fn(parse_matrix, deprecated="Use Pdf::parse_matrix instead")
pub fn Pdf::parse_matrix(
  self : Pdf,
  key : String,
  dict : PdfObject,
) -> @pdftransform.TransformMatrix raise {
  match self.lookup_direct(key, dict) {
    None | Some(Null) => @pdftransform.TransformMatrix::identity()
    Some(Array(vals)) =>
      if vals.length() != 6 {
        raise PdfError::Msg("Malformed matrix")
      } else {
        let a = self.getnum(vals[0])
        let b = self.getnum(vals[1])
        let c = self.getnum(vals[2])
        let d = self.getnum(vals[3])
        let e = self.getnum(vals[4])
        let f = self.getnum(vals[5])
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
#as_free_fn(transform_rect, deprecated="Use Pdf::transform_rect instead")
pub fn Pdf::transform_rect(
  self : Pdf,
  transform : @pdftransform.TransformMatrix,
  rect : PdfObject,
) -> PdfObject raise {
  let (minx, miny, maxx, maxy) = self.parse_rectangle(rect)
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
fn Pdf::transform_quadpoint_single(
  self : Pdf,
  transform : @pdftransform.TransformMatrix,
  qp : Array[PdfObject],
) -> Array[PdfObject] raise {
  if qp.length() != 8 {
    @pdfe.Pdfe::new().log(
      "Malformed /QuadPoints format: must be a multiple of 8 entries\n",
    )
    return qp
  }
  let x1 = self.getnum(qp[0])
  let y1 = self.getnum(qp[1])
  let x2 = self.getnum(qp[2])
  let y2 = self.getnum(qp[3])
  let x3 = self.getnum(qp[4])
  let y3 = self.getnum(qp[5])
  let x4 = self.getnum(qp[6])
  let y4 = self.getnum(qp[7])
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
#as_free_fn(transform_quadpoints, deprecated="Use Pdf::transform_quadpoints instead")
pub fn Pdf::transform_quadpoints(
  self : Pdf,
  transform : @pdftransform.TransformMatrix,
  qp : PdfObject,
) -> PdfObject raise {
  match qp {
    Array(qps) => {
      let out = Array::new()
      for chunk in split_into(qps, 8) {
        out.append(self.transform_quadpoint_single(transform, chunk))
      }
      Array(out)
    }
    _ => {
      @pdfe.Pdfe::new().log("Unknown or malformed /QuadPoints format\n")
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
#as_free_fn(removeobj, deprecated="Use Pdf::removeobj instead")
pub fn Pdf::removeobj(self : Pdf, objnum : Int) -> Unit {
  self.objects.objects.remove(objnum)
}

///|
/// Add an object. Returns the number chosen.
#as_free_fn(addobj, deprecated="Use Pdf::addobj instead")
pub fn Pdf::addobj(self : Pdf, obj : PdfObject) -> Int {
  let next = self.objects.max_obj_num + 1
  self.addobj_given_num((next, obj))
  next
}

///|
/// Same as addobj, but pick a number ourselves.
#as_free_fn(addobj_given_num, deprecated="Use Pdf::addobj_given_num instead")
pub fn Pdf::addobj_given_num(self : Pdf, pair : (Int, PdfObject)) -> Unit {
  let (num, obj) = pair
  if num > self.objects.max_obj_num {
    self.objects.max_obj_num = num
  }
  self.objects.objects.set(num, ({ val: Parsed(obj) }, 0))
}

///|
/// Lookup an object, failing if not found.
#as_free_fn(lookup_fail, deprecated="Use Pdf::lookup_fail instead")
pub fn Pdf::lookup_fail(
  self : Pdf,
  errtext : String,
  key : String,
  dict : PdfObject,
) -> PdfObject raise {
  match self.lookup_direct(key, dict) {
    Some(obj) => obj
    None => raise PdfError::Msg(errtext)
  }
}

///|
/// Find the indirect reference given by the value associated with a key.
#as_free_fn(find_indirect, deprecated="Use PdfObject::find_indirect instead")
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

///|
/// Return the document catalog.
#as_free_fn(catalog_of_pdf, deprecated="Use Pdf::catalog_of_pdf instead")
pub fn Pdf::catalog_of_pdf(self : Pdf) -> PdfObject raise {
  let obj = self.lookup_obj(self.root)
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
#as_free_fn(objiter, deprecated="Use Pdf::objiter instead")
pub fn Pdf::objiter(
  self : Pdf,
  f : (Int, PdfObject) -> Unit raise?,
) -> Unit raise? {
  let entries = self.objects.objects.to_array()
  entries.sort_by((a, b) => a.0 - b.0)
  for entry in entries {
    let key = entry.0
    f(key, self.lookup_obj(key))
  }
}

///|
/// Iterate over all objects in a document, ordered by object number.
#as_free_fn(objiter_inorder, deprecated="Use Pdf::objiter_inorder instead")
pub fn Pdf::objiter_inorder(
  self : Pdf,
  f : (Int, PdfObject) -> Unit raise?,
) -> Unit raise? {
  self.objiter(f)
}

///|
/// Iterate over all objects in a document with generation numbers.
#as_free_fn(objiter_gen, deprecated="Use Pdf::objiter_gen instead")
pub fn Pdf::objiter_gen(
  self : Pdf,
  f : (Int, Int, PdfObject) -> Unit raise?,
) -> Unit raise? {
  let entries = self.objects.objects.to_array()
  entries.sort_by((a, b) => a.0 - b.0)
  for entry in entries {
    let key = entry.0
    let (_obj_ref, gen) = entry.1
    f(key, gen, self.lookup_obj(key))
  }
}

///|
/// Map a function over all objects in a document.
#as_free_fn(objselfmap, deprecated="Use Pdf::objselfmap instead")
pub fn Pdf::objselfmap(
  self : Pdf,
  f : (PdfObject) -> PdfObject raise?,
) -> Unit raise? {
  let entries = self.objects.objects.to_array()
  entries.sort_by((a, b) => a.0 - b.0)
  for entry in entries {
    let key = entry.0
    let obj = self.lookup_obj(key)
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
#as_free_fn(objselect, deprecated="Use Pdf::objselect instead")
pub fn Pdf::objselect(
  self : Pdf,
  f : (PdfObject) -> Bool raise?,
) -> Array[Int] raise? {
  let out = Array::new()
  self.objiter((num, obj) => if f(obj) { out.push(num) })
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
fn Pdf::referenced_pdfobj(
  self : Pdf,
  no_follow_entries : Array[String],
  no_follow_contains : Array[(String, PdfObject)],
  found : Map[Int, Bool],
  obj : PdfObject,
) -> Unit {
  match obj {
    Indirect(j) =>
      if !refset_mem(j, found) {
        let target = self.lookup_obj(j)
        match target {
          Dictionary(d) =>
            if tocontinue(no_follow_entries, no_follow_contains, d) {
              refset_add(j, found)
              self.referenced_pdfobj(
                no_follow_entries, no_follow_contains, found, target,
              )
            }
          _ => {
            refset_add(j, found)
            self.referenced_pdfobj(
              no_follow_entries, no_follow_contains, found, target,
            )
          }
        }
      }
    Dictionary(d) =>
      for pair in d {
        let (k, v) = pair
        if no_follow_entries.length() == 0 ||
          !contains_string(no_follow_entries, k) {
          self.referenced_pdfobj(
            no_follow_entries, no_follow_contains, found, v,
          )
        }
      }
    Array(values) =>
      for value in values {
        self.referenced_pdfobj(
          no_follow_entries, no_follow_contains, found, value,
        )
      }
    Stream(r) => {
      let (dict, _) = r.val
      self.referenced_pdfobj(no_follow_entries, no_follow_contains, found, dict)
    }
    _ => ()
  }
}

///|
/// Find the objects reachable from the given object.
#as_free_fn(objects_referenced, deprecated="Use Pdf::objects_referenced instead")
pub fn Pdf::objects_referenced(
  self : Pdf,
  no_follow_entries : Array[String],
  no_follow_contains : Array[(String, PdfObject)],
  pdfobject : PdfObject,
) -> Array[Int] {
  let found = refset_empty()
  self.referenced_pdfobj(
    no_follow_entries, no_follow_contains, found, pdfobject,
  )
  refset_elts(found)
}

///|
fn Pdf::nullify_deleted_page_references(self : Pdf) -> Unit raise {
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
  self.objiter((objnum, obj) => match obj {
    Dictionary(_) =>
      match self.lookup_direct("/Type", obj) {
        Some(Name("/Page")) => page_object_numbers.push(objnum)
        _ => ()
      }
    _ => ()
  })
  let refnums = self.page_reference_numbers()
  if refnums.length() != page_object_numbers.length() {
    let table = Map::new()
    for num in page_object_numbers {
      table.set(num, true)
    }
    for num in refnums {
      table.remove(num)
    }
    self.objselfmap(obj => nullify(table, obj))
  }
}

///|
/// Remove any unreferenced objects.
#as_free_fn(remove_unreferenced, deprecated="Use Pdf::remove_unreferenced instead")
pub fn Pdf::remove_unreferenced(self : Pdf) -> Unit raise {
  self.nullify_deleted_page_references()
  let found = refset_empty()
  self.referenced_pdfobj([], [], found, self.lookup_obj(self.root))
  self.referenced_pdfobj([], [], found, self.trailerdict)
  refset_add(self.root, found)
  let eltnumbers = refset_elts(found)
  let elements = eltnumbers.map(num => self.lookup_obj(num))
  self.objects.max_obj_num = 0
  self.objects.objects.clear()
  self.objects.object_stream_ids.clear()
  for i, num in eltnumbers {
    self.addobj_given_num((num, elements[i]))
  }
}

///|
fn Pdf::page_reference_numbers_inner(
  self : Pdf,
  pages_node : PdfObject,
  node_number : Int,
) -> Array[Int] {
  match self.lookup_direct("/Type", pages_node) {
    Some(Name("/Page")) => [node_number]
    _ =>
      match self.lookup_direct("/Kids", pages_node) {
        Some(Array(elts)) => {
          let out = Array::new()
          for elt in elts {
            match elt {
              Indirect(i) =>
                out.append(
                  self.page_reference_numbers_inner(self.direct(Indirect(i)), i)[:],
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
#as_free_fn(page_reference_numbers, deprecated="Use Pdf::page_reference_numbers instead")
pub fn Pdf::page_reference_numbers(self : Pdf) -> Array[Int] raise {
  let root = self.lookup_obj(self.root)
  let pages_node = match self.lookup_direct("/Pages", root) {
    Some(p) => p
    None => raise PdfError::Msg("No /Pages found in /Root")
  }
  self.page_reference_numbers_inner(pages_node, -1)
}

///|
/// Renumber indirect references using a change table.
#as_free_fn(renumber_object_parsed, deprecated="Use Pdf::renumber_object_parsed instead")
pub fn Pdf::renumber_object_parsed(
  self : Pdf,
  changes : Map[Int, Int],
  obj : PdfObject,
  preserve_order? : Bool = false,
) -> PdfObject {
  match obj {
    Indirect(i) =>
      match changes.get(i) {
        Some(x) => Indirect(x)
        None => Indirect(i)
      }
    Array(values) =>
      Array(
        values.map(v => self.renumber_object_parsed(changes, v, preserve_order~)),
      )
    Dictionary(entries) =>
      recurse_dict(
        v => self.renumber_object_parsed(changes, v, preserve_order~),
        entries,
        preserve_order~,
      )
    Stream(r) => {
      let (dict, stream) = r.val
      let dict_updated = self.renumber_object_parsed(
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
#as_free_fn(changes, deprecated="Use Pdf::changes instead")
pub fn Pdf::changes(self : Pdf) -> Map[Int, Int] {
  let keys = self.objnumbers()
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
#as_free_fn(renumber, deprecated="Use Pdf::renumber instead")
pub fn Pdf::renumber(
  self : Pdf,
  change_table : Map[Int, Int],
  preserve_order? : Bool = false,
) -> Pdf {
  let root = match change_table.get(self.root) {
    Some(value) => value
    None => self.root
  }
  let trailerdict = if check_object_contains_renumbering(
      change_table,
      self.trailerdict,
    ) {
    self.renumber_object_parsed(change_table, self.trailerdict, preserve_order~)
  } else {
    self.trailerdict
  }
  let entries = self.objects.objects.to_array()
  entries.sort_by((a, b) => a.0 - b.0)
  let objects : PdfObjMap = Map::new(capacity=entries.length())
  let mut max_obj_num = 0
  for entry in entries {
    let old_num = entry.0
    let new_num = match change_table.get(old_num) {
      Some(value) => value
      None => old_num
    }
    let obj = self.lookup_obj(old_num)
    let updated = if check_object_contains_renumbering(change_table, obj) {
      self.renumber_object_parsed(change_table, obj, preserve_order~)
    } else {
      obj
    }
    objects.set(new_num, ({ val: ObjectData::Parsed(updated) }, 0))
    if new_num > max_obj_num {
      max_obj_num = new_num
    }
  }
  let object_stream_ids = Map::new()
  for key, value in self.objects.object_stream_ids {
    match change_table.get(key) {
      Some(new_key) => object_stream_ids.set(new_key, value)
      None => ()
    }
  }
  {
    major: self.major,
    minor: self.minor,
    root,
    objects: {
      max_obj_num,
      parse: self.objects.parse,
      objects,
      object_stream_ids,
    },
    trailerdict,
    was_linearized: self.was_linearized,
    saved_encryption: self.saved_encryption,
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
    out.push(pdf.renumber(changes))
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
#as_free_fn(deep_copy, deprecated="Use Pdf::deep_copy instead")
pub fn Pdf::deep_copy(self : Pdf) -> Pdf {
  let object_stream_ids = Map::new()
  for key, value in self.objects.object_stream_ids {
    object_stream_ids.set(key, value)
  }
  {
    major: self.major,
    minor: self.minor,
    root: self.root,
    objects: {
      max_obj_num: self.objects.max_obj_num,
      parse: self.objects.parse,
      objects: deep_copy_pdfobjects(self),
      object_stream_ids,
    },
    trailerdict: deep_copy_pdfobject(self.trailerdict),
    was_linearized: self.was_linearized,
    saved_encryption: self.saved_encryption,
  }
}

///|

///|
/// Generate an /ID entry for a document.
#as_free_fn(generate_id, deprecated="Use Pdf::generate_id instead")
pub fn Pdf::generate_id(
  self : Pdf,
  path : String,
  gettime : () -> Double,
) -> PdfObject {
  let _ = self
  let stamp = gettime().to_string()
  let id = path + stamp
  PdfObject::Array([PdfObject::String(id), PdfObject::String(id)])
}

///|
/// Replace the /ID entry in the trailer dictionary.
#as_free_fn(change_id, deprecated="Use Pdf::change_id instead")
pub fn Pdf::change_id(self : Pdf, path : String) -> Unit raise {
  match self.trailerdict {
    Dictionary(_) =>
      self.trailerdict = self.trailerdict.add_entry(
        "/ID",
        self.generate_id(path, () => @env.now().to_double()),
      )
    _ => raise PdfError::Msg("Bad trailer dictionary")
  }
}
