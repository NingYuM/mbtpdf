///|
fn build_two_page_pdf() -> @pdf.Pdf raise {
  let pages = [
    @pdfpage.blankpage(@pdfpaper.a4),
    @pdfpage.blankpage(@pdfpaper.a4),
  ]
  let (pdf, pageroot) = @pdfpage.add_pagetree(pages, @pdf.empty())
  @pdfpage.add_root(pageroot, [], pdf)
}

///|
fn build_page_pdf(count : Int) -> @pdf.Pdf raise {
  let pages = Array::new()
  let mut i = 0
  while i < count {
    pages.push(@pdfpage.blankpage(@pdfpaper.a4))
    i = i + 1
  }
  let (pdf, pageroot) = @pdfpage.add_pagetree(pages, @pdf.empty())
  @pdfpage.add_root(pageroot, [], pdf)
}

///|
fn install_struct_root(pdf : @pdf.Pdf, root : @pdf.PdfObject) -> Int raise {
  let root_num = @pdf.addobj(pdf, root)
  let catalog_num = match @pdf.lookup_immediate("/Root", pdf.trailerdict) {
    Some(@pdf.PdfObject::Indirect(i)) => i
    _ => raise @pdf.PdfError::Msg("missing root")
  }
  let catalog = @pdf.lookup_obj(pdf, catalog_num)
  let updated = @pdf.add_dict_entry(
    catalog,
    "/StructTreeRoot",
    @pdf.PdfObject::Indirect(root_num),
  )
  @pdf.addobj_given_num(pdf, (catalog_num, updated))
  root_num
}

///|
fn add_struct_tree(pdf : @pdf.Pdf) -> (Int, Int) raise {
  let page_refs = @pdf.page_reference_numbers(pdf)
  let struct1 = @pdf.PdfObject::Dictionary([
    ("/Pg", @pdf.PdfObject::Indirect(page_refs[0])),
  ])
  let struct2 = @pdf.PdfObject::Dictionary([
    ("/Pg", @pdf.PdfObject::Indirect(page_refs[1])),
  ])
  let struct1_num = @pdf.addobj(pdf, struct1)
  let struct2_num = @pdf.addobj(pdf, struct2)
  let root = @pdf.PdfObject::Dictionary([
    (
      "/K",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Indirect(struct1_num),
        @pdf.PdfObject::Indirect(struct2_num),
      ]),
    ),
  ])
  let root_num = @pdf.addobj(pdf, root)
  let catalog_num = match @pdf.lookup_immediate("/Root", pdf.trailerdict) {
    Some(@pdf.PdfObject::Indirect(i)) => i
    _ => raise @pdf.PdfError::Msg("missing root")
  }
  let catalog = @pdf.lookup_obj(pdf, catalog_num)
  let updated = @pdf.add_dict_entry(
    catalog,
    "/StructTreeRoot",
    @pdf.PdfObject::Indirect(root_num),
  )
  @pdf.addobj_given_num(pdf, (catalog_num, updated))
  (root_num, struct2_num)
}

///|
test "trim_structure_tree removes entries" {
  let pdf = build_two_page_pdf()
  let (root_num, removed_num) = add_struct_tree(pdf)
  let previous = endpage.val
  endpage.val = p => @pdfpage.pages_of_pagetree_quick(p) catch { _ => 0 }
  trim_structure_tree(pdf, [1])
  endpage.val = previous
  assert_true(!@pdf.objnumbers(pdf).contains(removed_num))
  let root = @pdf.lookup_obj(pdf, root_num)
  match @pdf.lookup_immediate("/K", root) {
    Some(@pdf.PdfObject::Array(items)) => assert_eq(items.length(), 1)
    Some(@pdf.PdfObject::Indirect(_)) => ()
    _ => fail("expected updated /K")
  }
}

///|
test "trim_structure_tree updates nested k arrays" {
  let pdf = build_page_pdf(3)
  let page_refs = @pdf.page_reference_numbers(pdf)
  let keep = @pdf.addobj(
    pdf,
    @pdf.PdfObject::Dictionary([("/Pg", @pdf.PdfObject::Indirect(page_refs[0]))]),
  )
  let remove_pg = @pdf.addobj(
    pdf,
    @pdf.PdfObject::Dictionary([("/Pg", @pdf.PdfObject::Indirect(page_refs[1]))]),
  )
  let remove_obj = @pdf.addobj(
    pdf,
    @pdf.PdfObject::Dictionary([
      ("/Obj", @pdf.PdfObject::Indirect(page_refs[2])),
    ]),
  )
  let parent_keep = @pdf.addobj(
    pdf,
    @pdf.PdfObject::Dictionary([
      (
        "/K",
        @pdf.PdfObject::Array([
          @pdf.PdfObject::Indirect(keep),
          @pdf.PdfObject::Indirect(remove_pg),
          @pdf.PdfObject::Indirect(999),
          @pdf.PdfObject::Integer(7),
          @pdf.PdfObject::Indirect(remove_obj),
        ]),
      ),
    ]),
  )
  let parent_remove = @pdf.addobj(
    pdf,
    @pdf.PdfObject::Dictionary([
      ("/K", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(remove_pg)])),
    ]),
  )
  let parent_int = @pdf.addobj(
    pdf,
    @pdf.PdfObject::Dictionary([("/K", @pdf.PdfObject::Integer(1))]),
  )
  let root_num = install_struct_root(
    pdf,
    @pdf.PdfObject::Dictionary([
      (
        "/K",
        @pdf.PdfObject::Array([
          @pdf.PdfObject::Indirect(parent_keep),
          @pdf.PdfObject::Indirect(parent_remove),
          @pdf.PdfObject::Indirect(parent_int),
        ]),
      ),
    ]),
  )
  ignore(
    @pdf.addobj(
      pdf,
      @pdf.PdfObject::Stream(
        Ref::new(
          (
            @pdf.PdfObject::Dictionary([("/Length", @pdf.PdfObject::Integer(0))]),
            @pdf.Stream::Got(([] : Array[Byte])),
          ),
        ),
      ),
    ),
  )
  let previous = endpage.val
  endpage.val = p => @pdfpage.pages_of_pagetree_quick(p) catch { _ => 0 }
  trim_structure_tree(pdf, [1])
  endpage.val = previous
  assert_true(!@pdf.objnumbers(pdf).contains(parent_remove))
  let root = @pdf.lookup_obj(pdf, root_num)
  match @pdf.lookup_immediate("/K", root) {
    Some(@pdf.PdfObject::Array(items)) => assert_eq(items.length(), 2)
    _ => fail("expected root /K array")
  }
  let parent = @pdf.lookup_obj(pdf, parent_keep)
  match @pdf.lookup_immediate("/K", parent) {
    Some(@pdf.PdfObject::Array(items)) => assert_eq(items.length(), 2)
    _ => fail("expected updated parent /K array")
  }
}

///|
test "renumber_parent_trees with empty parents" {
  let pdf1 = build_two_page_pdf()
  let pdf2 = build_two_page_pdf()
  inspect(try? renumber_parent_trees([pdf1, pdf2]), content="Ok(())")
}

///|
test "renumber_parent_trees handles single pdf" {
  let pdf = build_two_page_pdf()
  renumber_parent_trees([pdf])
}

///|
test "renumber_parent_trees remaps struct parents" {
  let pdf1 = build_page_pdf(1)
  let pdf2 = build_page_pdf(1)
  let obj1 = @pdf.addobj(
    pdf1,
    @pdf.PdfObject::Dictionary([("/StructParent", @pdf.PdfObject::Integer(0))]),
  )
  let obj2 = @pdf.addobj(
    pdf2,
    @pdf.PdfObject::Dictionary([("/StructParent", @pdf.PdfObject::Integer(0))]),
  )
  let obj3 = @pdf.addobj(
    pdf2,
    @pdf.PdfObject::Dictionary([
      ("/StructParents", @pdf.PdfObject::Array([@pdf.PdfObject::Integer(0)])),
    ]),
  )
  ignore(obj3)
  let stream = @pdf.PdfObject::Stream(
    Ref::new(
      (
        @pdf.PdfObject::Dictionary([
          ("/Length", @pdf.PdfObject::Integer(0)),
          ("/StructParent", @pdf.PdfObject::Integer(0)),
        ]),
        @pdf.Stream::Got(([] : Array[Byte])),
      ),
    ),
  )
  let stream_num = @pdf.addobj(pdf2, stream)
  let tree1 = @pdftree.build_name_tree(true, pdf1, [("0", @pdf.PdfObject::Null)])
  let tree2 = @pdftree.build_name_tree(true, pdf2, [("0", @pdf.PdfObject::Null)])
  let tree1_num = @pdf.addobj(pdf1, tree1)
  let tree2_num = @pdf.addobj(pdf2, tree2)
  ignore(
    install_struct_root(
      pdf1,
      @pdf.PdfObject::Dictionary([
        ("/ParentTree", @pdf.PdfObject::Indirect(tree1_num)),
      ]),
    ),
  )
  ignore(
    install_struct_root(
      pdf2,
      @pdf.PdfObject::Dictionary([
        ("/ParentTree", @pdf.PdfObject::Indirect(tree2_num)),
      ]),
    ),
  )
  renumber_parent_trees([pdf1, pdf2])
  match @pdf.lookup_direct(pdf1, "/StructParent", @pdf.lookup_obj(pdf1, obj1)) {
    Some(@pdf.PdfObject::Integer(0)) => ()
    _ => fail("expected pdf1 StructParent unchanged")
  }
  match @pdf.lookup_direct(pdf2, "/StructParent", @pdf.lookup_obj(pdf2, obj2)) {
    Some(@pdf.PdfObject::Integer(1)) => ()
    _ => fail("expected pdf2 StructParent remapped")
  }
  match
    @pdf.lookup_direct(pdf2, "/StructParent", @pdf.lookup_obj(pdf2, stream_num)) {
    Some(@pdf.PdfObject::Integer(1)) => ()
    _ => fail("expected stream StructParent remapped")
  }
  match
    @pdf.lookup_chain(pdf2, pdf2.trailerdict, [
      "/Root", "/StructTreeRoot", "/ParentTree",
    ]) {
    Some(tree) =>
      match @pdftree.read_number_tree(pdf2, tree) {
        [(key, _)] => assert_eq(key, "1")
        _ => fail("expected renumbered parent tree")
      }
    None => fail("expected parent tree")
  }
}

///|
test "merge_structure_trees returns none" {
  let pdf = @pdf.empty()
  let input = build_two_page_pdf()
  match merge_structure_trees(pdf, [input]) {
    None => ()
    _ => fail("expected none")
  }
}

///|
test "merge_structure_trees returns single root" {
  let pdf_out = @pdf.empty()
  let pdf = build_two_page_pdf()
  let root_num = install_struct_root(pdf, @pdf.PdfObject::Dictionary([]))
  match merge_structure_trees(pdf_out, [pdf]) {
    Some(id) => assert_eq(id, root_num)
    _ => fail("expected root objnum")
  }
}

///|
test "merge_structure_trees merges roots" {
  let pdf_out = @pdf.empty()
  let pdf1 = build_page_pdf(1)
  let pdf2 = build_page_pdf(1)
  let page_refs1 = @pdf.page_reference_numbers(pdf1)
  let page_refs2 = @pdf.page_reference_numbers(pdf2)
  let kid1 = @pdf.addobj(
    pdf1,
    @pdf.PdfObject::Dictionary([
      ("/Pg", @pdf.PdfObject::Indirect(page_refs1[0])),
    ]),
  )
  let idtree1 = @pdftree.build_name_tree(false, pdf1, [
    ("A", @pdf.PdfObject::Null),
  ])
  let parenttree1 = @pdftree.build_name_tree(true, pdf1, [
    ("0", @pdf.PdfObject::Null),
  ])
  ignore(
    install_struct_root(
      pdf1,
      @pdf.PdfObject::Dictionary([
        ("/K", @pdf.PdfObject::Indirect(kid1)),
        ("/IDTree", idtree1),
        ("/ParentTree", parenttree1),
        (
          "/RoleMap",
          @pdf.PdfObject::Dictionary([("/Sect", @pdf.PdfObject::Name("/Div"))]),
        ),
        (
          "/Namespaces",
          @pdf.PdfObject::Array([
            @pdf.PdfObject::Dictionary([("/NS", @pdf.PdfObject::String("ns1"))]),
          ]),
        ),
        ("/PronunciationLexicon", @pdf.PdfObject::Array([])),
      ]),
    ),
  )
  let kid2 = @pdf.PdfObject::Dictionary([
    ("/Pg", @pdf.PdfObject::Indirect(page_refs2[0])),
  ])
  let idtree2 = @pdftree.build_name_tree(false, pdf2, [
    ("B", @pdf.PdfObject::Null),
  ])
  let parenttree2 = @pdftree.build_name_tree(true, pdf2, [
    ("0", @pdf.PdfObject::Null),
  ])
  ignore(
    install_struct_root(
      pdf2,
      @pdf.PdfObject::Dictionary([
        ("/K", @pdf.PdfObject::Array([kid2, @pdf.PdfObject::Integer(3)])),
        ("/IDTree", idtree2),
        ("/ParentTree", parenttree2),
        ("/RoleMap", @pdf.PdfObject::Name("/NotADict")),
        (
          "/ClassMap",
          @pdf.PdfObject::Dictionary([("/Class", @pdf.PdfObject::Name("/Span"))]),
        ),
        ("/Namespaces", @pdf.PdfObject::Dictionary([])),
        ("/AF", @pdf.PdfObject::Array([@pdf.PdfObject::Name("/File")])),
      ]),
    ),
  )
  let merged = merge_structure_trees(
    pdf_out,
    [pdf1, pdf2],
    add_toplevel_document=true,
  )
  match merged {
    Some(root_num) =>
      match @pdf.lookup_obj(pdf_out, root_num) {
        @pdf.PdfObject::Dictionary(_) as dict =>
          match @pdf.lookup_direct(pdf_out, "/Type", dict) {
            Some(@pdf.PdfObject::Name("/StructTreeRoot")) => ()
            _ => fail("expected StructTreeRoot type")
          }
        _ => fail("expected merged root dict")
      }
    _ => fail("expected merged struct tree")
  }
  let merged_no_top = merge_structure_trees(pdf_out, [pdf1, pdf2])
  assert_true(merged_no_top is Some(_))
}
