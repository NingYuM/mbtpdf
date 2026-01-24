///|
test "read_ocg returns none without ocproperties" {
  let pdf = @pdfpage.minimum_valid_pdf()
  match OcgProperties::read(pdf) {
    None => ()
    _ => fail("expected no ocproperties")
  }
}

///|
test "read_ocg parses ocproperties" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let ocg_obj : @pdf.PdfObject = Dictionary([
    ("/Name", String("Layer 1")),
    ("/Intent", Array([Name("/View"), Integer(0)])),
  ])
  let ocg_ref = @pdf.addobj(pdf, ocg_obj)
  let default_config : @pdf.PdfObject = Dictionary([
    ("/Name", String("Default")),
    ("/Creator", String("tester")),
    ("/BaseState", Name("/OFF")),
    ("/ON", Array([Indirect(ocg_ref), Integer(99)])),
    ("/OFF", Array([Indirect(ocg_ref)])),
    ("/Intent", Array([Name("/View"), Integer(0)])),
    ("/AS", Array([Dictionary([])])),
    ("/ListMode", Name("/VisiblePages")),
    ("/Locked", Array([Indirect(ocg_ref), Integer(0)])),
  ])
  let alt_config : @pdf.PdfObject = Dictionary([
    ("/BaseState", Name("/Unchanged")),
    ("/Intent", Name("/Design")),
  ])
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", Array([Indirect(ocg_ref)])),
    ("/D", default_config),
    ("/Configs", Array([alt_config])),
  ])
  let root = @pdf.lookup_obj(pdf, pdf.root)
  let updated_root = root.add_entry("/OCProperties", ocprops)
  @pdf.addobj_given_num(pdf, (pdf.root, updated_root))
  let props = match OcgProperties::read(pdf) {
    Some(result) => result
    None => fail("expected ocproperties")
  }
  assert_eq(props.ocgs.length(), 1)
  let (num, ocg) = props.ocgs[0]
  assert_eq(num, ocg_ref)
  assert_eq(ocg.ocg_name, "Layer 1")
  assert_eq(ocg.ocg_intent.length(), 1)
  assert_eq(ocg.ocg_intent[0], "/View")
  assert_eq(props.ocg_default_config.ocgconfig_name, Some("Default"))
  assert_eq(props.ocg_default_config.ocgconfig_creator, Some("tester"))
  match props.ocg_default_config.ocgconfig_basestate {
    OcgState::Off => ()
    _ => fail("expected Off basestate")
  }
  match props.ocg_default_config.ocgconfig_on {
    Some(values) => {
      assert_eq(values.length(), 2)
      assert_eq(values[0], ocg_ref)
      assert_eq(values[1], 0)
    }
    None => fail("expected ON list")
  }
  match props.ocg_default_config.ocgconfig_off {
    Some(values) => {
      assert_eq(values.length(), 1)
      assert_eq(values[0], ocg_ref)
    }
    None => fail("expected OFF list")
  }
  assert_eq(props.ocg_default_config.ocgconfig_intent.length(), 2)
  assert_eq(props.ocg_default_config.ocgconfig_intent[0], "/View")
  assert_eq(props.ocg_default_config.ocgconfig_intent[1], "")
  match props.ocg_default_config.ocgconfig_usage_application_dictionaries {
    Some(values) => assert_eq(values.length(), 1)
    None => fail("expected AS list")
  }
  match props.ocg_default_config.ocgconfig_listmode {
    OcgListMode::VisiblePages => ()
    _ => fail("expected VisiblePages list mode")
  }
  assert_eq(props.ocg_default_config.ocgconfig_locked.length(), 2)
  assert_eq(props.ocg_default_config.ocgconfig_locked[0], 0)
  assert_eq(props.ocg_default_config.ocgconfig_locked[1], 0)
  assert_eq(props.ocg_configs.length(), 1)
  match props.ocg_configs[0].ocgconfig_basestate {
    OcgState::Unchanged => ()
    _ => fail("expected Unchanged basestate")
  }
  assert_eq(props.ocg_configs[0].ocgconfig_intent.length(), 1)
  assert_eq(props.ocg_configs[0].ocgconfig_intent[0], "/Design")
}

///|
test "read_ocg raises without root" {
  let pdf = @pdf.Pdf::empty()
  let res : Result[@pdfocg.OcgProperties?, Error] = try? OcgProperties::read(
    pdf,
  )
  match res {
    Err(_) => ()
    _ => fail("expected missing /Root error")
  }
}

///|
test "read_ocg raises when ocg is missing name" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let ocg_obj : @pdf.PdfObject = Dictionary([])
  let ocg_ref = @pdf.addobj(pdf, ocg_obj)
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", Array([Indirect(ocg_ref)])),
    ("/D", Dictionary([])),
  ])
  let root = @pdf.lookup_obj(pdf, pdf.root)
  let updated_root = root.add_entry("/OCProperties", ocprops)
  @pdf.addobj_given_num(pdf, (pdf.root, updated_root))
  let res : Result[@pdfocg.OcgProperties?, Error] = try? OcgProperties::read(
    pdf,
  )
  match res {
    Err(_) => ()
    _ => fail("expected missing /Name error")
  }
}

///|
test "read_ocg uses config defaults" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let ocg_obj : @pdf.PdfObject = Dictionary([
    ("/Name", String("Layer 2")),
    ("/Intent", Name("/Design")),
  ])
  let ocg_ref = @pdf.addobj(pdf, ocg_obj)
  let default_config : @pdf.PdfObject = Dictionary([])
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", Array([Indirect(ocg_ref)])),
    ("/D", default_config),
  ])
  let root = @pdf.lookup_obj(pdf, pdf.root)
  let updated_root = root.add_entry("/OCProperties", ocprops)
  @pdf.addobj_given_num(pdf, (pdf.root, updated_root))
  let props = match OcgProperties::read(pdf) {
    Some(result) => result
    None => fail("expected ocproperties")
  }
  assert_eq(props.ocg_default_config.ocgconfig_intent.length(), 1)
  assert_eq(props.ocg_default_config.ocgconfig_intent[0], "/View")
  match props.ocg_default_config.ocgconfig_listmode {
    OcgListMode::AllPages => ()
    _ => fail("expected AllPages list mode")
  }
  assert_true(props.ocg_default_config.ocgconfig_on == None)
  assert_true(props.ocg_default_config.ocgconfig_off == None)
  assert_eq(props.ocg_default_config.ocgconfig_locked.length(), 0)
}

///|
test "read_ocg parses ocg intent name" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let ocg_obj : @pdf.PdfObject = Dictionary([
    ("/Name", String("Layer 3")),
    ("/Intent", Name("/Design")),
  ])
  let ocg_ref = @pdf.addobj(pdf, ocg_obj)
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", Array([Indirect(ocg_ref)])),
    ("/D", Dictionary([])),
  ])
  let root = @pdf.lookup_obj(pdf, pdf.root)
  let updated_root = root.add_entry("/OCProperties", ocprops)
  @pdf.addobj_given_num(pdf, (pdf.root, updated_root))
  let props = match OcgProperties::read(pdf) {
    Some(result) => result
    None => fail("expected ocproperties")
  }
  assert_eq(props.ocgs.length(), 1)
  let (_, ocg) = props.ocgs[0]
  assert_eq(ocg.ocg_intent.length(), 1)
  assert_eq(ocg.ocg_intent[0], "/Design")
}

///|
test "print_document_ocg handles missing ocg" {
  let pdf = @pdfpage.minimum_valid_pdf()
  print_document_ocg(pdf)
}

///|
test "read_ocg handles direct ocgs and usage defaults" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let ocg_obj : @pdf.PdfObject = Dictionary([
    ("/Name", String("Layer 4")),
    ("/Usage", Dictionary([])),
  ])
  let default_config : @pdf.PdfObject = Dictionary([
    ("/BaseState", Name("/ON")),
    ("/OFF", Array([Integer(12), Name("/Bad")])),
    ("/Locked", Array([Integer(1)])),
  ])
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", Array([ocg_obj])),
    ("/D", default_config),
  ])
  let root = @pdf.lookup_obj(pdf, pdf.root)
  let updated_root = root.add_entry("/OCProperties", ocprops)
  @pdf.addobj_given_num(pdf, (pdf.root, updated_root))
  let props = match OcgProperties::read(pdf) {
    Some(result) => result
    None => fail("expected ocproperties")
  }
  assert_eq(props.ocgs.length(), 1)
  let (num, ocg) = props.ocgs[0]
  assert_eq(num, 0)
  assert_eq(ocg.ocg_name, "Layer 4")
  assert_eq(ocg.ocg_intent.length(), 1)
  assert_eq(ocg.ocg_intent[0], "/View")
  assert_true(ocg.ocg_usage is None)
  match props.ocg_default_config.ocgconfig_basestate {
    OcgState::On => ()
    _ => fail("expected On basestate")
  }
  match props.ocg_default_config.ocgconfig_off {
    Some(values) => {
      assert_eq(values.length(), 2)
      assert_eq(values[0], 0)
      assert_eq(values[1], 0)
    }
    None => fail("expected OFF list")
  }
}

///|
test "read_ocg raises without default config" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let ocprops : @pdf.PdfObject = Dictionary([("/OCGs", Name("/NotArray"))])
  let root = @pdf.lookup_obj(pdf, pdf.root)
  let updated_root = root.add_entry("/OCProperties", ocprops)
  @pdf.addobj_given_num(pdf, (pdf.root, updated_root))
  let res : Result[@pdfocg.OcgProperties?, Error] = try? OcgProperties::read(
    pdf,
  )
  assert_true(res is Err(_))
}
