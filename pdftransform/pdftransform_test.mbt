///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
test "translate transform" {
  let tr : @pdftransform.Transform = [
    @pdftransform.TransformOp::Translate(1.0, 2.0),
  ]
  let (x, y) = @pdftransform.transform(tr, (3.0, 4.0))
  assert_close(x, 4.0)
  assert_close(y, 6.0)
}

///|
test "rotate transform" {
  let half_pi = 2.0 * @math.atan(1.0)
  let tr : @pdftransform.Transform = [
    @pdftransform.TransformOp::Rotate((0.0, 0.0), half_pi),
  ]
  let (x, y) = @pdftransform.transform(tr, (1.0, 0.0))
  assert_close(x, 0.0)
  assert_close(y, 1.0)
}

///|
test "invert translation matrix" {
  let m = @pdftransform.mktranslate(5.0, -3.0)
  let inv = @pdftransform.matrix_invert(m) catch { _ => fail("no inverse") }
  let (x, y) = @pdftransform.transform_matrix(inv, (5.0, 7.0))
  assert_close(x, 0.0)
  assert_close(y, 10.0)
}
