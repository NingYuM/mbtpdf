///|
fn with_root(pdf : @pdf.Pdf, root_num : Int) -> @pdf.Pdf {
  @pdf.Pdf::{
    major: pdf.major,
    minor: pdf.minor,
    root: root_num,
    objects: pdf.objects,
    trailerdict: @pdf.PdfObject::Dictionary([
      ("/Root", @pdf.PdfObject::Indirect(root_num)),
    ]),
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
}

///|
fn build_ocg_pdf() -> @pdf.Pdf {
  let pdf = @pdf.empty()
  let ocg = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/OCG")),
    ("/Name", @pdf.PdfObject::String("Layer1")),
    (
      "/Intent",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/View"),
        @pdf.PdfObject::Name("/Design"),
      ]),
    ),
    ("/Usage", @pdf.PdfObject::Dictionary([])),
  ])
  let ocg_num = @pdf.addobj(pdf, ocg)
  let config = @pdf.PdfObject::Dictionary([
    ("/Name", @pdf.PdfObject::String("Default")),
    ("/Creator", @pdf.PdfObject::String("mbtpdf")),
    ("/BaseState", @pdf.PdfObject::Name("/OFF")),
    ("/ON", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(ocg_num)])),
    ("/OFF", @pdf.PdfObject::Array([])),
    (
      "/Intent",
      @pdf.PdfObject::Array([
        @pdf.PdfObject::Name("/View"),
        @pdf.PdfObject::Name("/Design"),
      ]),
    ),
    ("/AS", @pdf.PdfObject::Array([@pdf.PdfObject::Dictionary([])])),
    ("/ListMode", @pdf.PdfObject::Name("/VisiblePages")),
    ("/Locked", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(ocg_num)])),
  ])
  let config_num = @pdf.addobj(pdf, config)
  let ocprops = @pdf.PdfObject::Dictionary([
    ("/OCGs", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(ocg_num)])),
    ("/D", @pdf.PdfObject::Indirect(config_num)),
    ("/Configs", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(config_num)])),
  ])
  let ocprops_num = @pdf.addobj(pdf, ocprops)
  let catalog = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Catalog")),
    ("/OCProperties", @pdf.PdfObject::Indirect(ocprops_num)),
  ])
  let catalog_num = @pdf.addobj(pdf, catalog)
  with_root(pdf, catalog_num)
}

///|
test "read_ocg parses properties" {
  let pdf = build_ocg_pdf()
  match read_ocg(pdf) {
    None => fail("expected ocg properties")
    Some(props) => {
      assert_eq(props.ocgs.length(), 1)
      let ocg = props.ocgs[0].1
      assert_eq(ocg.ocg_name, "Layer1")
      assert_true(ocg.ocg_intent.contains("/View"))
      assert_true(props.ocg_configs.length() == 1)
      let config = props.ocg_configs[0]
      match config.ocgconfig_basestate {
        OcgState::Off => ()
        _ => fail("expected basestate off")
      }
      match config.ocgconfig_listmode {
        OcgListMode::VisiblePages => ()
        _ => fail("expected visible pages")
      }
      assert_eq(config.ocgconfig_locked.length(), 1)
    }
  }
}

///|
test "read_ocg returns none when missing" {
  let pdf = @pdf.empty()
  let catalog = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name("/Catalog")),
  ])
  let catalog_num = @pdf.addobj(pdf, catalog)
  let pdf_with_root = with_root(pdf, catalog_num)
  match read_ocg(pdf_with_root) {
    None => ()
    _ => fail("expected no ocg")
  }
}
