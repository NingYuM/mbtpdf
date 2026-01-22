///|
/// Bookmark entry.
pub(all) struct Bookmark {
  level : Int
  text : String
  target : @pdfdest.Destination
  isopen : Bool
  colour : (Double, Double, Double)
  flags : Int
}

///|
/// Pretty-print a bookmark for debugging.
pub fn string_of_bookmark(mark : Bookmark) -> String {
  let dest = @pdfdest.pdfobject_of_destination(mark.target)
  let dest_string = @pdfwrite.string_of_pdf(dest)
  "\{mark.level} \{mark.text} \{dest_string} \{mark.isopen}\n"
}

///|
/// Remove any existing /Outlines from the document.
pub fn remove_bookmarks(pdf : @pdf.Pdf) -> @pdf.Pdf raise {
  match @pdf.lookup_direct(pdf, "/Root", pdf.trailerdict) {
    None => raise @pdf.PdfError::Msg("remove_bookmarks: Bad PDF: no root")
    Some(catalog) => {
      let catalog_updated = @pdf.remove_dict_entry(catalog, "/Outlines")
      let newcatalognum = @pdf.addobj(pdf, catalog_updated)
      let trailerdict = @pdf.add_dict_entry(
        pdf.trailerdict,
        "/Root",
        @pdf.PdfObject::Indirect(newcatalognum),
      )
      {
        major: pdf.major,
        minor: pdf.minor,
        root: newcatalognum,
        objects: pdf.objects,
        trailerdict,
        was_linearized: pdf.was_linearized,
        saved_encryption: pdf.saved_encryption,
      }
    }
  }
}

///|
priv enum Ntree {
  Br(Int, @pdf.PdfObject, Array[Ntree], Bool)
}

///|
fn ntree_objnum(node : Ntree) -> Int {
  match node {
    Ntree::Br(i, _, _, _) => i
  }
}

///|
fn ntree_obj(node : Ntree) -> @pdf.PdfObject {
  match node {
    Ntree::Br(_, obj, _, _) => obj
  }
}

///|
fn ntree_children(node : Ntree) -> Array[Ntree] {
  match node {
    Ntree::Br(_, _, children, _) => children
  }
}

///|
fn ntree_isopen(node : Ntree) -> Bool {
  match node {
    Ntree::Br(_, _, _, isopen) => isopen
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
fn[T] extremes(items : Array[T]) -> (T, T) raise {
  if items.length() == 0 {
    raise @pdf.PdfError::Msg("extremes: empty list")
  }
  (items[0], items[items.length() - 1])
}

///|
fn fresh(source : Ref[Int], pdf : @pdf.Pdf) -> Int {
  source.val = source.val + 1
  pdf.objects.max_obj_num + source.val
}

///|
fn any_open_nodes(nodes : Array[Ntree]) -> Bool {
  for node in nodes {
    if ntree_isopen(node) || any_open_nodes(ntree_children(node)) {
      return true
    }
  }
  false
}

///|
fn total_visible(nodes : Array[Ntree]) -> Int {
  let mut total = 0
  for node in nodes {
    total = total + 1
    if ntree_isopen(node) {
      total = total + total_visible(ntree_children(node))
    }
  }
  total
}

///|
fn add_root_parent(root_objnum : Int, node : Ntree) -> Ntree raise {
  let obj = @pdf.add_dict_entry(
    ntree_obj(node),
    "/Parent",
    @pdf.PdfObject::Indirect(root_objnum),
  )
  Ntree::Br(ntree_objnum(node), obj, ntree_children(node), ntree_isopen(node))
}

///|
fn flatten_tree(
  source : Ref[Int],
  pdf : @pdf.Pdf,
  tree : Array[Ntree],
) -> (Array[(Int, @pdf.PdfObject)], Int) raise {
  if tree.length() == 0 {
    let n = fresh(source, pdf)
    return ([(n, @pdf.PdfObject::Dictionary([]))], n)
  }
  let root_objnum = fresh(source, pdf)
  let tree = tree.map(node => add_root_parent(root_objnum, node))
  fn really_flatten(node : Ntree) -> Array[(Int, @pdf.PdfObject)] {
    let out = Array::new()
    out.push((ntree_objnum(node), ntree_obj(node)))
    let children = ntree_children(node)
    if children.length() > 0 {
      out.append(flatten(children.map(really_flatten))[:])
    }
    out
  }

  let all_but_top = flatten(tree.map(really_flatten))
  let (first_node, last_node) = extremes(tree)
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/First", @pdf.PdfObject::Indirect(ntree_objnum(first_node))),
    ("/Last", @pdf.PdfObject::Indirect(ntree_objnum(last_node))),
  ]
  if any_open_nodes(tree) {
    entries.push(("/Count", @pdf.PdfObject::Integer(total_visible(tree))))
  }
  let top = (root_objnum, @pdf.PdfObject::Dictionary(entries))
  ([top] + all_but_top, root_objnum)
}

///|
fn add_counts(nodes : Array[Ntree]) -> Array[Ntree] raise {
  nodes.map(add_count)
}

///|
fn add_count(node : Ntree) -> Ntree raise {
  let children = ntree_children(node)
  let obj = if children.length() == 0 {
    ntree_obj(node)
  } else if ntree_isopen(node) {
    @pdf.add_dict_entry(
      ntree_obj(node),
      "/Count",
      @pdf.PdfObject::Integer(total_visible(children)),
    )
  } else {
    @pdf.add_dict_entry(
      ntree_obj(node),
      "/Count",
      @pdf.PdfObject::Integer(-total_visible(children)),
    )
  }
  Ntree::Br(ntree_objnum(node), obj, add_counts(children), ntree_isopen(node))
}

///|
fn add_parent(parent : Int?, node : Ntree) -> Ntree raise {
  let obj = match parent {
    None => ntree_obj(node)
    Some(parent_num) =>
      @pdf.add_dict_entry(
        ntree_obj(node),
        "/Parent",
        @pdf.PdfObject::Indirect(parent_num),
      )
  }
  let children = ntree_children(node).map(child => add_parent(
    Some(ntree_objnum(node)),
    child,
  ))
  Ntree::Br(ntree_objnum(node), obj, children, ntree_isopen(node))
}

///|
fn add_firstlast(node : Ntree) -> Ntree raise {
  let children = ntree_children(node)
  if children.length() == 0 {
    node
  } else {
    let first = ntree_objnum(children[0])
    let last = ntree_objnum(children[children.length() - 1])
    let obj = @pdf.add_dict_entry(
      @pdf.add_dict_entry(
        ntree_obj(node),
        "/First",
        @pdf.PdfObject::Indirect(first),
      ),
      "/Last",
      @pdf.PdfObject::Indirect(last),
    )
    Ntree::Br(
      ntree_objnum(node),
      obj,
      children.map(add_firstlast),
      ntree_isopen(node),
    )
  }
}

///|
fn add_next(node : Ntree) -> Ntree raise {
  let children = ntree_children(node)
  if children.length() == 0 {
    node
  } else if children.length() == 1 {
    Ntree::Br(
      ntree_objnum(node),
      ntree_obj(node),
      children.map(add_next),
      ntree_isopen(node),
    )
  } else {
    let out = Array::new(capacity=children.length())
    for i in 0..<children.length() {
      let child = children[i]
      let updated = if i + 1 < children.length() {
        let nextnum = ntree_objnum(children[i + 1])
        let obj = @pdf.add_dict_entry(
          ntree_obj(child),
          "/Next",
          @pdf.PdfObject::Indirect(nextnum),
        )
        Ntree::Br(
          ntree_objnum(child),
          obj,
          ntree_children(child),
          ntree_isopen(child),
        )
      } else {
        child
      }
      out.push(add_next(updated))
    }
    Ntree::Br(ntree_objnum(node), ntree_obj(node), out, ntree_isopen(node))
  }
}

///|
fn add_prev(node : Ntree) -> Ntree raise {
  let children = ntree_children(node)
  if children.length() == 0 {
    node
  } else if children.length() == 1 {
    Ntree::Br(
      ntree_objnum(node),
      ntree_obj(node),
      children.map(add_prev),
      ntree_isopen(node),
    )
  } else {
    let out = Array::new(capacity=children.length())
    for i in 0..<children.length() {
      let child = children[i]
      let updated = if i > 0 {
        let prevnum = ntree_objnum(children[i - 1])
        let obj = @pdf.add_dict_entry(
          ntree_obj(child),
          "/Prev",
          @pdf.PdfObject::Indirect(prevnum),
        )
        Ntree::Br(
          ntree_objnum(child),
          obj,
          ntree_children(child),
          ntree_isopen(child),
        )
      } else {
        child
      }
      out.push(add_prev(updated))
    }
    Ntree::Br(ntree_objnum(node), ntree_obj(node), out, ntree_isopen(node))
  }
}

///|
fn node_of_line(
  _pdf : @pdf.Pdf,
  title : String,
  target : @pdfdest.Destination,
  colour : (Double, Double, Double),
  flags : Int,
) -> @pdf.PdfObject {
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/Title", @pdf.PdfObject::String(title)),
  ]
  let dest = @pdfdest.pdfobject_of_destination(target)
  match (dest : @pdf.PdfObject) {
    Null => ()
    _ =>
      match (target : @pdfdest.Destination) {
        Action(action) => entries.push(("/A", action))
        _ => entries.push(("/Dest", dest))
      }
  }
  let (r, g, b) = colour
  if !(r == 0.0 && g == 0.0 && b == 0.0) {
    entries.push(
      (
        "/C",
        @pdf.PdfObject::Array([
          @pdf.PdfObject::Real(r),
          @pdf.PdfObject::Real(g),
          @pdf.PdfObject::Real(b),
        ]),
      ),
    )
  }
  if flags != 0 {
    entries.push(("/F", @pdf.PdfObject::Integer(flags)))
  }
  @pdf.PdfObject::Dictionary(entries)
}

///|
fn make_outline_ntree(
  source : Ref[Int],
  pdf : @pdf.Pdf,
  marks : Array[Bookmark],
) -> Array[Ntree] {
  match marks {
    [] => return []
    _ => ()
  }
  let head = marks[0]
  let rest = marks[1:].to_array()
  let mut split = 0
  while split < rest.length() && rest[split].level > head.level {
    split = split + 1
  }
  let lower = rest.sub(start=0, end=split).to_array()
  let remaining = rest.sub(start=split).to_array()
  let node = node_of_line(pdf, head.text, head.target, head.colour, head.flags)
  let tree = make_outline_ntree(source, pdf, lower)
  let current = Ntree::Br(fresh(source, pdf), node, tree, head.isopen)
  let out = Array::new()
  out.push(current)
  out.append(make_outline_ntree(source, pdf, remaining)[:])
  out
}

///|
/// Add bookmarks to the document.
pub fn add_bookmarks(
  parsed : Array[Bookmark],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  if parsed.length() == 0 {
    remove_bookmarks(pdf)
  } else {
    let source = Ref::new(0)
    let tree = make_outline_ntree(source, pdf, parsed)
    let tree = tree.map(add_firstlast)
    let tree = match
      add_next(add_prev(Ntree::Br(0, @pdf.PdfObject::Null, tree, false))) {
      Ntree::Br(_, _, children, _) => children
    }
    let tree = add_counts(tree.map(node => add_parent(None, node)))
    let (pairs, tree_root_num) = flatten_tree(source, pdf, tree)
    for pair in pairs {
      @pdf.addobj_given_num(pdf, pair)
    }
    match @pdf.lookup_direct(pdf, "/Root", pdf.trailerdict) {
      None => raise @pdf.PdfError::Msg("Bad PDF: no root")
      Some(catalog) => {
        let catalog_updated = @pdf.add_dict_entry(
          catalog,
          "/Outlines",
          @pdf.PdfObject::Indirect(tree_root_num),
        )
        let newcatalognum = @pdf.addobj(pdf, catalog_updated)
        let trailerdict = @pdf.add_dict_entry(
          pdf.trailerdict,
          "/Root",
          @pdf.PdfObject::Indirect(newcatalognum),
        )
        {
          major: pdf.major,
          minor: pdf.minor,
          root: newcatalognum,
          objects: pdf.objects,
          trailerdict,
          was_linearized: pdf.was_linearized,
          saved_encryption: pdf.saved_encryption,
        }
      }
    }
  }
}

///|
fn traverse_outlines_lb(
  pdf : @pdf.Pdf,
  outlines : @pdf.PdfObject,
  indent : Ref[Int],
  preserve_actions : Bool,
  out : Ref[Array[Bookmark]],
) -> Unit raise {
  match @pdf.lookup_direct(pdf, "/First", outlines) {
    None => ()
    Some(first) =>
      do_until_no_next_lb(pdf, first, indent, preserve_actions, out)
  }
}

///|
fn do_until_no_next_lb(
  pdf : @pdf.Pdf,
  outline : @pdf.PdfObject,
  indent : Ref[Int],
  preserve_actions : Bool,
  out : Ref[Array[Bookmark]],
) -> Unit raise {
  let title = match @pdf.lookup_direct(pdf, "/Title", outline) {
    Some(@pdf.PdfObject::String(s)) => s
    _ => {
      @pdfe.log(
        "/Title not a string or not present in document outline entry. Using the empty string.\n",
      )
      ""
    }
  }
  let page : @pdfdest.Destination = match
    @pdf.lookup_direct(pdf, "/Dest", outline) {
    Some(@pdf.PdfObject::String(stringdest)) if preserve_actions =>
      StringDestination(stringdest)
    Some(dest) => @pdfdest.read_destination(pdf, dest, shallow=preserve_actions)
    None =>
      match @pdf.lookup_direct(pdf, "/A", outline) {
        None => NullDestination
        Some(action) =>
          if preserve_actions {
            match @pdf.lookup_direct(pdf, "/D", action) {
              Some(@pdf.PdfObject::Array(_) as dest) =>
                @pdfdest.read_destination(pdf, dest, shallow=preserve_actions)
              _ => Action(@pdf.direct(pdf, action))
            }
          } else {
            match @pdf.lookup_direct(pdf, "/D", action) {
              None => Action(@pdf.direct(pdf, action))
              Some(dest) =>
                @pdfdest.read_destination(pdf, dest, shallow=preserve_actions)
            }
          }
      }
  }
  let opn = match @pdf.lookup_direct(pdf, "/Count", outline) {
    Some(@pdf.PdfObject::Integer(i)) if i > 0 => true
    _ => false
  }
  let colour = try {
    match @pdf.lookup_direct(pdf, "/C", outline) {
      Some(@pdf.PdfObject::Array([a, b, c])) =>
        (@pdf.getnum(pdf, a), @pdf.getnum(pdf, b), @pdf.getnum(pdf, c))
      _ => (0.0, 0.0, 0.0)
    }
  } catch {
    _ => (0.0, 0.0, 0.0)
  }
  let flags = match @pdf.lookup_direct(pdf, "/F", outline) {
    Some(@pdf.PdfObject::Integer(i)) => i
    _ => 0
  }
  out.val.push({
    level: indent.val,
    text: title,
    target: page,
    isopen: opn,
    colour,
    flags,
  })
  indent.val = indent.val + 1
  traverse_outlines_lb(pdf, outline, indent, preserve_actions, out)
  if indent.val > 0 {
    indent.val = indent.val - 1
  }
  match @pdf.lookup_direct(pdf, "/Next", outline) {
    None => ()
    Some(next) => do_until_no_next_lb(pdf, next, indent, preserve_actions, out)
  }
}

///|
/// Read all bookmarks from the document.
pub fn read_bookmarks(
  pdf : @pdf.Pdf,
  preserve_actions? : Bool = false,
) -> Array[Bookmark] raise {
  match @pdf.lookup_direct(pdf, "/Root", pdf.trailerdict) {
    None => raise @pdf.PdfError::Msg("read_bookmarks - Bad PDF: no root")
    Some(catalog) =>
      match @pdf.lookup_direct(pdf, "/Outlines", catalog) {
        None => []
        Some(outlines) => {
          let out = Ref::new(Array::new())
          traverse_outlines_lb(
            pdf,
            outlines,
            Ref::new(0),
            preserve_actions,
            out,
          )
          out.val
        }
      }
  }
}

///|
/// Transform a bookmark destination.
pub fn transform_bookmark(
  pdf : @pdf.Pdf,
  tr : @pdftransform.TransformMatrix,
  mark : Bookmark,
) -> Bookmark raise {
  {
    level: mark.level,
    text: mark.text,
    target: @pdfdest.transform_destination(pdf, tr, mark.target),
    isopen: mark.isopen,
    colour: mark.colour,
    flags: mark.flags,
  }
}
