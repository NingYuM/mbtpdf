///|
/// Hook for resolving page count without direct dependency on pdfpage.
pub let endpage : Ref[(@pdf.Pdf) -> Int] = { val: _ => 0 }

///|
fn ilist(start : Int, finish : Int) -> Array[Int] {
  if finish < start {
    return []
  }
  let out = Array::new(capacity=finish - start + 1)
  let mut i = start
  while i <= finish {
    out.push(i)
    i = i + 1
  }
  out
}

///|
fn setminus(full : Array[Int], remove : Array[Int]) -> Array[Int] {
  let remove_set = Map::new(capacity=remove.length())
  for v in remove {
    remove_set.set(v, ())
  }
  let out = Array::new()
  for v in full {
    if remove_set.get(v) == None {
      out.push(v)
    }
  }
  out
}

///|
fn set_of_ints(values : Array[Int]) -> Map[Int, Unit] {
  let out = Map::new(capacity=values.length())
  for v in values {
    out.set(v, ())
  }
  out
}

///|
fn dedup_ints(values : Array[Int]) -> Array[Int] {
  let set = set_of_ints(values)
  let out = Array::new()
  for key, _ in set {
    out.push(key)
  }
  out
}

///|
fn dedup_pairs(
  values : Array[(Int, @pdf.PdfObject)],
) -> Array[(Int, @pdf.PdfObject)] {
  let set = Map::new(capacity=values.length())
  for pair in values {
    set.set(pair.0, pair.1)
  }
  let out = Array::new()
  for key, value in set {
    out.push((key, value))
  }
  out
}

///|
/// Trim the structure tree to match a subset of pages.
pub fn trim_structure_tree(pdf : @pdf.Pdf, range : Array[Int]) -> Unit raise {
  let objnums = @pdf.page_reference_numbers(pdf)
  let total_pages = (endpage.val)(pdf)
  let pages_to_remove = setminus(ilist(1, total_pages), range)
  let page_objnums_to_remove = Array::new(capacity=pages_to_remove.length())
  for pnum in pages_to_remove {
    if pnum >= 1 && pnum <= objnums.length() {
      page_objnums_to_remove.push(objnums[pnum - 1])
    }
  }
  if page_objnums_to_remove.length() == 0 {
    return
  }
  let remove_set = set_of_ints(page_objnums_to_remove)
  let del : Ref[Array[Int]] = { val: [] }
  let replaceobjs : Ref[Array[(Int, @pdf.PdfObject)]] = { val: [] }
  @pdf.objiter(
    (n, o) => match @pdf.direct(pdf, o) {
      @pdf.PdfObject::Dictionary(d) =>
        match @pdf.lookup_immediate("/Pg", @pdf.PdfObject::Dictionary(d)) {
          Some(@pdf.PdfObject::Indirect(i)) =>
            if remove_set.get(i) != None {
              del.val.push(n)
            }
          _ => ()
        }
      _ => ()
    },
    pdf,
  )
  fn survives(obj : @pdf.PdfObject) -> Bool {
    match obj {
      @pdf.PdfObject::Indirect(i) => {
        let exists = match @pdf.lookup_obj(pdf, i) {
          @pdf.PdfObject::Null => false
          _ => true
        }
        if !exists {
          return false
        }
        match @pdf.indirect_number(pdf, "/Pg", @pdf.PdfObject::Indirect(i)) {
          Some(p) if remove_set.get(p) != None => false
          _ =>
            match
              @pdf.indirect_number(pdf, "/Obj", @pdf.PdfObject::Indirect(i)) {
              Some(p) if remove_set.get(p) != None => false
              _ => true
            }
        }
      }
      _ => true
    }
  }

  fn process(objs : Array[@pdf.PdfObject]) -> Array[@pdf.PdfObject]? {
    let out = Array::new()
    let mut changed = false
    for obj in objs {
      if survives(obj) {
        out.push(obj)
      } else {
        changed = true
      }
    }
    if !changed {
      None
    } else {
      Some(out)
    }
  }

  fn process_indirect(
    d : Array[(String, @pdf.PdfObject)],
    objs : Array[@pdf.PdfObject],
    n : Int,
  ) -> Unit raise {
    match process(objs) {
      None => ()
      Some(newlist) =>
        if newlist.length() == 0 {
          del.val.push(n)
        } else {
          let replacement = if newlist.length() == 1 {
            newlist[0]
          } else {
            @pdf.PdfObject::Array(newlist)
          }
          let updated = @pdf.replace_dict_entry(
            @pdf.PdfObject::Dictionary(d),
            "/K",
            replacement,
          )
          replaceobjs.val.push((n, updated))
        }
    }
  }

  while del.val.length() > 0 || replaceobjs.val.length() > 0 {
    for objnum in dedup_ints(del.val) {
      @pdf.removeobj(pdf, objnum)
    }
    del.val = []
    for pair in dedup_pairs(replaceobjs.val) {
      @pdf.addobj_given_num(pdf, pair)
    }
    replaceobjs.val = []
    @pdf.objiter(
      (n, o) => match @pdf.direct(pdf, o) {
        @pdf.PdfObject::Dictionary(d) =>
          match @pdf.lookup_immediate("/K", @pdf.PdfObject::Dictionary(d)) {
            Some(@pdf.PdfObject::Integer(_)) => ()
            Some(@pdf.PdfObject::Indirect(i)) =>
              process_indirect(d, [@pdf.PdfObject::Indirect(i)], n)
            Some(@pdf.PdfObject::Array(objs)) => process_indirect(d, objs, n)
            _ => ()
          }
        _ => ()
      },
      pdf,
    )
  }
}
