///|
priv enum PtreeObjnumbers {
  OLf(Array[Int], Int, Int)
  OBr(Array[Int], PtreeObjnumbers, PtreeObjnumbers, Int, Int)
}

///|
fn pagetree_with_objnumbers(
  toplevel : Bool,
  old_pagetree_root_num : Int,
  objnumsource : () -> Int,
  objnumbers : Array[Int],
  parent : Int,
) -> PtreeObjnumbers raise {
  if objnumbers.length() < 10 {
    let this_num = if toplevel { old_pagetree_root_num } else { objnumsource() }
    PtreeObjnumbers::OLf(objnumbers, parent, this_num)
  } else {
    let (left, this, right) = split3(5, objnumbers)
    let this_num = if toplevel { old_pagetree_root_num } else { objnumsource() }
    let left_tree = pagetree_with_objnumbers(
      false, old_pagetree_root_num, objnumsource, left, this_num,
    )
    let right_tree = pagetree_with_objnumbers(
      false, old_pagetree_root_num, objnumsource, right, this_num,
    )
    PtreeObjnumbers::OBr(this, left_tree, right_tree, parent, this_num)
  }
}

///|
fn buildnode(kids : Array[Int], parent : Int, count : Int) -> @pdf.PdfObject {
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/Type", @pdf.PdfObject::Name("/Pages")),
    ("/Kids", @pdf.PdfObject::Array(kids.map(i => @pdf.PdfObject::Indirect(i)))),
    ("/Count", @pdf.PdfObject::Integer(count)),
  ]
  if parent != 0 {
    entries.push(("/Parent", @pdf.PdfObject::Indirect(parent)))
  }
  @pdf.PdfObject::Dictionary(entries)
}

///|
fn objnumfrom(node : PtreeObjnumbers) -> Int {
  match node {
    PtreeObjnumbers::OLf(_, _, o) => o
    PtreeObjnumbers::OBr(_, _, _, _, o) => o
  }
}

///|
fn countof(node : PtreeObjnumbers) -> Int {
  match node {
    PtreeObjnumbers::OLf(objnumbers, _, _) => objnumbers.length()
    PtreeObjnumbers::OBr(objnumbers, left, right, _, _) =>
      objnumbers.length() + countof(left) + countof(right)
  }
}

///|
fn objects_of_ptree_objnumbers(pdf : @pdf.Pdf, node : PtreeObjnumbers) -> Unit {
  match node {
    PtreeObjnumbers::OLf(objnumbers, parent, objnum_leaf) =>
      @pdf.addobj_given_num(
        pdf,
        (objnum_leaf, buildnode(objnumbers, parent, countof(node))),
      )
    PtreeObjnumbers::OBr(objnumbers, left, right, parent, objnum_branch) => {
      let kids = Array::new()
      kids.push(objnumfrom(left))
      kids.append(objnumbers[:])
      kids.push(objnumfrom(right))
      @pdf.addobj_given_num(
        pdf,
        (objnum_branch, buildnode(kids, parent, countof(node))),
      )
      objects_of_ptree_objnumbers(pdf, left)
      objects_of_ptree_objnumbers(pdf, right)
    }
  }
}

///|
fn pdf_of_pages_build_pagetree(
  tree : PtreeObjnumbers,
  objnumbers : Array[Int],
  pdf : @pdf.Pdf,
) -> @pdf.PdfObject {
  match tree {
    PtreeObjnumbers::OLf(_, parent, _) =>
      buildnode(objnumbers, parent, countof(tree))
    PtreeObjnumbers::OBr(_, left, right, parent, _) => {
      objects_of_ptree_objnumbers(pdf, left)
      objects_of_ptree_objnumbers(pdf, right)
      let kids = Array::new()
      kids.push(objnumfrom(left))
      kids.append(objnumbers[:])
      kids.push(objnumfrom(right))
      buildnode(kids, parent, countof(tree))
    }
  }
}

///|
fn select_page_ref(refs : Array[Int], index_1 : Int) -> Int raise {
  if index_1 < 1 || index_1 > refs.length() {
    raise @pdf.PdfError::Msg("pdf_of_pages")
  }
  refs[index_1 - 1]
}

///|
fn range_to_set(range : Array[Int]) -> Map[Int, Unit] {
  let out = Map::new(capacity=range.length())
  for page in range {
    out.set(page, ())
  }
  out
}

///|
fn build_fastrefnums(refnums : Array[Int]) -> Map[Int, Int] {
  let out = Map::new(capacity=refnums.length())
  for i in 0..<refnums.length() {
    out.set(refnums[i], i + 1)
  }
  out
}

///|
/// Build a PDF containing a subset of pages.
pub fn pdf_of_pages(
  basepdf : @pdf.Pdf,
  range : Array[Int],
  retain_numbering? : Bool = false,
  process_struct_tree? : Bool = false,
) -> @pdf.Pdf raise {
  if range.length() == 0 {
    raise @pdf.PdfError::Msg("pdf_of_pages: cannot build PDF with no pages")
  }
  let page_labels = if @pdfpagelabels.PageLabel::read_all(basepdf).length() == 0 {
    []
  } else if retain_numbering {
    @pdfpagelabels.merge_pagelabels([basepdf], [range])
  } else {
    []
  }
  let marks = {
    let refnums = @pdf.page_reference_numbers(basepdf)
    let fastrefnums = build_fastrefnums(refnums)
    let range_set = range_to_set(range)
    let mut first_index = -1
    let mut first_level = -1
    let mut index = -1
    let marks = @pdfmarks.read_bookmarks(basepdf, preserve_actions=true)
    let kept : Array[@pdfmarks.Bookmark] = Array::new(capacity=marks.length())
    for mark in marks {
      index = index + 1
      let page_num = pagenumber_of_target(basepdf, mark.target, fastrefnums~)
      if range_set.get(page_num) is Some(_) {
        if first_index == -1 {
          first_index = index
          first_level = mark.level
        }
        kept.push(mark)
      }
    }
    let prefix_rev : Array[@pdfmarks.Bookmark] = Array::new()
    if first_index != -1 {
      let mut level = first_level - 1
      let mut n = first_index
      while n >= 0 {
        if level > -1 && marks[n].level == level {
          prefix_rev.push(marks[n])
          level = level - 1
        }
        if n == 0 {
          break
        }
        n = n - 1
      }
      prefix_rev.rev_in_place()
    }
    prefix_rev + kept
  }
  let pdf = @pdf.Pdf::empty()
  @pdf.objiter((k, v) => @pdf.addobj_given_num(pdf, (k, v)), basepdf)
  let page_numbers = @pdf.page_reference_numbers(basepdf)
  let pdf : @pdf.Pdf = {
    major: basepdf.major,
    minor: basepdf.minor,
    root: basepdf.root,
    objects: pdf.objects,
    trailerdict: basepdf.trailerdict,
    was_linearized: basepdf.was_linearized,
    saved_encryption: basepdf.saved_encryption,
  }
  if process_struct_tree {
    @pdfst.trim_structure_tree(pdf, range)
  }
  let existing_root_entries = match @pdf.lookup_obj(basepdf, basepdf.root) {
    @pdf.PdfObject::Dictionary(d) => d
    _ => []
  }
  let objnumbers : Array[Int] = Array::new(capacity=range.length())
  for page in range {
    objnumbers.push(select_page_ref(page_numbers, page))
  }
  let old_pagetree_root_num = match
    @pdf.lookup_direct(basepdf, "/Root", pdf.trailerdict) {
    Some(root) =>
      match @pdf.indirect_number(basepdf, "/Pages", root) {
        Some(i) => i
        None => raise @pdf.PdfError::Msg("pdf_of_pages")
      }
    None => raise @pdf.PdfError::Msg("pdf_of_pages")
  }
  replace_inherit(pdf, objnumbers)
  let thetree = pagetree_with_objnumbers(
    true,
    old_pagetree_root_num,
    source(pdf.objects.max_obj_num),
    objnumbers,
    0,
  )
  let objnumbers_set = range_to_set(objnumbers)
  @pdf.objiter(
    (i, o) => match o {
      @pdf.PdfObject::Dictionary(_) =>
        match @pdf.lookup_direct(pdf, "/Type", o) {
          Some(@pdf.PdfObject::Name("/Pages")) => @pdf.removeobj(pdf, i)
          Some(@pdf.PdfObject::Name("/Page")) =>
            if objnumbers_set.get(i) is None {
              @pdf.removeobj(pdf, i)
            }
          _ => ()
        }
      _ => ()
    },
    pdf,
  )
  let new_pagetree = pdf_of_pages_build_pagetree(thetree, objnumbers, pdf)
  @pdf.addobj_given_num(pdf, (old_pagetree_root_num, new_pagetree))
  let pdf = add_root(old_pagetree_root_num, existing_root_entries, pdf)
  @pdfpagelabels.PageLabel::write_all(page_labels, pdf)
  let pdf = @pdfmarks.add_bookmarks(marks, pdf)
  fixup_duplicate_pages(pdf)
  fixup_parents(pdf)
  fixup_destinations(pdf)
  try fixup_duplicate_annots(pdf) catch {
    _ => @pdfe.log("warning: fixup_duplicate_annots\n")
  } noraise {
    _ => ()
  }
  pdf
}
