///|
fn source(start : Int) -> () -> Int {
  let counter = Ref::new(start)
  fn() {
    counter.val = counter.val + 1
    counter.val
  }
}

///|
fn[T] array_slice(values : Array[T], start : Int, len : Int) -> Array[T] {
  values.sub(start~, end=start + len).to_array()
}

///|
/// Page tree node.
priv enum Ptree {
  Lf(Array[Page], Int, Int)
  Br(Array[Page], Ptree, Ptree, Int, Int)
}

///|
fn[T] split3(
  n : Int,
  values : Array[T],
) -> (Array[T], Array[T], Array[T]) raise {
  let len = values.length()
  if n > len - 2 {
    raise @pdf.PdfError::Msg("split3")
  }
  let leftlen = (len - n) / 2
  let left = array_slice(values, 0, leftlen)
  let middle = array_slice(values, leftlen, n)
  let right = array_slice(values, leftlen + n, len - leftlen - n)
  (left, middle, right)
}

///|
fn pagetree(
  objnumsource : () -> Int,
  pages : Array[Page],
  parent : Int,
) -> Ptree raise {
  if pages.length() < 10 {
    Ptree::Lf(pages, parent, objnumsource())
  } else {
    let (left, middle, right) = split3(5, pages)
    let this_num = objnumsource()
    let left_tree = pagetree(objnumsource, left, this_num)
    let right_tree = pagetree(objnumsource, right, this_num)
    Ptree::Br(middle, left_tree, right_tree, parent, this_num)
  }
}

///|
fn mkpage(
  getobjnum : () -> Int,
  parent : Int,
  page : Page,
) -> (Int, @pdf.PdfObject, Array[(Int, @pdf.PdfObject)]) raise {
  let extras : Array[(Int, @pdf.PdfObject)] = Array::new()
  let indirects : Array[@pdf.PdfObject] = Array::new()
  for c in page.content {
    match c {
      @pdf.PdfObject::Indirect(i) => indirects.push(@pdf.PdfObject::Indirect(i))
      _ => {
        let objnum = getobjnum()
        indirects.push(@pdf.PdfObject::Indirect(objnum))
        extras.push((objnum, c))
      }
    }
  }
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/Type", @pdf.PdfObject::Name("/Page")),
    ("/Parent", @pdf.PdfObject::Indirect(parent)),
    ("/Resources", page.resources),
    ("/MediaBox", page.mediabox),
  ]
  let rotation = page.rotate.to_int()
  if rotation != 0 {
    entries.push(("/Rotate", @pdf.PdfObject::Integer(rotation)))
  }
  let rest_entries = match page.rest {
    @pdf.PdfObject::Dictionary(d) => d
    _ => raise @pdf.PdfError::Msg("mkpage")
  }
  entries.append(rest_entries[:])
  if indirects.length() > 0 {
    entries.push(("/Contents", @pdf.PdfObject::Array(indirects)))
  }
  let page_obj = @pdf.PdfObject::Dictionary(entries)
  let objnum = getobjnum()
  (objnum, page_obj, extras)
}

///|
fn count_ptree(tree : Ptree) -> Int {
  match tree {
    Ptree::Lf(pages, _, _) => pages.length()
    Ptree::Br(pages, left, right, _, _) =>
      pages.length() + count_ptree(left) + count_ptree(right)
  }
}

///|
fn objnum_of_ptree(tree : Ptree) -> Int {
  match tree {
    Ptree::Lf(_, _, this) => this
    Ptree::Br(_, _, _, _, this) => this
  }
}

///|
fn objects_of_ptree(
  getobjnum : () -> Int,
  extras : Ref[Array[(Int, @pdf.PdfObject)]],
  tree : Ptree,
) -> Array[(Int, @pdf.PdfObject)] raise {
  match tree {
    Ptree::Lf(pages, parent, this) => {
      let page_objects : Array[(Int, @pdf.PdfObject)] = Array::new()
      for page in pages {
        let (objnum, obj, extra) = mkpage(getobjnum, this, page)
        extras.val.append(extra[:])
        page_objects.push((objnum, obj))
      }
      let parent_entry = if parent == 0 {
        []
      } else {
        [("/Parent", @pdf.PdfObject::Indirect(parent))]
      }
      let kids = page_objects.map(pair => @pdf.PdfObject::Indirect(pair.0))
      let node_entries : Array[(String, @pdf.PdfObject)] = [
        ("/Type", @pdf.PdfObject::Name("/Pages")),
        ("/Kids", @pdf.PdfObject::Array(kids)),
        ("/Count", @pdf.PdfObject::Integer(pages.length())),
      ]
      node_entries.append(parent_entry[:])
      let node = @pdf.PdfObject::Dictionary(node_entries)
      let result = Array::new(capacity=1 + page_objects.length())
      result.push((this, node))
      result.append(page_objects[:])
      result
    }
    Ptree::Br(pages, left, right, parent, this) => {
      let objs_left = objects_of_ptree(getobjnum, extras, left)
      let objs_right = objects_of_ptree(getobjnum, extras, right)
      let left_num = objnum_of_ptree(left)
      let right_num = objnum_of_ptree(right)
      let count_left = count_ptree(left)
      let count_right = count_ptree(right)
      let page_objects : Array[(Int, @pdf.PdfObject)] = Array::new()
      for page in pages {
        let (objnum, obj, extra) = mkpage(getobjnum, this, page)
        extras.val.append(extra[:])
        page_objects.push((objnum, obj))
      }
      let parent_entry = if parent == 0 {
        []
      } else {
        [("/Parent", @pdf.PdfObject::Indirect(parent))]
      }
      let kids = Array::new()
      kids.push(@pdf.PdfObject::Indirect(left_num))
      kids.append(page_objects.map(pair => @pdf.PdfObject::Indirect(pair.0))[:])
      kids.push(@pdf.PdfObject::Indirect(right_num))
      let node_entries : Array[(String, @pdf.PdfObject)] = [
        ("/Type", @pdf.PdfObject::Name("/Pages")),
        ("/Kids", @pdf.PdfObject::Array(kids)),
        (
          "/Count",
          @pdf.PdfObject::Integer(
            count_left + count_right + page_objects.length(),
          ),
        ),
      ]
      node_entries.append(parent_entry[:])
      let node = @pdf.PdfObject::Dictionary(node_entries)
      let result = Array::new()
      result.push((this, node))
      result.append(page_objects[:])
      result.append(objs_left[:])
      result.append(objs_right[:])
      result
    }
  }
}

///|
/// Build a page tree and add it to the PDF.
pub fn add_pagetree(
  pages : Array[Page],
  pdf : @pdf.Pdf,
) -> (@pdf.Pdf, Int) raise {
  let extras : Ref[Array[(Int, @pdf.PdfObject)]] = { val: [] }
  let getobjnum = source(pdf.objects.max_obj_num)
  let ptree = pagetree(getobjnum, pages, 0)
  let objects = objects_of_ptree(getobjnum, extras, ptree)
  if objects.length() == 0 {
    raise @pdf.PdfError::Msg("add_pagetree: empty page tree")
  }
  for obj in objects {
    @pdf.addobj_given_num(pdf, obj)
  }
  for extra in extras.val {
    @pdf.addobj_given_num(pdf, extra)
  }
  (pdf, objects[0].0)
}

///|
/// Replace the root catalog with a new /Pages entry.
pub fn add_root(
  pageroot : Int,
  extras : Array[(String, @pdf.PdfObject)],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let existing_entries = match @pdf.lookup_obj(pdf, pdf.root) {
    @pdf.PdfObject::Dictionary(d) => d
    _ => []
  }
  let mut root = @pdf.PdfObject::Dictionary(extras)
  for entry in existing_entries {
    root = root.add_entry(entry.0, entry.1)
  }
  root = root.add_entry("/Type", @pdf.PdfObject::Name("/Catalog"))
  root = root.add_entry("/Pages", @pdf.PdfObject::Indirect(pageroot))
  let rootnum = @pdf.addobj(pdf, root)
  let trailerdict = match pdf.trailerdict {
    @pdf.PdfObject::Dictionary(_) =>
      pdf.trailerdict.add_entry("/Root", @pdf.PdfObject::Indirect(rootnum))
    _ => raise @pdf.PdfError::Msg("add_root: bad trailer dictionary")
  }
  {
    major: pdf.major,
    minor: pdf.minor,
    root: rootnum,
    objects: pdf.objects,
    trailerdict,
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
}
