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

///|
test "compose merges translation" {
  let tr : @pdftransform.Transform = [
    @pdftransform.TransformOp::Translate(1.0, 2.0),
    @pdftransform.TransformOp::Scale((0.0, 0.0), 2.0, 2.0),
  ]
  let composed = @pdftransform.compose(
    @pdftransform.TransformOp::Translate(3.0, -1.0),
    tr,
  )
  match composed {
    [
      @pdftransform.TransformOp::Translate(dx, dy),
      @pdftransform.TransformOp::Scale(_, sx, sy),
    ] => {
      assert_close(dx, 4.0)
      assert_close(dy, 1.0)
      assert_close(sx, 2.0)
      assert_close(sy, 2.0)
    }
    _ => fail("expected merged translation")
  }
}

///|
test "compose merges scale with same center" {
  let tr : @pdftransform.Transform = [
    @pdftransform.TransformOp::Scale((1.0, 1.0), 2.0, 3.0),
  ]
  let composed = @pdftransform.compose(
    @pdftransform.TransformOp::Scale((1.0, 1.0), 4.0, 5.0),
    tr,
  )
  match composed {
    [@pdftransform.TransformOp::Scale((cx, cy), sx, sy)] => {
      assert_close(cx, 1.0)
      assert_close(cy, 1.0)
      assert_close(sx, 8.0)
      assert_close(sy, 15.0)
    }
    _ => fail("expected merged scale")
  }
}

///|
test "compose keeps scale with different centers" {
  let tr : @pdftransform.Transform = [
    @pdftransform.TransformOp::Scale((0.0, 0.0), 2.0, 2.0),
  ]
  let composed = @pdftransform.compose(
    @pdftransform.TransformOp::Scale((1.0, 0.0), 3.0, 3.0),
    tr,
  )
  match composed {
    [
      @pdftransform.TransformOp::Scale((cx, _), _, _),
      @pdftransform.TransformOp::Scale((cx2, _), _, _),
    ] => {
      assert_close(cx, 1.0)
      assert_close(cx2, 0.0)
    }
    _ => fail("expected two scale ops")
  }
}

///|
test "append applies second transform first" {
  let a : @pdftransform.Transform = [
    @pdftransform.TransformOp::Translate(1.0, 2.0),
  ]
  let b : @pdftransform.Transform = [
    @pdftransform.TransformOp::Scale((0.0, 0.0), 2.0, 2.0),
  ]
  let combined = @pdftransform.append(a, b)
  let (x, y) = @pdftransform.transform(combined, (1.0, 1.0))
  assert_close(x, 3.0)
  assert_close(y, 4.0)
}

///|
test "shear transforms via matrix and op" {
  let mx = @pdftransform.mkshearx((0.0, 0.0), 2.0)
  let (x1, y1) = @pdftransform.transform_matrix(mx, (1.0, 1.0))
  assert_close(x1, 3.0)
  assert_close(y1, 1.0)
  let tr_x : @pdftransform.Transform = [
    @pdftransform.TransformOp::ShearX((0.0, 0.0), 2.0),
  ]
  let (x2, y2) = @pdftransform.transform(tr_x, (1.0, 1.0))
  assert_close(x2, 3.0)
  assert_close(y2, 1.0)
  let my = @pdftransform.mksheary((0.0, 0.0), 2.0)
  let (x3, y3) = @pdftransform.transform_matrix(my, (1.0, 1.0))
  assert_close(x3, 1.0)
  assert_close(y3, 3.0)
  let tr_y : @pdftransform.Transform = [
    @pdftransform.TransformOp::ShearY((0.0, 0.0), 2.0),
  ]
  let (x4, y4) = @pdftransform.transform(tr_y, (1.0, 1.0))
  assert_close(x4, 1.0)
  assert_close(y4, 3.0)
}

///|
test "string_of_transform orders operations" {
  let tr : @pdftransform.Transform = [
    @pdftransform.TransformOp::Translate(1.0, 2.0),
    @pdftransform.TransformOp::Scale((0.0, 0.0), 2.0, 2.0),
  ]
  let rendered = @pdftransform.string_of_transform(tr)
  let scale_idx = match rendered.find("Scale about") {
    Some(i) => i
    None => fail("expected scale line")
  }
  let translate_idx = match rendered.find("Translate by") {
    Some(i) => i
    None => fail("expected translate line")
  }
  assert_true(scale_idx < translate_idx)
}

///|
test "decompose handles zero scale" {
  let m = @pdftransform.mkscale((0.0, 0.0), 0.0, 0.0)
  let (scale, aspect, rotation, shear, tx, ty) = @pdftransform.decompose(m)
  assert_close(scale, 0.0)
  assert_close(aspect, 0.0)
  assert_close(rotation, 0.0)
  assert_close(shear, 0.0)
  assert_close(tx, 0.0)
  assert_close(ty, 0.0)
}
