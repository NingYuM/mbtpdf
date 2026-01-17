///|
priv suberror AddPrefixError {
  NonIso
}

///|
fn next_string(s : String) -> String {
  if s == "" {
    "a"
  } else if s.get_char(0) == Some('z') {
    "a" + s
  } else {
    let sb = StringBuilder::new()
    let mut first = true
    for c in s {
      if first {
        first = false
        let next = c.to_int() + 1
        match next.to_char() {
          Some(ch) => sb.write_char(ch)
          None => sb.write_char(c)
        }
      } else {
        sb.write_char(c)
      }
    }
    sb.to_string()
  }
}

///|
fn is_prefix(prefix : String, name : String) -> Bool {
  name.has_prefix(prefix[:])
}

///|
fn names_used(pdf : @pdf.Pdf) -> Array[String] {
  let names : Array[String] = Array::new()
  fn unslash(x : String) -> String {
    if x == "" {
      ""
    } else {
      (try! x[1:]).to_string()
    }
  }

  @pdf.objiter(
    fn(_n : Int, obj : @pdf.PdfObject) -> Unit {
      match obj {
        @pdf.PdfObject::Dictionary(_) | @pdf.PdfObject::Stream(_) =>
          match @pdf.lookup_direct(pdf, "/Type", obj) {
            Some(@pdf.PdfObject::Name("/Page"))
            | Some(@pdf.PdfObject::Name("/Pages")) =>
              match @pdf.lookup_direct(pdf, "/Resources", obj) {
                Some(resources) =>
                  for key in resource_keys {
                    match @pdf.lookup_direct(pdf, key, resources) {
                      Some(@pdf.PdfObject::Dictionary(d)) =>
                        for entry in d {
                          names.push(unslash(entry.0))
                        }
                      _ => ()
                    }
                  }
                _ => ()
              }
            _ => ()
          }
        _ => ()
      }
    },
    pdf,
  )
  names.sort()
  names.dedup()
  names
}

///|
fn shortest(names : Array[String]) -> String {
  let mut prefix = "a"
  while names.any(name => is_prefix(prefix, name)) {
    prefix = next_string(prefix)
  }
  prefix
}

///|
/// Find a prefix which is not used by any resource names in the document.
pub fn shortest_unused_prefix(pdf : @pdf.Pdf) -> String {
  shortest(names_used(pdf))
}

///|
fn addp(prefix : String, name : String) -> String raise {
  if name == "" {
    raise @pdf.PdfError::Msg("addp: blank name")
  }
  "/" + prefix + (try! name[1:]).to_string()
}

///|
let direct_cs_names : Array[String] = [
  "/DeviceGray", "/DeviceRGB", "/DeviceCMYK", "/Pattern",
]

///|
let direct_cs_names_inline : Array[String] = [
  "/DeviceGray", "/DeviceRGB", "/DeviceCMYK", "/G", "/RGB", "/CMYK",
]

///|
fn prefix_operator(
  pdf : @pdf.Pdf,
  prefix : String,
  op : @pdfops.Op,
) -> @pdfops.Op raise {
  match op {
    @pdfops.Op::OpTf(f, s) => @pdfops.Op::OpTf(addp(prefix, f), s)
    @pdfops.Op::Opgs(n) => @pdfops.Op::Opgs(addp(prefix, n))
    @pdfops.Op::OpCS(n) =>
      @pdfops.Op::OpCS(
        if direct_cs_names.contains(n) {
          n
        } else {
          addp(prefix, n)
        },
      )
    @pdfops.Op::Opcs(n) =>
      @pdfops.Op::Opcs(
        if direct_cs_names.contains(n) {
          n
        } else {
          addp(prefix, n)
        },
      )
    @pdfops.Op::OpSCNName(s, ns) => @pdfops.Op::OpSCNName(addp(prefix, s), ns)
    @pdfops.Op::OpscnName(s, ns) => @pdfops.Op::OpscnName(addp(prefix, s), ns)
    @pdfops.Op::Opsh(s) => @pdfops.Op::Opsh(addp(prefix, s))
    @pdfops.Op::OpDo(x) => @pdfops.Op::OpDo(addp(prefix, x))
    @pdfops.Op::OpDP(n, @pdf.PdfObject::Name(x)) =>
      @pdfops.Op::OpDP(n, @pdf.PdfObject::Name(addp(prefix, x)))
    @pdfops.Op::OpBDC(n, @pdf.PdfObject::Name(x)) =>
      @pdfops.Op::OpBDC(n, @pdf.PdfObject::Name(addp(prefix, x)))
    @pdfops.Op::InlineImage((dict, dp, bytes)) => {
      let dict_updated = match
        @pdf.lookup_direct_orelse(pdf, "/CS", "/ColorSpace", dict) {
        Some(@pdf.PdfObject::Name(n)) if direct_cs_names_inline.contains(n) =>
          dict
        Some(@pdf.PdfObject::Name(n)) => {
          let stripped = @pdf.remove_dict_entry(
            @pdf.remove_dict_entry(dict, "/ColorSpace"),
            "/CS",
          )
          @pdf.add_dict_entry(
            stripped,
            "/CS",
            @pdf.PdfObject::Name(addp(prefix, n)),
          )
        }
        _ => dict
      }
      @pdfops.Op::InlineImage((dict_updated, dp, bytes))
    }
    _ => op
  }
}

///|
fn change_resources(
  pdf : @pdf.Pdf,
  prefix : String,
  resources : @pdf.PdfObject,
) -> @pdf.PdfObject raise {
  fn newdict(name : String) -> @pdf.PdfObject raise {
    match @pdf.lookup_direct(pdf, name, resources) {
      Some(@pdf.PdfObject::Dictionary(dict)) =>
        @pdf.PdfObject::Dictionary(
          dict.map(pair => (addp(prefix, pair.0), pair.1)),
        )
      _ => @pdf.PdfObject::Dictionary([])
    }
  }

  let newdicts = resource_keys.map(newdict)
  let mut updated = resources
  for i, key in resource_keys {
    updated = @pdf.add_dict_entry(updated, key, newdicts[i])
  }
  updated
}

///|
fn fix_stream(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  prefix : String,
  fixed_streams : Map[Int, Unit],
  obj : @pdf.PdfObject,
) -> Unit raise {
  match obj {
    @pdf.PdfObject::Indirect(i) =>
      if fixed_streams.get(i) == None {
        let operators = @pdfops.parse_operators(pdf, resources, [obj])
        let operators_updated = operators.map(op => prefix_operator(
          pdf, prefix, op,
        ))
        let stream_obj = @pdf.lookup_obj(pdf, i)
        match stream_obj {
          @pdf.PdfObject::Stream(r) =>
            match @pdfops.stream_of_ops(operators_updated) {
              @pdf.PdfObject::Stream(updated) => {
                r.val = updated.val
                fixed_streams.set(i, ())
              }
              _ => fail("add_prefix: bad stream")
            }
          _ => fail("add_prefix: bad stream 2")
        }
      }
    _ => fail("add_prefix: not indirect")
  }
}

///|
fn add_prefix_impl(pdf : @pdf.Pdf, prefix : String) -> Unit raise {
  let fixed_streams : Map[Int, Unit] = Map::new()
  @pdf.objselfmap(
    fn(obj : @pdf.PdfObject) -> @pdf.PdfObject raise {
      match obj {
        @pdf.PdfObject::Dictionary(dict) =>
          match @pdf.lookup_direct(pdf, "/Type", obj) {
            Some(@pdf.PdfObject::Name("/Page"))
            | Some(@pdf.PdfObject::Name("/Pages")) => {
              let (resources, resources_updated) = match
                @pdf.lookup_direct(pdf, "/Resources", obj) {
                Some(res) =>
                  (Some(res), Some(change_resources(pdf, prefix, res)))
                None => (None, None)
              }
              let resources_obj = match resources {
                Some(res) => res
                None => @pdf.PdfObject::Dictionary([])
              }
              match dict.search_by(pair => pair.0 == "/Contents") {
                Some(index) =>
                  match dict[index].1 {
                    @pdf.PdfObject::Indirect(_) =>
                      fix_stream(
                        pdf,
                        resources_obj,
                        prefix,
                        fixed_streams,
                        dict[index].1,
                      )
                    @pdf.PdfObject::Array(a) => {
                      if a.length() > 1 {
                        try {
                          for c in a {
                            let direct = @pdf.direct(pdf, c)
                            @pdfcodec.decode_pdfstream(pdf, direct)
                            @pdf.getstream(direct)
                            let bytes = match direct {
                              @pdf.PdfObject::Stream(r) =>
                                match r.val {
                                  (_, @pdf.Stream::Got(data)) => data
                                  _ =>
                                    raise @pdf.PdfError::Msg(
                                      "add_prefix: bad stream",
                                    )
                                }
                              _ =>
                                raise @pdf.PdfError::Msg(
                                  "add_prefix: bad stream",
                                )
                            }
                            ignore(
                              @pdfops.parse_single_stream(
                                pdf, resources_obj, bytes,
                              ),
                            )
                          }
                        } catch {
                          _ => {
                            @pdfe.log(
                              "add_prefix: non-ISO PDF detected streams detected. Fixing...\n",
                            )
                            raise AddPrefixError::NonIso
                          }
                        }
                      }
                      for c in a {
                        fix_stream(pdf, resources_obj, prefix, fixed_streams, c)
                      }
                    }
                    _ => ()
                  }
                None => ()
              }
              match resources_updated {
                Some(updated) => @pdf.add_dict_entry(obj, "/Resources", updated)
                None => obj
              }
            }
            _ => obj
          }
        _ => obj
      }
    },
    pdf,
  )
}

///|
fn merge_content_streams(pdf : @pdf.Pdf) -> Unit raise {
  @pdf.objselfmap(
    fn(obj : @pdf.PdfObject) -> @pdf.PdfObject raise {
      match obj {
        @pdf.PdfObject::Dictionary(dict) =>
          match @pdf.lookup_direct(pdf, "/Type", obj) {
            Some(@pdf.PdfObject::Name("/Page"))
            | Some(@pdf.PdfObject::Name("/Pages")) =>
              match dict.search_by(pair => pair.0 == "/Contents") {
                Some(index) =>
                  match dict[index].1 {
                    @pdf.PdfObject::Indirect(_) => obj
                    @pdf.PdfObject::Array(a) =>
                      if a.length() <= 1 {
                        obj
                      } else {
                        let direct_streams = a.map(c => @pdf.direct(pdf, c))
                        for stream in direct_streams {
                          @pdfcodec.decode_pdfstream(pdf, stream)
                          @pdf.getstream(stream)
                        }
                        let rawstreams : Array[@pdfio.MutableBytes] = Array::new()
                        for stream in direct_streams {
                          match stream {
                            @pdf.PdfObject::Stream(r) =>
                              match r.val {
                                (_, @pdf.Stream::Got(data)) =>
                                  rawstreams.push(data)
                                _ =>
                                  raise @pdf.PdfError::Msg(
                                    "merge_content_streams: bad stream",
                                  )
                              }
                            _ =>
                              raise @pdf.PdfError::Msg(
                                "merge_content_streams: bad stream",
                              )
                          }
                        }
                        let merged = @pdfops.concat_bytess(rawstreams)
                        let stream = @pdf.PdfObject::Stream(
                          Ref::new(
                            (
                              @pdf.PdfObject::Dictionary([
                                (
                                  "/Length",
                                  @pdf.PdfObject::Integer(
                                    @pdfio.bytes_size(merged),
                                  ),
                                ),
                              ]),
                              @pdf.Stream::Got(merged),
                            ),
                          ),
                        )
                        let objnum = @pdf.addobj(pdf, stream)
                        @pdf.add_dict_entry(
                          obj,
                          "/Contents",
                          @pdf.PdfObject::Indirect(objnum),
                        )
                      }
                    _ => obj
                  }
                None => obj
              }
            _ => obj
          }
        _ => obj
      }
    },
    pdf,
  )
}

///|
/// Prefix resource names and content streams to avoid clashes.
pub fn add_prefix(pdf : @pdf.Pdf, prefix : String) -> Unit raise {
  add_prefix_impl(pdf, prefix) catch {
    AddPrefixError::NonIso => {
      merge_content_streams(pdf)
      add_prefix_impl(pdf, prefix)
    }
    err => raise err
  }
}
