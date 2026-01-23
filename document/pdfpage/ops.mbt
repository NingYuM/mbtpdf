///|
/// Prepend operators to a page.
pub fn prepend_operators(
  pdf : @pdf.Pdf,
  ops : Array[@pdfops.Op],
  page : Page,
  fast? : Bool = false,
) -> Page raise {
  if fast {
    {
      content: [@pdfops.stream_of_ops(ops)] + page.content,
      mediabox: page.mediabox,
      resources: page.resources,
      rotate: page.rotate,
      rest: page.rest,
    }
  } else {
    let old_ops = @pdfops.parse_operators(pdf, page.resources, page.content)
    {
      content: [@pdfops.stream_of_ops(ops + old_ops)],
      mediabox: page.mediabox,
      resources: page.resources,
      rotate: page.rotate,
      rest: page.rest,
    }
  }
}

///|
/// Add stack operators to a content stream to ensure it is composeable.
pub fn protect(ops : Array[@pdfops.Op]) -> Array[@pdfops.Op] {
  let mut qs = 0
  let mut bigqs = 0
  for op in ops {
    match (op : @pdfops.Op) {
      Opq => qs = qs + 1
      OpQ => bigqs = bigqs + 1
      _ => ()
    }
  }
  let deficit = if qs > bigqs { qs - bigqs } else { 0 }
  if deficit != 0 {
    @pdfe.log("Q Deficit was nonzero. Fixing. \{deficit}\n")
  }
  let result : Array[@pdfops.Op] = if deficit == 0 {
    []
  } else {
    Array::make(deficit, OpQ)
  }
  result
}

///|
/// Postpend operators to a page.
pub fn postpend_operators(
  pdf : @pdf.Pdf,
  ops : Array[@pdfops.Op],
  page : Page,
  fast? : Bool = false,
) -> Page raise {
  if fast {
    let wrapped : Array[@pdfops.Op] = Array::new()
    wrapped.push(Opq)
    wrapped.append(ops[:])
    wrapped.push(OpQ)
    {
      content: page.content + [@pdfops.stream_of_ops(wrapped)],
      mediabox: page.mediabox,
      resources: page.resources,
      rotate: page.rotate,
      rest: page.rest,
    }
  } else {
    let existing_ops = @pdfops.parse_operators(
      pdf,
      page.resources,
      page.content,
    )
    if existing_ops.length() == 0 {
      {
        content: [@pdfops.stream_of_ops(ops)],
        mediabox: page.mediabox,
        resources: page.resources,
        rotate: page.rotate,
        rest: page.rest,
      }
    } else {
      let protected_ops = protect(existing_ops)
      let combined : Array[@pdfops.Op] = Array::new()
      combined.push(Opq)
      combined.append(existing_ops[:])
      combined.append(protected_ops[:])
      combined.push(OpQ)
      combined.append(ops[:])
      {
        content: [@pdfops.stream_of_ops(combined)],
        mediabox: page.mediabox,
        resources: page.resources,
        rotate: page.rotate,
        rest: page.rest,
      }
    }
  }
}
