///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
test "write/read CalGray" {
  let pdf = @pdf.empty()
  let space = @pdfspace.ColourSpace::CalGray(
    (1.0, 1.0, 1.0),
    (0.0, 0.0, 0.0),
    2.2,
  )
  let obj = @pdfspace.write_colourspace(pdf, space)
  let resources = @pdf.PdfObject::Dictionary([])
  let read = @pdfspace.read_colourspace(pdf, resources, obj)
  match read {
    @pdfspace.ColourSpace::CalGray(white, black, gamma) => {
      assert_close(white.0, 1.0)
      assert_close(black.0, 0.0)
      assert_close(gamma, 2.2)
    }
    _ => fail("expected CalGray")
  }
}

///|
test "write/read Indexed" {
  let pdf = @pdf.empty()
  let table : Map[Int, Array[Int]] = Map::new()
  table.set(0, [0, 0, 0])
  table.set(1, [255, 255, 255])
  let space = @pdfspace.ColourSpace::Indexed(
    @pdfspace.ColourSpace::DeviceRGB,
    table,
  )
  let obj = @pdfspace.write_colourspace(pdf, space)
  let resources = @pdf.PdfObject::Dictionary([])
  let read = @pdfspace.read_colourspace(pdf, resources, obj)
  match read {
    @pdfspace.ColourSpace::Indexed(base, read_table) => {
      match base {
        @pdfspace.ColourSpace::DeviceRGB => ()
        _ => fail("expected DeviceRGB base")
      }
      match read_table.get(1) {
        Some(values) => {
          assert_eq(values.length(), 3)
          assert_eq(values[0], 255)
        }
        None => fail("missing index 1")
      }
    }
    _ => fail("expected Indexed")
  }
}

///|
test "write/read ICCBased" {
  let pdf = @pdf.empty()
  let dict = @pdf.PdfObject::Dictionary([])
  let data = @pdfio.bytes_of_string("ICC")
  let stream_obj = @pdf.PdfObject::Stream(
    Ref::new((dict, @pdf.Stream::Got(data))),
  )
  let icc = @pdfspace.ICCBased::{
    icc_n: 3,
    icc_alternate: @pdfspace.ColourSpace::DeviceRGB,
    icc_range: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
    icc_metadata: None,
    icc_stream: stream_obj,
  }
  let space = @pdfspace.ColourSpace::ICCBased(icc)
  let obj = @pdfspace.write_colourspace(pdf, space)
  let resources = @pdf.PdfObject::Dictionary([])
  let read = @pdfspace.read_colourspace(pdf, resources, obj)
  match read {
    @pdfspace.ColourSpace::ICCBased(read_icc) => {
      assert_eq(read_icc.icc_n, 3)
      match read_icc.icc_alternate {
        @pdfspace.ColourSpace::DeviceRGB => ()
        _ => fail("expected DeviceRGB alternate")
      }
    }
    _ => fail("expected ICCBased")
  }
}
