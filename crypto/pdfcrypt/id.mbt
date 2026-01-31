///|
fn get_or_add_id(pdf : @pdf.Pdf) -> (String, @pdf.Pdf) raise {
  match pdf.lookup_direct("/ID", pdf.trailerdict) {
    Some(Array([String(s), _])) => (s, pdf)
    _ => {
      let stamp = @env.now().to_string()
      let id = stamp
      let idobj = @pdf.PdfObject::Array([String(id), String(id)])
      pdf.trailerdict = pdf.trailerdict.add_entry("/ID", idobj)
      (id, pdf)
    }
  }
}
