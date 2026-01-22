///|
fn find_first_duplicate(values : Array[Int]) -> Int? {
  if values.length() < 2 {
    return None
  }
  let mut prev = values[0]
  let mut i = 1
  while i < values.length() {
    let current = values[i]
    if current == prev {
      return Some(current)
    }
    prev = current
    i = i + 1
  }
  None
}

///|
fn rewrite_first_kid(
  old_num : Int,
  new_num : Int,
  kids : Array[@pdf.PdfObject],
) -> Array[@pdf.PdfObject] {
  let out = Array::new(capacity=kids.length())
  let mut rewritten = false
  for kid in kids {
    match kid {
      @pdf.PdfObject::Indirect(i) if i == old_num && !rewritten => {
        out.push(@pdf.PdfObject::Indirect(new_num))
        rewritten = true
      }
      _ => out.push(kid)
    }
  }
  out
}

///|
fn rewrite_first_indirect(
  pdf : @pdf.Pdf,
  objnum : Int,
  obj : @pdf.PdfObject,
  old_num : Int,
  new_num : Int,
) -> Bool raise {
  match @pdf.lookup_direct(pdf, "/Kids", obj) {
    Some(@pdf.PdfObject::Array(kids)) => {
      let mut found = false
      for kid in kids {
        match kid {
          @pdf.PdfObject::Indirect(i) if i == old_num => found = true
          _ => ()
        }
      }
      if found {
        let updated_kids = rewrite_first_kid(old_num, new_num, kids)
        let updated = @pdf.add_dict_entry(
          obj,
          "/Kids",
          @pdf.PdfObject::Array(updated_kids),
        )
        @pdf.addobj_given_num(pdf, (objnum, updated))
        true
      } else {
        false
      }
    }
    _ => false
  }
}

///|
fn page_tree_nodes_not_pages_inner(
  pdf : @pdf.Pdf,
  pages_node : @pdf.PdfObject,
  node_number : Int,
) -> Array[Int] {
  match @pdf.lookup_direct(pdf, "/Type", pages_node) {
    Some(@pdf.PdfObject::Name("/Page")) => []
    _ =>
      match @pdf.lookup_direct(pdf, "/Kids", pages_node) {
        Some(@pdf.PdfObject::Array(elts)) => {
          let out = Array::new()
          out.push(node_number)
          for elt in elts {
            match elt {
              @pdf.PdfObject::Indirect(i) =>
                out.append(
                  page_tree_nodes_not_pages_inner(pdf, @pdf.direct(pdf, elt), i)[:],
                )
              _ => ()
            }
          }
          out
        }
        _ => []
      }
  }
}

///|
fn page_tree_nodes_not_pages(pdf : @pdf.Pdf) -> Array[Int] raise {
  let root = @pdf.lookup_obj(pdf, pdf.root)
  let page_root_num = match root {
    @pdf.PdfObject::Dictionary(d) =>
      match d.search_by(pair => pair.0 == "/Pages") {
        Some(index) =>
          match d[index].1 {
            @pdf.PdfObject::Indirect(i) => i
            _ => raise @pdf.PdfError::Msg("No /Pages found in /Root")
          }
        None => raise @pdf.PdfError::Msg("No /Pages found in /Root")
      }
    _ => raise @pdf.PdfError::Msg("No /Pages found in /Root")
  }
  let pages_node = match @pdf.lookup_direct(pdf, "/Pages", root) {
    Some(p) => p
    None => raise @pdf.PdfError::Msg("No /Pages found in /Root")
  }
  page_tree_nodes_not_pages_inner(pdf, pages_node, page_root_num)
}

///|
fn rewrite_page_tree_first(
  nodes : Array[Int],
  pdf : @pdf.Pdf,
  old_num : Int,
) -> Unit raise {
  let new_num = @pdf.addobj(pdf, @pdf.lookup_obj(pdf, old_num))
  let mut rewritten = false
  for node in nodes {
    if !rewritten {
      rewritten = rewrite_first_indirect(
        pdf,
        node,
        @pdf.lookup_obj(pdf, node),
        old_num,
        new_num,
      )
    }
  }
  if !rewritten {
    raise @pdf.PdfError::Msg("rewrite_page_tree_first: malformed page tree")
  }
}

///|
fn page_reference_numbers_unordered_inner(
  pdf : @pdf.Pdf,
  pages_node : @pdf.PdfObject,
  node_number : Int,
  acc : Ref[Array[Int]],
) -> Unit {
  match @pdf.lookup_direct(pdf, "/Type", pages_node) {
    Some(@pdf.PdfObject::Name("/Page")) => acc.val.push(node_number)
    _ =>
      match @pdf.lookup_direct(pdf, "/Kids", pages_node) {
        Some(@pdf.PdfObject::Array(elts)) =>
          for elt in elts {
            match elt {
              @pdf.PdfObject::Indirect(i) =>
                page_reference_numbers_unordered_inner(
                  pdf,
                  @pdf.direct(pdf, elt),
                  i,
                  acc,
                )
              _ => ()
            }
          }
        _ => acc.val.push(node_number)
      }
  }
}

///|
fn page_reference_numbers_unordered(pdf : @pdf.Pdf) -> Array[Int] raise {
  let acc : Ref[Array[Int]] = { val: [] }
  let root = @pdf.lookup_obj(pdf, pdf.root)
  let pages_node = match @pdf.lookup_direct(pdf, "/Pages", root) {
    Some(p) => p
    None => raise @pdf.PdfError::Msg("No /Pages found in /Root")
  }
  page_reference_numbers_unordered_inner(pdf, pages_node, -1, acc)
  acc.val
}

///|
fn fixup_duplicate_pages_inner(
  nodes : Array[Int],
  pdf : @pdf.Pdf,
) -> Unit raise {
  let refs = page_reference_numbers_unordered(pdf)
  refs.sort()
  match find_first_duplicate(refs) {
    Some(n) => {
      rewrite_page_tree_first(nodes, pdf, n)
      fixup_duplicate_pages_inner(nodes, pdf)
    }
    None => ()
  }
}

///|
/// Ensure page tree does not contain duplicate page objects.
pub fn fixup_duplicate_pages(pdf : @pdf.Pdf) -> Unit raise {
  let nodes = page_tree_nodes_not_pages(pdf)
  fixup_duplicate_pages_inner(nodes, pdf)
}

///|
fn fixup_parents_inner(
  pdf : @pdf.Pdf,
  parent_objnum : Int,
  objnum : Int,
) -> Unit raise {
  let obj = @pdf.lookup_obj(pdf, objnum)
  match @pdf.indirect_number(pdf, "/Parent", obj) {
    Some(_) => {
      let updated = @pdf.add_dict_entry(
        obj,
        "/Parent",
        @pdf.PdfObject::Indirect(parent_objnum),
      )
      @pdf.addobj_given_num(pdf, (objnum, updated))
    }
    None => ()
  }
  match @pdf.lookup_direct(pdf, "/Kids", obj) {
    Some(@pdf.PdfObject::Array(kids)) =>
      for kid in kids {
        match kid {
          @pdf.PdfObject::Indirect(i) => fixup_parents_inner(pdf, objnum, i)
          _ => ()
        }
      }
    _ => ()
  }
}

///|
/// Rewrite /Parent links for page tree nodes.
pub fn fixup_parents(pdf : @pdf.Pdf) -> Unit raise {
  let root = @pdf.lookup_obj(pdf, pdf.root)
  match @pdf.indirect_number(pdf, "/Pages", root) {
    Some(pagetreeroot) => fixup_parents_inner(pdf, 0, pagetreeroot)
    None => raise @pdf.PdfError::Msg("fixup_parents: no page tree root")
  }
}

///|
fn fixup_link(
  key : String,
  obj : @pdf.PdfObject,
  assoc : Map[Int, Int],
) -> @pdf.PdfObject raise {
  match @pdf.lookup_immediate(key, obj) {
    Some(@pdf.PdfObject::Indirect(i)) =>
      match assoc.get(i) {
        Some(t) => @pdf.add_dict_entry(obj, key, @pdf.PdfObject::Indirect(t))
        None => obj
      }
    _ => obj
  }
}

///|
/// Duplicate shared annotations across pages.
pub fn fixup_duplicate_annots(pdf : @pdf.Pdf) -> Unit raise {
  let src = Ref::new(pdf.objects.max_obj_num)
  let pages = pages_of_pagetree(pdf)
  let existing_annots = pages.map(page => match
    @pdf.lookup_direct(pdf, "/Annots", page.rest) {
    Some(@pdf.PdfObject::Array(a)) =>
      a.filter_map(obj => match obj {
        @pdf.PdfObject::Indirect(i) => Some(i)
        _ => None
      })
    _ => []
  })
  let seen : Map[Int, Unit] = Map::new()
  let to_copy : Array[(Int, Int)] = Array::new()
  let new_annots = existing_annots.map(annots => {
    let out = Array::new()
    for i in annots {
      if seen.get(i) is None {
        out.push(i)
        seen.set(i, ())
      } else {
        src.val = src.val + 1
        let new_num = src.val
        to_copy.push((i, new_num))
        out.push(new_num)
        seen.set(new_num, ())
      }
    }
    out
  })
  for pair in to_copy {
    let (from, to) = pair
    @pdf.addobj_given_num(pdf, (to, @pdf.lookup_obj(pdf, from)))
  }
  for i in 0..<existing_annots.length() {
    let old_annots = existing_annots[i]
    let updated_annots = new_annots[i]
    let assoc : Map[Int, Int] = Map::new()
    for j in 0..<old_annots.length() {
      assoc.set(old_annots[j], updated_annots[j])
    }
    for annot_num in updated_annots {
      let obj = @pdf.lookup_obj(pdf, annot_num)
      let obj = fixup_link("/Popup", obj, assoc)
      let obj = fixup_link("/Parent", obj, assoc)
      @pdf.addobj_given_num(pdf, (annot_num, obj))
    }
  }
  let pagerefnums = @pdf.page_reference_numbers(pdf)
  for i in 0..<new_annots.length() {
    let annots = new_annots[i]
    let pagerefnum = pagerefnums[i]
    if annots.length() > 0 {
      let page_obj = @pdf.lookup_obj(pdf, pagerefnum)
      match page_obj {
        @pdf.PdfObject::Dictionary(_) => {
          let indirects = annots.map(n => @pdf.PdfObject::Indirect(n))
          let updated = @pdf.add_dict_entry(
            page_obj,
            "/Annots",
            @pdf.PdfObject::Array(indirects),
          )
          @pdf.addobj_given_num(pdf, (pagerefnum, updated))
        }
        _ => ()
      }
    }
  }
}

///|
fn was_nulled(pdf : @pdf.Pdf, pair : (String, @pdf.PdfObject)) -> Bool {
  let (_, dest) = pair
  match @pdf.direct(pdf, dest) {
    @pdf.PdfObject::Array(values) =>
      if values.length() > 0 {
        match values[0] {
          @pdf.PdfObject::Indirect(i) =>
            match @pdf.lookup_obj(pdf, i) {
              @pdf.PdfObject::Null => true
              _ => false
            }
          _ => false
        }
      } else {
        false
      }
    _ => false
  }
}

///|
/// Rewrite /Dests tree entries pointing at removed pages.
pub fn fixup_destinations(pdf : @pdf.Pdf) -> Unit raise {
  match @pdf.lookup_chain(pdf, pdf.trailerdict, ["/Root", "/Names", "/Dests"]) {
    Some(t) => {
      let tree = @pdftree.read_name_tree(pdf, t)
      let tree_updated = tree.filter(pair => !was_nulled(pdf, pair))
      let tree_obj = @pdftree.build_name_tree(false, pdf, tree_updated)
      @pdf.replace_chain(pdf, ["/Root", "/Names", "/Dests"], tree_obj)
    }
    None => ()
  }
}

///|
fn replace_inherit_entry(
  pdf : @pdf.Pdf,
  objnum : Int,
  entry : String,
) -> Unit raise {
  let obj = @pdf.lookup_obj(pdf, objnum)
  fn find_attribute(current : @pdf.PdfObject) -> @pdf.PdfObject? {
    match @pdf.lookup_direct(pdf, entry, current) {
      Some(_) => None
      None =>
        match @pdf.lookup_direct(pdf, "/Parent", current) {
          Some(@pdf.PdfObject::Dictionary(parent)) =>
            match
              @pdf.lookup_immediate(entry, @pdf.PdfObject::Dictionary(parent)) {
              Some(value) => Some(value)
              None => find_attribute(@pdf.PdfObject::Dictionary(parent))
            }
          Some(parent) => find_attribute(parent)
          None => None
        }
    }
  }

  match find_attribute(obj) {
    Some(replacement) => {
      let updated = @pdf.add_dict_entry(obj, entry, replacement)
      @pdf.addobj_given_num(pdf, (objnum, updated))
    }
    None => ()
  }
}

///|
/// For all pages in objnumbers, ensure inheritable attributes are present.
pub fn replace_inherit(pdf : @pdf.Pdf, objnumbers : Array[Int]) -> Unit raise {
  for objnum in objnumbers {
    replace_inherit_entry(pdf, objnum, "/MediaBox")
    replace_inherit_entry(pdf, objnum, "/CropBox")
    replace_inherit_entry(pdf, objnum, "/Rotate")
    replace_inherit_entry(pdf, objnum, "/Resources")
  }
}

///|
/// Get page object number for a 1-based page index.
pub fn page_object_number(pdf : @pdf.Pdf, destpage : Int) -> Int? raise {
  let refs = @pdf.page_reference_numbers(pdf)
  if destpage < 1 || destpage > refs.length() {
    None
  } else {
    Some(refs[destpage - 1])
  }
}

///|
/// Build a Fit destination for a page number.
pub fn target_of_pagenumber(
  pdf : @pdf.Pdf,
  index : Int,
) -> @pdfdest.Destination raise {
  match page_object_number(pdf, index) {
    None => NullDestination
    Some(p) => Fit(PageObject(p))
  }
}
