///|
fn position_1(value : Int, values : Array[Int]) -> Int? {
  match values.search_by(v => v == value) {
    Some(i) => Some(i + 1)
    None => None
  }
}

///|
fn matrix_is_identity(m : @pdftransform.TransformMatrix) -> Bool {
  m.a == 1.0 &&
  m.b == 0.0 &&
  m.c == 0.0 &&
  m.d == 1.0 &&
  m.e == 0.0 &&
  m.f == 0.0
}

///|
pub fn pagenumber_of_target(
  pdf : @pdf.Pdf,
  target : @pdfdest.Destination,
  fastrefnums? : Map[Int, Int],
) -> Int raise {
  match target {
    NullDestination | NamedDestination(_) | StringDestination(_) => 0
    Action(a) =>
      match @pdf.lookup_direct(pdf, "/S", a) {
        Some(@pdf.PdfObject::Name("/GoTo")) =>
          match @pdf.lookup_direct(pdf, "/D", a) {
            Some(dest) =>
              match fastrefnums {
                Some(table) =>
                  pagenumber_of_target(
                    pdf,
                    @pdfdest.read_destination(pdf, dest),
                    fastrefnums=table,
                  )
                None =>
                  pagenumber_of_target(
                    pdf,
                    @pdfdest.read_destination(pdf, dest),
                  )
              }
            None => 0
          }
        _ => 0
      }
    XYZ(tp, _, _, _)
    | Fit(tp)
    | FitH(tp, _)
    | FitV(tp, _)
    | FitR(tp, _, _, _, _)
    | FitB(tp)
    | FitBH(tp, _)
    | FitBV(tp, _) =>
      match (tp : @pdfdest.TargetPage) {
        OtherDocPageNumber(i) => i + 1
        PageObject(i) =>
          match fastrefnums {
            Some(table) =>
              match table.get(i) {
                Some(n) => n
                None => 0
              }
            None =>
              match position_1(i, @pdf.page_reference_numbers(pdf)) {
                Some(n) => n
                None => 0
              }
          }
      }
  }
}

///|
/// For page processing without matrices, return the identity matrix.
pub fn[A, B, C] ppstub(
  f : (A, B) -> C raise?,
  n : A,
  p : B,
) -> (C, A, @pdftransform.TransformMatrix) raise? {
  (f(n, p), n, @pdftransform.TransformMatrix::identity())
}

///|
fn change_pages_find_matrix(
  dest : @pdfdest.Destination,
  mattable : Map[Int, @pdftransform.TransformMatrix],
  refnumstable : Map[Int, Int],
) -> @pdftransform.TransformMatrix {
  match dest {
    XYZ(tp, _, _, _)
    | FitH(tp, _)
    | FitV(tp, _)
    | FitR(tp, _, _, _, _)
    | FitBH(tp, _)
    | FitBV(tp, _) =>
      match (tp : @pdfdest.TargetPage) {
        PageObject(i) =>
          match refnumstable.get(i) {
            Some(pagenumber) =>
              match mattable.get(pagenumber) {
                Some(tr) => tr
                None => @pdftransform.TransformMatrix::identity()
              }
            None => @pdftransform.TransformMatrix::identity()
          }
        _ => @pdftransform.TransformMatrix::identity()
      }
    _ => @pdftransform.TransformMatrix::identity()
  }
}

///|
fn change_pages_process_bookmarks(
  mattable : Map[Int, @pdftransform.TransformMatrix],
  refnumstable : Map[Int, Int],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let bookmarks = @pdfmarks.read_bookmarks(pdf, preserve_actions=true)
  let updated = bookmarks.map(m => {
    let tr = change_pages_find_matrix(m.target, mattable, refnumstable)
    if matrix_is_identity(tr) {
      m
    } else {
      @pdfmarks.transform_bookmark(pdf, tr, m)
    }
  })
  @pdfmarks.add_bookmarks(updated, pdf)
}

///|
fn rewrite_dest(
  pdf : @pdf.Pdf,
  mattable : Map[Int, @pdftransform.TransformMatrix],
  refnumstable : Map[Int, Int],
  dest : @pdf.PdfObject,
) -> Int? raise {
  let parsed_dest = @pdfdest.read_destination(pdf, dest)
  let tr = change_pages_find_matrix(parsed_dest, mattable, refnumstable)
  if matrix_is_identity(tr) {
    None
  } else {
    let transformed = @pdfdest.transform_destination(pdf, tr, parsed_dest)
    let new_dest = @pdfdest.pdfobject_of_destination(transformed)
    Some(@pdf.addobj(pdf, new_dest))
  }
}

///|
fn rewrite_action(
  pdf : @pdf.Pdf,
  mattable : Map[Int, @pdftransform.TransformMatrix],
  refnumstable : Map[Int, Int],
  action : @pdf.PdfObject,
) -> @pdf.PdfObject? raise {
  match @pdf.lookup_direct(pdf, "/S", action) {
    Some(@pdf.PdfObject::Name("/GoTo")) =>
      match @pdf.lookup_direct(pdf, "/D", action) {
        Some(dest) =>
          match rewrite_dest(pdf, mattable, refnumstable, dest) {
            Some(objnum) =>
              Some(
                @pdf.add_dict_entry(
                  action,
                  "/D",
                  @pdf.PdfObject::Indirect(objnum),
                ),
              )
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn change_pages_process_annotations(
  mattable : Map[Int, @pdftransform.TransformMatrix],
  refnumstable : Map[Int, Int],
  pdf : @pdf.Pdf,
) -> Unit raise {
  let pages = pages_of_pagetree(pdf)
  let mut pnum = 0
  for page in pages {
    pnum = pnum + 1
    match @pdf.lookup_direct(pdf, "/Annots", page.rest) {
      Some(@pdf.PdfObject::Array(annots)) =>
        for annotobj in annots {
          match annotobj {
            @pdf.PdfObject::Indirect(i) => {
              let annot = @pdf.lookup_obj(pdf, i)
              match @pdf.lookup_direct(pdf, "/Subtype", annot) {
                Some(@pdf.PdfObject::Name("/Link")) =>
                  match @pdf.lookup_direct(pdf, "/Dest", annot) {
                    Some(dest) =>
                      match rewrite_dest(pdf, mattable, refnumstable, dest) {
                        Some(objnum) => {
                          let new_annot = @pdf.add_dict_entry(
                            annot,
                            "/Dest",
                            @pdf.PdfObject::Indirect(objnum),
                          )
                          @pdf.addobj_given_num(pdf, (i, new_annot))
                        }
                        None => ()
                      }
                    None =>
                      match @pdf.lookup_direct(pdf, "/A", annot) {
                        Some(@pdf.PdfObject::Dictionary(_) as action) =>
                          match
                            rewrite_action(pdf, mattable, refnumstable, action) {
                            Some(updated_action) => {
                              let new_annot = @pdf.add_dict_entry(
                                annot, "/A", updated_action,
                              )
                              @pdf.addobj_given_num(pdf, (i, new_annot))
                            }
                            None => ()
                          }
                        _ => ()
                      }
                  }
                _ => ()
              }
            }
            _ =>
              @pdfe.log("change_pages_process_annotations: annotation direct\n")
          }
        }
      None => ()
      _ => @pdfe.log("change_pages_process_annotations: /Annots not an array\n")
    }
  }
}

///|
fn rewrite_openaction(pdf : @pdf.Pdf, action : @pdf.PdfObject) -> Unit raise {
  let catalog = @pdf.catalog_of_pdf(pdf)
  let updated = @pdf.add_dict_entry(catalog, "/OpenAction", action)
  @pdf.addobj_given_num(pdf, (pdf.root, updated))
}

///|
fn change_pages_process_openaction(
  mattable : Map[Int, @pdftransform.TransformMatrix],
  refnumstable : Map[Int, Int],
  pdf : @pdf.Pdf,
) -> Unit raise {
  match @pdf.lookup_direct(pdf, "/OpenAction", @pdf.catalog_of_pdf(pdf)) {
    Some(@pdf.PdfObject::Array(dest)) =>
      match
        rewrite_dest(pdf, mattable, refnumstable, @pdf.PdfObject::Array(dest)) {
        Some(new_dest_objnum) =>
          rewrite_openaction(pdf, @pdf.PdfObject::Indirect(new_dest_objnum))
        None => ()
      }
    Some(@pdf.PdfObject::Dictionary(_) as action) =>
      match rewrite_action(pdf, mattable, refnumstable, action) {
        Some(updated_action) => rewrite_openaction(pdf, updated_action)
        None => ()
      }
    _ => ()
  }
}

///|
fn[K : Hash + Eq, V] map_of_pairs(pairs : Array[(K, V)]) -> Map[K, V] {
  let m = Map::new(capacity=pairs.length())
  for pair in pairs {
    m.set(pair.0, pair.1)
  }
  m
}

///|
fn copy_object_stream_ids(pdf : @pdf.Pdf, basepdf : @pdf.Pdf) -> Unit {
  pdf.objects.object_stream_ids.clear()
  for key, value in basepdf.objects.object_stream_ids {
    pdf.objects.object_stream_ids.set(key, value)
  }
}

///|
fn select_page_ref_change(refs : Array[Int], index_1 : Int) -> Int raise {
  if index_1 < 1 || index_1 > refs.length() {
    raise @pdf.PdfError::Msg("change_pages: bad serial number")
  }
  refs[index_1 - 1]
}

///|
/// Replace the page tree with new pages, optionally rewriting references.
pub fn change_pages(
  change_references : Bool,
  basepdf : @pdf.Pdf,
  pages : Array[Page],
  matrices? : Array[(Int, @pdftransform.TransformMatrix)],
  changes? : Array[(Int, Int)],
) -> @pdf.Pdf raise {
  let pdf = @pdf.empty()
  @pdf.objiter((k, v) => @pdf.addobj_given_num(pdf, (k, v)), basepdf)
  copy_object_stream_ids(pdf, basepdf)
  let old_page_numbers = @pdf.page_reference_numbers(basepdf)
  let (pdf, pagetree_num) = add_pagetree(pages, pdf)
  let pdf : @pdf.Pdf = {
    major: basepdf.major,
    minor: basepdf.minor,
    root: pdf.root,
    objects: pdf.objects,
    trailerdict: basepdf.trailerdict,
    was_linearized: basepdf.was_linearized,
    saved_encryption: basepdf.saved_encryption,
  }
  let existing_root_entries = match @pdf.lookup_obj(basepdf, basepdf.root) {
    @pdf.PdfObject::Dictionary(d) => d
    _ => []
  }
  let pdf = add_root(pagetree_num, existing_root_entries, pdf)
  let new_page_numbers = @pdf.page_reference_numbers(pdf)
  if !change_references {
    pdf
  } else {
    let changes = match changes {
      None =>
        if old_page_numbers.length() == new_page_numbers.length() {
          Array::zip(old_page_numbers, new_page_numbers)
        } else {
          @pdfe.log("change_pages: No change supplied, and lengths differ\n")
          []
        }
      Some(cs) => {
        let out = Array::new(capacity=cs.length())
        for pair in cs {
          let (x, y) = pair
          let old_ref = select_page_ref_change(old_page_numbers, x)
          let new_ref = select_page_ref_change(new_page_numbers, y)
          out.push((old_ref, new_ref))
        }
        out
      }
    }
    let changes_map = map_of_pairs(changes)
    @pdf.objselfmap(
      obj => @pdf.renumber_object_parsed(pdf, changes_map, obj),
      pdf,
    )
    match matrices {
      None => pdf
      Some(matpairs) => {
        let refnums = @pdf.page_reference_numbers(pdf)
        let mattable = map_of_pairs(matpairs)
        let refnumstable = Map::new(capacity=refnums.length())
        for i in 0..<refnums.length() {
          refnumstable.set(refnums[i], i + 1)
        }
        let pdf = if old_page_numbers.length() == new_page_numbers.length() {
          change_pages_process_bookmarks(mattable, refnumstable, pdf)
        } else {
          @pdfe.log(
            "Pdfpage.change_pages: non-null matrices when lengths differ\n",
          )
          pdf
        }
        try
          change_pages_process_annotations(mattable, refnumstable, pdf)
        catch {
          _ => @pdfe.log("failure in change_pages_process_annotations\n")
        } noraise {
          _ => ()
        }
        try change_pages_process_openaction(mattable, refnumstable, pdf) catch {
          _ => @pdfe.log("failure in change_pages_process_openaction\n")
        } noraise {
          _ => ()
        }
        pdf
      }
    }
  }
}
