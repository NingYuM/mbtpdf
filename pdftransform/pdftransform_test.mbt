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

///|
test "matrix_compose applies m then m_prime" {
  let translate = @pdftransform.mktranslate(2.0, 3.0)
  let scale = @pdftransform.mkscale((0.0, 0.0), 2.0, 2.0)
  let composed = @pdftransform.matrix_compose(scale, translate)
  let (x, y) = @pdftransform.transform_matrix(composed, (1.0, 1.0))
  assert_close(x, 6.0)
  assert_close(y, 8.0)
}

///|
test "matrix_of_transform composes in list order" {
  let tr : @pdftransform.Transform = [
    @pdftransform.TransformOp::Translate(2.0, 3.0),
    @pdftransform.TransformOp::Scale((0.0, 0.0), 2.0, 3.0),
  ]
  let expected = @pdftransform.matrix_compose(
    @pdftransform.matrix_of_op(
      @pdftransform.TransformOp::Scale((0.0, 0.0), 2.0, 3.0),
    ),
    @pdftransform.matrix_compose(
      @pdftransform.matrix_of_op(@pdftransform.TransformOp::Translate(2.0, 3.0)),
      @pdftransform.i_matrix,
    ),
  )
  let actual = @pdftransform.matrix_of_transform(tr)
  assert_eq(
    @pdftransform.string_of_matrix(actual),
    @pdftransform.string_of_matrix(expected),
  )
}

///|
test "decompose and recompose translation" {
  let m = @pdftransform.mktranslate(4.0, -1.0)
  let (scale, aspect, rotation, shear, tx, ty) = @pdftransform.decompose(m)
  let recomposed = @pdftransform.recompose(
    scale, aspect, rotation, shear, tx, ty,
  )
  assert_eq(
    @pdftransform.string_of_matrix(m),
    @pdftransform.string_of_matrix(recomposed),
  )
}

///|
test "matrix_invert fails for zero scale" {
  let m = @pdftransform.mkscale((0.0, 0.0), 0.0, 1.0)
  let res : Result[@pdftransform.TransformMatrix, Error] = try? @pdftransform.matrix_invert(
    m,
  )
  match res {
    Err(_) => ()
    _ => fail("expected NonInvertable")
  }
}
