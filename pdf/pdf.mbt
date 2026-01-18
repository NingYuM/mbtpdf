///|
/// Core error used across the PDF surface.
pub(all) suberror PdfError {
  Msg(String)
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
pub type PdfObjMapKey = Int

///|
pub type PdfObjMapEntry = (Ref[ObjectData], Int)

///|
pub type PdfObjMap = Map[PdfObjMapKey, PdfObjMapEntry]

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
pub fn pdfobjmap_add(
  key : PdfObjMapKey,
  entry : PdfObjMapEntry,
  map : PdfObjMap,
) -> PdfObjMap {
  map.set(key, entry)
  map
}

///|
pub fn pdfobjmap_remove(key : PdfObjMapKey, map : PdfObjMap) -> PdfObjMap {
  map.remove(key)
  map
}

///|
pub fn pdfobjmap_bindings(
  map : PdfObjMap,
) -> Array[(PdfObjMapKey, PdfObjMapEntry)] {
  map.to_array()
}

///|
/// The empty document (PDF 2.0, no objects, no root, empty trailer dictionary).
pub fn empty() -> Pdf {
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
/// Return a name with the given prefix not already used in the dictionary.
pub fn unique_key(prefix : String, obj : PdfObject) -> String raise {
  let entries = match obj {
    Dictionary(es) => es
    Stream(r) => {
      let (inner, _) = r.val
      match inner {
        Dictionary(es) => es
        _ => raise PdfError::Msg("unique_key: Not a dictionary or stream")
      }
    }
    _ => raise PdfError::Msg("unique_key: Not a dictionary or stream")
  }
  fn dict_has_key(dict : Array[(String, PdfObject)], key : String) -> Bool {
    dict.search_by(pair => pair.0 == key) is Some(_)
  }

  fn name_of_num(n : Int) -> String {
    "/\{prefix}\{n}"
  }

  let mut num = 0
  while dict_has_key(entries, name_of_num(num)) {
    num = num + 1
  }
  name_of_num(num)
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
/// Lookup a key in a nested dictionary chain.
pub fn lookup_chain(
  pdf : Pdf,
  start : PdfObject,
  keys : ArrayView[String],
) -> PdfObject? {
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
  fn remove_in_obj(
    current : PdfObject,
    chain : ArrayView[String],
  ) -> (PdfObject, Bool) raise {
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
  let mut i = 0
  while i < ac.length() && i < bc.length() {
    if ac[i] != bc[i] {
      return ac[i].to_int() - bc[i].to_int()
    }
    i = i + 1
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
      let mut i = 0
      while i + 1 < elts.length() {
        if key_eq(key, elts[i]) {
          return Some(elts[i + 1])
        }
        i = i + 2
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
      let mut i = 0
      while i + 1 < names.length() {
        out.push((names[i], names[i + 1]))
        i = i + 2
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
            let raw = @pdfio.bytes_of_input(
              toget.input,
              toget.position,
              toget.length,
            )
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
/// Return the size of the object map.
pub fn objcard(pdf : Pdf) -> Int {
  pdf.objects.objects.length()
}

///|
/// Return the object numbers in ascending order.
pub fn objnumbers(pdf : Pdf) -> Array[Int] {
  let entries = pdf.objects.objects.to_array()
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
/// Same as lookup_fail, but with a customized exception.
pub fn lookup_exception(
  err : Error,
  pdf : Pdf,
  key : String,
  dict : PdfObject,
) -> PdfObject raise {
  match lookup_direct(pdf, key, dict) {
    Some(obj) => obj
    None => raise err
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
pub fn recurse_dict(
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
/// Iterate over stream objects in a document.
pub fn iter_stream(f : (PdfObject) -> Unit raise?, pdf : Pdf) -> Unit raise? {
  objiter(
    (_num, obj) => match obj {
      Stream(_) => f(obj)
      _ => ()
    },
    pdf,
  )
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
  let trailerdict = renumber_object_parsed(
    pdf,
    change_table,
    pdf.trailerdict,
    preserve_order~,
  )
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
    let updated = renumber_object_parsed(
      pdf,
      change_table,
      obj,
      preserve_order~,
    )
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
    let keys = objnumbers(pdf)
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
fn generate_id(path : String) -> PdfObject {
  let stamp = @env.now().to_string()
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
        generate_id(path),
      )
    _ => raise PdfError::Msg("Bad trailer dictionary")
  }
}
