///|
/// Compare two byte arrays lexicographically.
fn compare_bytes(left : Array[Byte], right : Array[Byte]) -> Int {
  let min_len = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for i in 0..<min_len {
    let a = left[i].to_int()
    let b = right[i].to_int()
    if a != b {
      return a - b
    }
  }
  if left.length() == right.length() {
    0
  } else if left.length() < right.length() {
    -1
  } else {
    1
  }
}

///|
fn[T] flatten(lists : Array[Array[T]]) -> Array[T] {
  let out = Array::new()
  for list in lists {
    out.append(list[:])
  }
  out
}

///|
fn ilist(start : Int, finish : Int) -> Array[Int] {
  if finish < start {
    return []
  }
  let out = Array::new(capacity=finish - start + 1)
  for i in start..<=finish {
    out.push(i)
  }
  out
}

///|
fn contains_int(values : Array[Int], value : Int) -> Bool {
  for item in values {
    if item == value {
      return true
    }
  }
  false
}

///|
fn[T] slice(values : Array[T], start : Int, count : Int) -> Array[T] raise {
  if start < 0 || count < 0 || start + count > values.length() {
    raise @pdf.PdfError::Msg("slice: out of bounds")
  }
  let out = Array::new(capacity=count)
  for i in 0..<count {
    out.push(values[start + i])
  }
  out
}

///|
fn[K : Eq, V] lookup(key : K, pairs : Array[(K, V)]) -> V? {
  for pair in pairs {
    if pair.0 == key {
      return Some(pair.1)
    }
  }
  None
}

///|
fn[K : Eq, V] lookup_fail(
  key : K,
  pairs : Array[(K, V)],
  err : String,
) -> V raise {
  match lookup(key, pairs) {
    Some(value) => value
    None => raise @pdf.PdfError::Msg(err)
  }
}

///|
fn[A, B] combine(left : Array[A], right : Array[B]) -> Array[(A, B)] raise {
  if left.length() != right.length() {
    raise @pdf.PdfError::Msg("combine: length mismatch")
  }
  let out = Array::new(capacity=left.length())
  for i in 0..<left.length() {
    out.push((left[i], right[i]))
  }
  out
}

///|

///|
fn[T] collate(items : Array[T], cmp : (T, T) -> Int) -> Array[Array[T]] {
  let out = Array::new()
  let mut i = 0
  while i < items.length() {
    let group = Array::new()
    group.push(items[i])
    let mut j = i + 1
    while j < items.length() && cmp(items[i], items[j]) == 0 {
      group.push(items[j])
      j = j + 1
    }
    out.push(group)
    i = j
  }
  out
}

///|
fn setify_strings(values : Array[String]) -> Array[String] {
  let seen = Map::new(capacity=values.length())
  let out = Array::new()
  for value in values {
    if seen.get(value) is None {
      seen.set(value, ())
      out.push(value)
    }
  }
  out
}

///|
fn remove_entry(
  entries : Array[(String, @pdf.PdfObject)],
  key : String,
) -> Array[(String, @pdf.PdfObject)] {
  let out = Array::new()
  for entry in entries {
    if entry.0 != key {
      out.push(entry)
    }
  }
  out
}

///|
fn add_entry(
  entries : Array[(String, @pdf.PdfObject)],
  key : String,
  value : @pdf.PdfObject,
) -> Array[(String, @pdf.PdfObject)] {
  let out = Array::new()
  let mut replaced = false
  for entry in entries {
    if entry.0 == key {
      out.push((key, value))
      replaced = true
    } else {
      out.push(entry)
    }
  }
  if !replaced {
    out.push((key, value))
  }
  out
}

///|
fn stream_compare(pdf : @pdf.Pdf, x : Int, y : Int) -> Int {
  try {
    let xobj = @pdf.lookup_obj(pdf, x)
    let yobj = @pdf.lookup_obj(pdf, y)
    @pdf.getstream(xobj)
    @pdf.getstream(yobj)
    match (xobj, yobj) {
      (@pdf.PdfObject::Stream(rx), @pdf.PdfObject::Stream(ry)) => {
        let (dict, stream_x) = rx.val
        let (dict2, stream_y) = ry.val
        match (stream_x, stream_y) {
          (@pdf.Stream::Got(bytes), @pdf.Stream::Got(bytes2)) => {
            let dict_s = @pdfwrite.string_of_pdf(dict)
            let dict_s2 = @pdfwrite.string_of_pdf(dict2)
            let cmp = String::compare(dict_s, dict_s2)
            if cmp != 0 {
              cmp
            } else {
              compare_bytes(bytes, bytes2)
            }
          }
          _ => 0
        }
      }
      _ => 0
    }
  } catch {
    _ => 0
  }
}

///|
/// Remove duplicate fonts from a PDF.
pub fn remove_duplicate_fonts(pdf : @pdf.Pdf) -> Unit {
  let streamobjs = Array::new()
  @pdf.objiter(
    (objnum, obj) => match obj {
      @pdf.PdfObject::Stream(_) => streamobjs.push(objnum)
      _ => ()
    },
    pdf,
  )
  let sorted = streamobjs
  sorted.sort_by((a, b) => stream_compare(pdf, a, b))
  let groups = collate(sorted, (a, b) => stream_compare(pdf, a, b))
  let toprocess = groups.filter(group => group.length() > 1)
  if toprocess.length() == 0 {
    return
  }
  let mut current = pdf
  for group in toprocess {
    let changetable : Map[Int, Int] = Map::new()
    let keep = group[0]
    for i in 1..<group.length() {
      changetable.set(group[i], keep)
    }
    current = @pdf.renumber(changetable, current)
  }
  let existing = pdf.objects.objects.to_array()
  for entry in existing {
    pdf.objects.objects.remove(entry.0)
  }
  for entry in current.objects.objects {
    pdf.objects.objects.set(entry.0, entry.1)
  }
  let existing_ids = pdf.objects.object_stream_ids.to_array()
  for entry in existing_ids {
    pdf.objects.object_stream_ids.remove(entry.0)
  }
  for entry in current.objects.object_stream_ids {
    pdf.objects.object_stream_ids.set(entry.0, entry.1)
  }
  pdf.objects.max_obj_num = current.objects.max_obj_num
  pdf.trailerdict = current.trailerdict
}

///|
fn new_dests(pdf : @pdf.Pdf, pdfs : Array[@pdf.Pdf]) -> Int? raise {
  let dests = Array::new()
  for src in pdfs {
    let catalog = @pdf.catalog_of_pdf(src)
    match @pdf.lookup_direct(src, "/Dests", catalog) {
      Some(@pdf.PdfObject::Dictionary(d)) => dests.push(d)
      _ => ()
    }
  }
  if dests.length() == 0 {
    None
  } else {
    let merged = @pdf.PdfObject::Dictionary(flatten(dests))
    Some(@pdf.addobj(pdf, merged))
  }
}

///|
fn merge_pdfs_renumber(
  names : Array[String],
  pdfs : Array[@pdf.Pdf],
) -> Array[@pdf.Pdf] raise {
  if names.length() != pdfs.length() {
    raise @pdf.PdfError::Msg("merge_pdfs_renumber: length mismatch")
  }
  let table : Map[String, @pdf.Pdf] = Map::new()
  for i in 0..<names.length() {
    table.set(names[i], pdfs[i])
  }
  let unique_names = Array::new()
  let unique_pdfs = Array::new()
  for name, pdf in table {
    unique_names.push(name)
    unique_pdfs.push(pdf)
  }
  let renumbered = @pdf.renumber_pdfs(unique_pdfs)
  let mapping : Map[String, @pdf.Pdf] = Map::new()
  for i, name in unique_names {
    mapping.set(name, renumbered[i])
  }
  let out = Array::new(capacity=names.length())
  for name in names {
    match mapping.get(name) {
      Some(pdf) => out.push(pdf)
      None => raise @pdf.PdfError::Msg("merge_pdfs_renumber: missing mapping")
    }
  }
  out
}

///|
fn merge_namedicts(pdf : @pdf.Pdf, pdfs : Array[@pdf.Pdf]) -> Int raise {
  let names : Array[String] = [
    "/Dests", "/AP", "/JavaScript", "/Pages", "/Templates", "/IDS", "/URLS", "/EmbeddedFiles",
    "/AlternatePresentations", "/Renditions",
  ]
  let trees = Array::new()
  for name in names {
    let trees_for_name = Array::new()
    for src in pdfs {
      let catalog = @pdf.catalog_of_pdf(src)
      match @pdf.lookup_direct(src, "/Names", catalog) {
        Some(dict) =>
          match @pdf.lookup_direct(src, name, dict) {
            Some(tree) => trees_for_name.push(tree)
            None => ()
          }
        None => ()
      }
    }
    if trees_for_name.length() > 0 {
      trees.push((name, trees_for_name))
    }
  }
  let new_entries = Array::new()
  let tree_ctx = @pdftree.PdfTree::new(pdf)
  for pair in trees {
    let merged = tree_ctx.merge_name_trees_no_clash(pair.1)
    let num = @pdf.addobj(pdf, merged)
    new_entries.push((pair.0, @pdf.PdfObject::Indirect(num)))
  }
  let newdict = @pdf.PdfObject::Dictionary(new_entries)
  @pdf.addobj(pdf, newdict)
}

///|
fn merge_bookmarks(
  changes : Array[(Int, Int)],
  pdfs : Array[@pdf.Pdf],
  ranges : Array[Array[Int]],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf {
  try {
    let tree_ctx = @pdftree.PdfTree::new(pdf)
    let dest_nametree = {
      let catalog = @pdf.catalog_of_pdf(pdf)
      let oldstyle = match @pdf.lookup_direct(pdf, "/Dests", catalog) {
        Some(d) => tree_ctx.read_name_tree(d)
        _ => []
      }
      let newstyle = match @pdf.lookup_direct(pdf, "/Names", catalog) {
        Some(d) =>
          match @pdf.lookup_direct(pdf, "/Dests", d) {
            Some(d2) => tree_ctx.read_name_tree(d2)
            _ => []
          }
        _ => []
      }
      let out = Array::new()
      out.append(oldstyle[:])
      out.append(newstyle[:])
      out
    }
    fn process_mark(
      oldnums : Array[Int],
      changes : Array[(Int, Int)],
      mark : @pdfmarks.Bookmark,
    ) -> @pdfmarks.Bookmark? raise {
      let changes_rev = changes.map(pair => (pair.1, pair.0))
      fn pageobjectnumber_of_target(t : @pdfdest.Destination) -> Int raise {
        match t {
          NullDestination => 0
          NamedDestination(s) | StringDestination(s) =>
            match lookup(s, dest_nametree) {
              Some(dest) =>
                match @pdf.lookup_direct(pdf, "/D", dest) {
                  Some(dest_obj) => {
                    let r = pageobjectnumber_of_target(
                      @pdfdest.Destination::read(pdf, dest_obj),
                    )
                    match lookup(r, changes_rev) {
                      Some(old) => old
                      None => r
                    }
                  }
                  None => 0
                }
              None => 0
            }
          Action(a) =>
            match @pdf.lookup_direct(pdf, "/S", a) {
              Some(@pdf.PdfObject::Name("/GoTo")) =>
                match @pdf.lookup_direct(pdf, "/D", a) {
                  Some(@pdf.PdfObject::String(s)) =>
                    match lookup(s, dest_nametree) {
                      Some(dest) =>
                        match @pdf.lookup_direct(pdf, "/D", dest) {
                          Some(dest_obj) => {
                            let r = pageobjectnumber_of_target(
                              @pdfdest.Destination::read(pdf, dest_obj),
                            )
                            match lookup(r, changes_rev) {
                              Some(old) => old
                              None => r
                            }
                          }
                          None => 0
                        }
                      None => 0
                    }
                  _ => 0
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
              OtherDocPageNumber(_) => 0
              PageObject(i) => i
            }
        }
      }

      let objnum = pageobjectnumber_of_target(mark.target)
      let is_null = (mark.target : @pdfdest.Destination) is NullDestination
      if contains_int(oldnums, objnum) || is_null {
        let change_targetpage = fn(
          target : @pdfdest.TargetPage,
          newnum : Int,
        ) -> @pdfdest.TargetPage {
          match target {
            OtherDocPageNumber(n) => OtherDocPageNumber(n)
            PageObject(_) => PageObject(newnum)
          }
        }
        let change_target_destinationpage = fn(
          target : @pdfdest.Destination,
          newnum : Int,
        ) -> @pdfdest.Destination {
          match target {
            Action(a) => Action(a)
            NullDestination => NullDestination
            NamedDestination(s) => NamedDestination(s)
            StringDestination(s) => StringDestination(s)
            XYZ(tp, a, b, c) => XYZ(change_targetpage(tp, newnum), a, b, c)
            Fit(tp) => Fit(change_targetpage(tp, newnum))
            FitH(tp, a) => FitH(change_targetpage(tp, newnum), a)
            FitV(tp, a) => FitV(change_targetpage(tp, newnum), a)
            FitR(tp, a, b, c, d) =>
              FitR(change_targetpage(tp, newnum), a, b, c, d)
            FitB(tp) => FitB(change_targetpage(tp, newnum))
            FitBH(tp, a) => FitBH(change_targetpage(tp, newnum), a)
            FitBV(tp, a) => FitBV(change_targetpage(tp, newnum), a)
          }
        }
        let new_target : @pdfdest.Destination = if is_null {
          NullDestination
        } else {
          let newnum = lookup_fail(
            objnum, changes, "merge_bookmarks: missing change",
          )
          change_target_destinationpage(mark.target, newnum)
        }
        Some({
          level: mark.level,
          text: mark.text,
          target: new_target,
          isopen: mark.isopen,
          colour: mark.colour,
          flags: mark.flags,
        })
      } else {
        None
      }
    }

    let bookmarks = Array::new()
    let mut offset = 0
    for i in 0..<pdfs.length() {
      let range = ranges[i]
      let subset_changes = slice(changes, offset, range.length())
      let subset_oldnums = subset_changes.map(pair => pair.0)
      let marks = @pdfmarks.read_bookmarks(pdfs[i], preserve_actions=true)
      for mark in marks {
        match process_mark(subset_oldnums, subset_changes, mark) {
          Some(updated) => bookmarks.push(updated)
          None => ()
        }
      }
      offset = offset + range.length()
    }
    @pdfmarks.add_bookmarks(bookmarks, pdf)
  } catch {
    _ => {
      @pdfe.log("failure in merge_bookmarks\n")
      pdf
    }
  }
}

///|
fn apply_namechanges_to_destination_nametree(
  pdf : @pdf.Pdf,
  changes : Array[(String, String)],
) -> Unit raise {
  let changes_map : Map[String, String] = Map::new()
  for pair in changes {
    changes_map.set(pair.0, pair.1)
  }
  fn rewrite_string(s : String) -> String {
    match changes_map.get(s) {
      Some(r) => r
      None => {
        @pdfe.log(
          "apply_namechanges_to_destination_nametree: destination not found: \{s}\n",
        )
        s
      }
    }
  }

  fn pairs_of_array(
    values : Array[@pdf.PdfObject],
  ) -> Array[(@pdf.PdfObject, @pdf.PdfObject)]? {
    if values.length() % 2 == 1 {
      return None
    }
    let out = Array::new()
    for i = 0; i + 1 < values.length(); i = i + 2 {
      out.push((values[i], values[i + 1]))
    }
    Some(out)
  }

  fn rewrite(dict : @pdf.PdfObject) -> @pdf.PdfObject {
    let entries = match dict {
      @pdf.PdfObject::Dictionary(e) => e
      _ => return dict
    }
    let mut updated = entries
    match lookup("/Names", updated) {
      Some(@pdf.PdfObject::Array(values)) =>
        match pairs_of_array(values) {
          Some(pairs) => {
            let updated_pairs = pairs.map(pair => match pair {
              (@pdf.PdfObject::String(s), obj) =>
                (@pdf.PdfObject::String(rewrite_string(s)), obj)
              _ => pair
            })
            let rebuilt = Array::new(capacity=values.length())
            for pair in updated_pairs {
              rebuilt.push(pair.0)
              rebuilt.push(pair.1)
            }
            updated = add_entry(
              updated,
              "/Names",
              @pdf.PdfObject::Array(rebuilt),
            )
          }
          None => @pdfe.log("Warning: malformed /Names")
        }
      _ => ()
    }
    match lookup("/Limits", updated) {
      Some(
        @pdf.PdfObject::Array(
          [@pdf.PdfObject::String(a), @pdf.PdfObject::String(b)]
        )
      ) =>
        updated = add_entry(
          updated,
          "/Limits",
          @pdf.PdfObject::Array([
            @pdf.PdfObject::String(rewrite_string(a)),
            @pdf.PdfObject::String(rewrite_string(b)),
          ]),
        )
      _ => ()
    }
    match lookup("/Kids", updated) {
      Some(@pdf.PdfObject::Array(kids)) =>
        for kid in kids {
          match kid {
            @pdf.PdfObject::Indirect(i) =>
              @pdf.addobj_given_num(
                pdf,
                (i, rewrite(@pdf.direct(pdf, @pdf.PdfObject::Indirect(i)))),
              )
            _ => ()
          }
        }
      _ => ()
    }
    @pdf.PdfObject::Dictionary(updated)
  }

  let catalog = @pdf.catalog_of_pdf(pdf)
  match @pdf.lookup_direct(pdf, "/Names", catalog) {
    Some(@pdf.PdfObject::Dictionary(d)) =>
      match lookup("/Dests", d) {
        Some(@pdf.PdfObject::Dictionary(dest_dict)) => {
          let newdest = rewrite(@pdf.PdfObject::Dictionary(dest_dict))
          let newcatalog = catalog.add_entry("/Dests", newdest)
          @pdf.addobj_given_num(pdf, (pdf.root, newcatalog))
        }
        Some(@pdf.PdfObject::Indirect(i)) =>
          @pdf.addobj_given_num(
            pdf,
            (i, rewrite(@pdf.direct(pdf, @pdf.PdfObject::Indirect(i)))),
          )
        _ => ()
      }
    _ => ()
  }
}

///|
fn apply_namechanges_at_destination_callsites(
  pdf : @pdf.Pdf,
  changes : Array[(String, String)],
  allchanges : Array[(String, String)],
) -> Unit {
  let changes_map : Map[String, String] = Map::new()
  for pair in changes {
    changes_map.set(pair.0, pair.1)
  }
  let allchanges_map : Map[String, String] = Map::new()
  for i in (allchanges.length() - 1)>=..0 {
    let pair = allchanges[i]
    allchanges_map.set(pair.0, pair.1)
  }
  fn rewrite_string(s : String) -> String {
    match changes_map.get(s) {
      Some(r) => r
      None =>
        match allchanges_map.get(s) {
          Some(r) => r
          None => s
        }
    }
  }

  fn f(obj : @pdf.PdfObject) -> @pdf.PdfObject {
    match obj {
      @pdf.PdfObject::Dictionary(entries) => {
        let updated = Array::new(capacity=entries.length())
        for entry in entries {
          updated.push((entry.0, f(entry.1)))
        }
        let updated = match lookup("/S", updated) {
          Some(@pdf.PdfObject::Name("/GoTo")) =>
            match lookup("/D", updated) {
              Some(@pdf.PdfObject::String(s)) =>
                add_entry(
                  updated,
                  "/D",
                  @pdf.PdfObject::String(rewrite_string(s)),
                )
              _ => updated
            }
          _ => updated
        }
        match lookup("/Dest", updated) {
          Some(@pdf.PdfObject::String(s)) =>
            @pdf.PdfObject::Dictionary(
              add_entry(
                updated,
                "/Dest",
                @pdf.PdfObject::String(rewrite_string(s)),
              ),
            )
          _ => @pdf.PdfObject::Dictionary(updated)
        }
      }
      @pdf.PdfObject::Array(values) => @pdf.recurse_array(f, values)
      _ => obj
    }
  }

  @pdf.objselfmap(f, pdf)
  pdf.trailerdict = f(pdf.trailerdict)
}

///|
fn merge_pdfs_rename_name_trees(
  names : Array[String],
  pdfs : Array[@pdf.Pdf],
) -> Unit raise {
  let pairs = combine(names, pdfs)
  pairs.sort_by((a, b) => String::compare(a.0, b.0))
  let groups = collate(pairs, (a, b) => String::compare(a.0, b.0))
  let unique_pdfs = groups.map(group => group[0].1)
  let pdfs_and_nametrees = unique_pdfs.map(pdf => {
    let catalog = @pdf.catalog_of_pdf(pdf)
    match @pdf.lookup_direct(pdf, "/Names", catalog) {
      Some(d) =>
        match @pdf.lookup_direct(pdf, "/Dests", d) {
          Some(@pdf.PdfObject::Dictionary(dict)) =>
            (pdf, Some(@pdf.PdfObject::Dictionary(dict)))
          _ => (pdf, None)
        }
      _ => (pdf, None)
    }
  })
  let name_lists = pdfs_and_nametrees.map(pair => match pair.1 {
    Some(tree) =>
      (pair.0, @pdftree.PdfTree::new(pair.0).read_name_tree(tree).map(p => p.0))
    None => (pair.0, [])
  })
  fn worked(values : Array[(@pdf.Pdf, Array[(String, String)])]) -> Bool {
    let all = flatten(values.map(pair => pair.1.map(item => item.1)))
    setify_strings(all).length() == all.length()
  }

  let mut num = -1
  let mut renamed = name_lists.map(pair => (
    pair.0,
    pair.1.map(name => (name, name)),
  ))
  while !worked(renamed) {
    num = num + 1
    let indexes = ilist(num, num + renamed.length() - 1)
    let updated = Array::new(capacity=renamed.length())
    for i, pair in renamed {
      let suffix = "-f" + indexes[i].to_string()
      let mapped = pair.1.map(entry => (entry.0, entry.0 + suffix))
      updated.push((pair.0, mapped))
    }
    renamed = updated
  }
  for pair in renamed {
    apply_namechanges_to_destination_nametree(pair.0, pair.1)
  }
  let allchanges = flatten(renamed.map(pair => pair.1))
  for pair in renamed {
    apply_namechanges_at_destination_callsites(pair.0, pair.1, allchanges)
  }
}

///|
fn catalog_items_from_original_documents(
  pdfs : Array[@pdf.Pdf],
) -> Array[(String, @pdf.PdfObject)] raise {
  let out : Array[(String, @pdf.PdfObject)] = Array::new()
  for pdf in pdfs {
    match @pdf.catalog_of_pdf(pdf) {
      @pdf.PdfObject::Dictionary(entries) =>
        for entry in entries {
          let mut replaced = false
          let mut i = 0
          while i < out.length() {
            if out[i].0 == entry.0 {
              out[i] = entry
              replaced = true
              break
            }
            i = i + 1
          }
          if !replaced {
            out.push(entry)
          }
        }
      _ => raise @pdf.PdfError::Msg("catalog_items_from_original_documents")
    }
  }
  out
}

///|
fn merge_entries(
  pdf : @pdf.Pdf,
  name : String,
  dicts : Array[@pdf.PdfObject],
) -> Array[@pdf.PdfObject] {
  let out = Array::new()
  for dict in dicts {
    match @pdf.lookup_direct(pdf, name, dict) {
      Some(@pdf.PdfObject::Array(arr)) => out.append(arr[:])
      _ => ()
    }
  }
  out
}

///|
fn merge_default_dictionaries(
  pdf : @pdf.Pdf,
  dicts : Array[@pdf.PdfObject],
) -> Array[(String, @pdf.PdfObject)] {
  fn merge_empty_is_none(name : String) -> Array[(String, @pdf.PdfObject)] {
    let arrays = Array::new()
    for dict in dicts {
      match @pdf.lookup_direct(pdf, name, dict) {
        Some(@pdf.PdfObject::Array(arr)) => arrays.push(arr)
        _ => ()
      }
    }
    if arrays.length() == 0 {
      []
    } else {
      [(name, @pdf.PdfObject::Array(flatten(arrays)))]
    }
  }

  let merged_on = merge_empty_is_none("/ON")
  let merged_off = merge_empty_is_none("/OFF")
  let merged_order = merge_empty_is_none("/Order")
  let merged_rbgroups = merge_empty_is_none("/RBGroups")
  let keys : Array[String] = [
    "/Locked", "/ListMode", "/AS", "/Intent", "/BaseState", "/Creator", "/Name",
  ]
  let simple_copies = Array::new()
  for key in keys {
    let mut found = None
    for dict in dicts {
      match @pdf.lookup_direct(pdf, key, dict) {
        Some(obj) => {
          found = Some(obj)
          break
        }
        None => ()
      }
    }
    match found {
      Some(obj) => simple_copies.push((key, obj))
      None => ()
    }
  }
  let out = Array::new()
  out.append(merged_on[:])
  out.append(merged_off[:])
  out.append(merged_order[:])
  out.append(merged_rbgroups[:])
  out.append(simple_copies[:])
  out
}

///|
fn merge_optional_content_groups(
  pdf : @pdf.Pdf,
  pdfs : Array[@pdf.Pdf],
) -> Int? raise {
  let ocp_dicts = Array::new()
  for src in pdfs {
    match @pdf.lookup_direct(src, "/OCProperties", @pdf.catalog_of_pdf(src)) {
      Some(obj) => ocp_dicts.push(obj)
      None => ()
    }
  }
  if ocp_dicts.length() == 0 {
    return None
  }
  let merged_ocg_arrays = merge_entries(pdf, "/OCGs", ocp_dicts)
  let merged_config_arrays = merge_entries(pdf, "/Configs", ocp_dicts)
  let default_dicts = Array::new()
  for dict in ocp_dicts {
    match @pdf.lookup_direct(pdf, "/D", dict) {
      Some(obj) => default_dicts.push(obj)
      None => ()
    }
  }
  let merged_default_dictionary = merge_default_dictionaries(pdf, default_dicts)
  let entries = Array::new()
  entries.push(("/OCGs", @pdf.PdfObject::Array(merged_ocg_arrays)))
  entries.push(("/D", @pdf.PdfObject::Dictionary(merged_default_dictionary)))
  if merged_config_arrays.length() > 0 {
    entries.push(("/Configs", @pdf.PdfObject::Array(merged_config_arrays)))
  }
  let new_ocproperties = @pdf.PdfObject::Dictionary(entries)
  Some(@pdf.addobj(pdf, new_ocproperties))
}

///|
fn merge_acroforms(pdf : @pdf.Pdf, pdfs : Array[@pdf.Pdf]) -> Int? raise {
  let form_dicts = Array::new()
  for src in pdfs {
    match @pdf.lookup_direct(src, "/AcroForm", @pdf.catalog_of_pdf(src)) {
      Some(obj) => form_dicts.push(obj)
      None => ()
    }
  }
  if form_dicts.length() == 0 {
    return None
  }
  let merged_field_arrays = Array::new()
  for dict in form_dicts {
    match @pdf.lookup_direct(pdf, "/Fields", dict) {
      Some(@pdf.PdfObject::Array(arr)) => merged_field_arrays.append(arr[:])
      _ => ()
    }
  }
  let mut merged_nonfield_items = @pdf.PdfObject::Dictionary([])
  for dict in form_dicts {
    match dict {
      @pdf.PdfObject::Dictionary(entries) =>
        for entry in entries {
          merged_nonfield_items = merged_nonfield_items.add_entry(
            entry.0,
            entry.1,
          )
        }
      _ => ()
    }
  }
  let new_dict = merged_nonfield_items.add_entry(
    "/Fields",
    @pdf.PdfObject::Array(merged_field_arrays),
  )
  Some(@pdf.addobj(pdf, new_dict))
}

///|
fn max_version_number(pdfs : Array[@pdf.Pdf]) -> (Int, Int) raise {
  if pdfs.length() == 0 {
    raise @pdf.PdfError::Msg("max_version_number: empty")
  }
  let mut major = pdfs[0].major
  let mut minor = pdfs[0].minor
  for pdf in pdfs {
    if pdf.major > major || (pdf.major == major && pdf.minor > minor) {
      major = pdf.major
      minor = pdf.minor
    }
  }
  (major, minor)
}

///|
/// Merge PDF files.
pub fn merge_pdfs(
  retain_numbering : Bool,
  do_remove_duplicate_fonts : Bool,
  process_struct_trees? : Bool = true,
  add_toplevel_document? : Bool = false,
  names : Array[String],
  pdfs : Array[@pdf.Pdf],
  ranges : Array[Array[Int]],
) -> @pdf.Pdf raise {
  if process_struct_trees && setify_strings(names).length() < names.length() {
    @pdfe.log(
      "Warning: multiply-included files will not merge structure trees properly.\n",
    )
  }
  if process_struct_trees {
    for i, pdf in pdfs {
      @pdfst.trim_structure_tree(pdf, ranges[i])
    }
    @pdfst.renumber_parent_trees(pdfs)
  }
  let pdfs = merge_pdfs_renumber(names, pdfs)
  merge_pdfs_rename_name_trees(names, pdfs)
  let (major, minor) = max_version_number(pdfs)
  let pagelists = pdfs.map(pdf => @pdfpage.pages_of_pagetree(pdf))
  let pdf = @pdf.Pdf::empty()
  fn select_pages(
    range : Array[Int],
    pagelist : Array[@pdfpage.Page],
  ) -> Array[@pdfpage.Page] raise {
    let out = Array::new()
    for n in range {
      if n <= 0 || n > pagelist.length() {
        raise @pdf.PdfError::Msg("merge_pdfs: page out of range")
      }
      out.push(pagelist[n - 1])
    }
    out
  }

  let pages = Array::new()
  for i, range in ranges {
    let selected = select_pages(range, pagelists[i])
    pages.append(selected[:])
  }
  for src in pdfs {
    @pdf.objiter((k, v) => @pdf.addobj_given_num(pdf, (k, v)), src)
  }
  let (pdf, pagetree_num) = @pdfpage.add_pagetree(pages, pdf)
  let page_labels = if retain_numbering {
    @pdfpagelabels.merge_pagelabels(pdfs, ranges)
  } else {
    []
  }
  let dests = new_dests(pdf, pdfs)
  let namedict = merge_namedicts(pdf, pdfs)
  let mut extra_catalog_entries = catalog_items_from_original_documents(pdfs)
  extra_catalog_entries = add_entry(
    extra_catalog_entries,
    "/Names",
    @pdf.PdfObject::Indirect(namedict),
  )
  match dests {
    None => ()
    Some(num) =>
      extra_catalog_entries = add_entry(
        extra_catalog_entries,
        "/Dests",
        @pdf.PdfObject::Indirect(num),
      )
  }
  extra_catalog_entries = try {
    match merge_optional_content_groups(pdf, pdfs) {
      None => extra_catalog_entries
      Some(ocgnum) =>
        add_entry(
          extra_catalog_entries,
          "/OCProperties",
          @pdf.PdfObject::Indirect(ocgnum),
        )
    }
  } catch {
    _ => {
      @pdfe.log("Warning: failed to merge OCGs\n")
      extra_catalog_entries
    }
  }
  extra_catalog_entries = try {
    match merge_acroforms(pdf, pdfs) {
      None => extra_catalog_entries
      Some(formnum) =>
        add_entry(
          extra_catalog_entries,
          "/AcroForm",
          @pdf.PdfObject::Indirect(formnum),
        )
    }
  } catch {
    _ => {
      @pdfe.log("Warning: failed to merge Acroforms\n")
      extra_catalog_entries
    }
  }
  let extra_catalog_entries = if !process_struct_trees {
    extra_catalog_entries
  } else {
    try {
      match @pdfst.merge_structure_trees(pdf, pdfs, add_toplevel_document~) {
        None => extra_catalog_entries
        Some(structnum) =>
          add_entry(
            extra_catalog_entries,
            "/StructTreeRoot",
            @pdf.PdfObject::Indirect(structnum),
          )
      }
    } catch {
      _ => {
        @pdfe.log("Warning: failed to merge structure tree roots\n")
        extra_catalog_entries
      }
    }
  }
  let extra_catalog_entries = remove_entry(extra_catalog_entries, "/OpenAction")
  match @pdf.lookup_direct(pdfs[0], "/Info", pdfs[0].trailerdict) {
    None => ()
    Some(info) =>
      pdf.trailerdict = @pdf.PdfObject::Dictionary([
        ("/Info", @pdf.PdfObject::Indirect(@pdf.addobj(pdf, info))),
      ])
  }
  let pdf = @pdfpage.add_root(pagetree_num, extra_catalog_entries, pdf)
  let old_page_numbers = {
    let page_nums = pdfs.map(p => @pdf.page_reference_numbers(p))
    let out = Array::new()
    for i, range in ranges {
      let numbers = page_nums[i]
      for n in range {
        if n <= 0 || n > numbers.length() {
          raise @pdf.PdfError::Msg("merge_pdfs: page out of range")
        }
        out.push(numbers[n - 1])
      }
    }
    out
  }
  let new_page_numbers = @pdf.page_reference_numbers(pdf)
  let changes = combine(old_page_numbers, new_page_numbers)
  let changes_map : Map[Int, Int] = Map::new()
  for pair in changes {
    changes_map.set(pair.0, pair.1)
  }
  @pdf.objselfmap(
    obj => @pdf.renumber_object_parsed(
      pdf,
      changes_map,
      obj,
      preserve_order=false,
    ),
    pdf,
  )
  let pdf : @pdf.Pdf = {
    major,
    minor,
    root: pdf.root,
    objects: pdf.objects,
    trailerdict: pdf.trailerdict,
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
  let pdf = merge_bookmarks(changes, pdfs, ranges, pdf)
  @pdfpagelabels.PageLabel::write_all(page_labels, pdf)
  if do_remove_duplicate_fonts {
    remove_duplicate_fonts(pdf)
  }
  @pdf.change_id(pdf, "")
  pdf
}
