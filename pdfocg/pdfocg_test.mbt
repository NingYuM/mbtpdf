///|
test "read_ocg returns none without ocproperties" {
  let pdf = @pdfpage.minimum_valid_pdf()
  match read_ocg(pdf) {
    None => ()
    _ => fail("expected no ocproperties")
  }
}

///|
test "read_ocg parses ocproperties" {
  let pdf = @pdfpage.minimum_valid_pdf()
  let ocg_obj = @pdf.PdfObject::Dictionary([
    ("/Name", @pdf.PdfObject::String("Layer 1")),
    (
      "/Intent",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/View"),
        @pdf.PdfObject::Integer(0),
      ]),
    ),
  ])
  let ocg_ref = @pdf.addobj(pdf, ocg_obj)
  let default_config = @pdf.PdfObject::Dictionary([
    ("/Name", @pdf.PdfObject::String("Default")),
    ("/Creator", @pdf.PdfObject::String("tester")),
    ("/BaseState", @pdf.PdfObject::Name("/OFF")),
    (
      "/ON",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Indirect(ocg_ref),
        @pdf.PdfObject::Integer(99),
      ]),
    ),
    ("/OFF", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(ocg_ref)])),
    (
      "/Intent",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/View"),
        @pdf.PdfObject::Integer(0),
      ]),
    ),
    ("/AS", @pdf.PdfObject::Array([@pdf.PdfObject::Dictionary([])])),
    ("/ListMode", @pdf.PdfObject::Name("/VisiblePages")),
    (
      "/Locked",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Indirect(ocg_ref),
        @pdf.PdfObject::Integer(0),
      ]),
    ),
  ])
  let alt_config = @pdf.PdfObject::Dictionary([
    ("/BaseState", @pdf.PdfObject::Name("/Unchanged")),
    ("/Intent", @pdf.PdfObject::Name("/Design")),
  ])
  let ocprops = @pdf.PdfObject::Dictionary([
    ("/OCGs", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(ocg_ref)])),
    ("/D", default_config),
    ("/Configs", @pdf.PdfObject::Array([alt_config])),
  ])
  let root = @pdf.lookup_obj(pdf, pdf.root)
  let updated_root = @pdf.add_dict_entry(root, "/OCProperties", ocprops)
  @pdf.addobj_given_num(pdf, (pdf.root, updated_root))
  let props = match read_ocg(pdf) {
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
