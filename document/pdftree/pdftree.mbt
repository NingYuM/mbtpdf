///|
/// Read a name tree as a flat (key, value) list.
pub fn read_name_tree(
  pdf : @pdf.Pdf,
  tree : @pdf.PdfObject,
) -> Array[(String, @pdf.PdfObject)] {
  read_tree_strings(pdf, tree, false)
}

///|
/// Read a number tree as a flat (key, value) list (numbers as strings).
pub fn read_number_tree(
  pdf : @pdf.Pdf,
  tree : @pdf.PdfObject,
) -> Array[(String, @pdf.PdfObject)] {
  read_tree_strings(pdf, tree, true)
}

///|
/// Build a name or number tree from flat (key, value) list.
pub fn build_name_tree(
  isnum : Bool,
  pdf : @pdf.Pdf,
  entries : Array[(String, @pdf.PdfObject)],
) -> @pdf.PdfObject {
  if entries.length() == 0 {
    if isnum {
      @pdf.PdfObject::Dictionary([("/Nums", @pdf.PdfObject::Array([]))])
    } else {
      @pdf.PdfObject::Dictionary([("/Names", @pdf.PdfObject::Array([]))])
    }
  } else {
    let sorted = clone_entries(entries)
    if isnum {
      sorted.sort_by((a, b) => parse_int(a.0) - parse_int(b.0))
    } else {
      sorted.sort_by((a, b) => compare_string(a.0, b.0))
    }
    let nt = build_nt_tree(sorted)
    let tree_obj = name_tree_of_nt(isnum, true, pdf, nt)
    try tree_obj.remove_entry("/Limits") catch {
      _ => tree_obj
    } noraise {
      updated => updated
    }
  }
}

///|
/// Merge name trees assuming no duplicate keys.
pub fn merge_name_trees_no_clash(
  pdf : @pdf.Pdf,
  trees : Array[@pdf.PdfObject],
) -> @pdf.PdfObject {
  let entries = flatten(trees.map(tree => read_name_tree(pdf, tree)))
  build_name_tree(false, pdf, entries)
}

///|
/// Merge number trees assuming no duplicate keys.
pub fn merge_number_trees_no_clash(
  pdf : @pdf.Pdf,
  trees : Array[@pdf.PdfObject],
) -> @pdf.PdfObject {
  let entries = flatten(trees.map(tree => read_number_tree(pdf, tree)))
  build_name_tree(true, pdf, entries)
}

///|
fn read_tree_raw(
  pdf : @pdf.Pdf,
  tree : @pdf.PdfObject,
) -> Array[(@pdf.PdfObject, @pdf.PdfObject)] {
  let names = match @pdf.lookup_direct_orelse(pdf, "/Names", "/Nums", tree) {
    Some(@pdf.PdfObject::Array(elts)) =>
      if elts.length() % 2 == 1 {
        @pdfe.log("Bad /Names array. Name tree will be read as empty\n")
        []
      } else {
        pairs_of_array(elts)
      }
    _ => []
  }
  match @pdf.lookup_direct(pdf, "/Kids", tree) {
    Some(@pdf.PdfObject::Array(kids)) =>
      concat_arrays(names, flatten(kids.map(kid => read_tree_raw(pdf, kid))))
    _ => names
  }
}

///|
fn read_tree_strings(
  pdf : @pdf.Pdf,
  tree : @pdf.PdfObject,
  isnum : Bool,
) -> Array[(String, @pdf.PdfObject)] {
  let raw = read_tree_raw(pdf, tree)
  let sorted = clone_pairs(raw)
  if isnum {
    sorted.sort_by((a, b) => key_int(a.0) - key_int(b.0))
  } else {
    sorted.sort_by((a, b) => compare_string(key_string(a.0), key_string(b.0)))
  }
  let deduped = remove_duplicates(sorted, isnum)
  let out = Array::new()
  for pair in deduped {
    let key = pair.0
    let value = pair.1
    match key {
      @pdf.PdfObject::Integer(i) if isnum => out.push((i.to_string(), value))
      @pdf.PdfObject::String(s) if !isnum => out.push((s, value))
      _ => {
        let msg = if isnum {
          "Pdftree.read_number_tree: skipping malformed number tree\n"
        } else {
          "Pdftree.read_name_tree: skipping malformed name tree\n"
        }
        @pdfe.log(msg)
        return []
      }
    }
  }
  out
}

///|
fn key_int(obj : @pdf.PdfObject) -> Int {
  match obj {
    @pdf.PdfObject::Integer(i) => i
    _ => 0
  }
}

///|
fn key_string(obj : @pdf.PdfObject) -> String {
  match obj {
    @pdf.PdfObject::String(s) => s
    _ => ""
  }
}

///|
fn parse_int(value : String) -> Int {
  try @strconv.parse_int(value) catch {
    _ => 0
  } noraise {
    v => v
  }
}

///|
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
fn remove_duplicates(
  items : Array[(@pdf.PdfObject, @pdf.PdfObject)],
  isnum : Bool,
) -> Array[(@pdf.PdfObject, @pdf.PdfObject)] {
  if items.length() == 0 {
    return []
  }
  let out = Array::new()
  let mut prev = items[0]
  for i in 1..<items.length() {
    let current = items[i]
    let same = if isnum {
      key_int(prev.0) == key_int(current.0)
    } else {
      key_string(prev.0) == key_string(current.0)
    }
    if same {
      prev = current
    } else {
      out.push(prev)
      prev = current
    }
  }
  out.push(prev)
  out
}

///|
fn pairs_of_array(
  arr : Array[@pdf.PdfObject],
) -> Array[(@pdf.PdfObject, @pdf.PdfObject)] {
  let out = Array::new()
  for i = 0; i + 1 < arr.length(); i = i + 2 {
    out.push((arr[i], arr[i + 1]))
  }
  out
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
fn[T] concat_arrays(a : Array[T], b : Array[T]) -> Array[T] {
  let out = Array::new(capacity=a.length() + b.length())
  for item in a {
    out.push(item)
  }
  for item in b {
    out.push(item)
  }
  out
}

///|
let maxsize : Int = 10

///|
priv enum Nt {
  Branch(String, Array[Nt], String)
  Leaf(String, Array[(String, @pdf.PdfObject)], String)
}

///|
fn build_nt_tree(items : Array[(String, @pdf.PdfObject)]) -> Nt {
  if items.length() == 0 {
    return Nt::Leaf("", [], "")
  }
  if items.length() <= maxsize {
    Nt::Leaf(items[0].0, items, items[items.length() - 1].0)
  } else {
    let groups = split_into(items, maxsize)
    let subtrees = Array::new()
    for group in groups {
      subtrees.push(build_nt_tree(group))
    }
    Nt::Branch(items[0].0, subtrees, items[items.length() - 1].0)
  }
}

///|
fn clone_entries(
  entries : Array[(String, @pdf.PdfObject)],
) -> Array[(String, @pdf.PdfObject)] {
  let out = Array::new(capacity=entries.length())
  for entry in entries {
    out.push(entry)
  }
  out
}

///|
fn clone_pairs(
  entries : Array[(@pdf.PdfObject, @pdf.PdfObject)],
) -> Array[(@pdf.PdfObject, @pdf.PdfObject)] {
  let out = Array::new(capacity=entries.length())
  for entry in entries {
    out.push(entry)
  }
  out
}

///|
fn split_into(
  items : Array[(String, @pdf.PdfObject)],
  group_size : Int,
) -> Array[Array[(String, @pdf.PdfObject)]] {
  let groups = Array::new()
  let mut index = 0
  while index < items.length() {
    let group = Array::new()
    let mut i = 0
    while i < group_size && index < items.length() {
      group.push(items[index])
      index = index + 1
      i = i + 1
    }
    groups.push(group)
  }
  groups
}

///|
fn name_tree_of_nt(
  isnum : Bool,
  isroot : Bool,
  pdf : @pdf.Pdf,
  node : Nt,
) -> @pdf.PdfObject {
  match node {
    Nt::Leaf(llimit, items, rlimit) => {
      let array_items = Array::new()
      for pair in items {
        let key_obj = if isnum {
          @pdf.PdfObject::Integer(parse_int(pair.0))
        } else {
          @pdf.PdfObject::String(pair.0)
        }
        array_items.push(key_obj)
        array_items.push(pair.1)
      }
      let entry_key = if isnum { "/Nums" } else { "/Names" }
      let entry = (entry_key, @pdf.PdfObject::Array(array_items))
      let limits = if isnum {
        @pdf.PdfObject::Array([
          @pdf.PdfObject::Integer(parse_int(llimit)),
          @pdf.PdfObject::Integer(parse_int(rlimit)),
        ])
      } else {
        @pdf.PdfObject::Array([
          @pdf.PdfObject::String(llimit),
          @pdf.PdfObject::String(rlimit),
        ])
      }
      let dict_entries = Array::new()
      dict_entries.push(entry)
      if !isroot {
        dict_entries.push(("/Limits", limits))
      }
      @pdf.PdfObject::Dictionary(dict_entries)
    }
    Nt::Branch(llimit, kids, rlimit) => {
      let kid_refs = Array::new()
      for child in kids {
        let child_obj = name_tree_of_nt(isnum, false, pdf, child)
        match child_obj {
          @pdf.PdfObject::Dictionary(_)
          | @pdf.PdfObject::Stream(_)
          | @pdf.PdfObject::Array(_) => {
            let objnum = @pdf.addobj(pdf, child_obj)
            kid_refs.push(@pdf.PdfObject::Indirect(objnum))
          }
          _ => kid_refs.push(child_obj)
        }
      }
      let limits = if isnum {
        @pdf.PdfObject::Array([
          @pdf.PdfObject::Integer(parse_int(llimit)),
          @pdf.PdfObject::Integer(parse_int(rlimit)),
        ])
      } else {
        @pdf.PdfObject::Array([
          @pdf.PdfObject::String(llimit),
          @pdf.PdfObject::String(rlimit),
        ])
      }
      @pdf.PdfObject::Dictionary([
        ("/Kids", @pdf.PdfObject::Array(kid_refs)),
        ("/Limits", limits),
      ])
    }
  }
}
