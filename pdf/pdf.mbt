///|
/// Core error used across the PDF surface.
pub suberror PdfError String

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
  Got(Bytes)
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
  max_obj_num : Int
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
  trailerdict : PdfObject
  was_linearized : Bool
  saved_encryption : SavedEncryption?
}
