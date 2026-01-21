///|
/// PostScript calculator operators.
pub(all) enum Calculator {
  If(Array[Calculator])
  IfElse(Array[Calculator], Array[Calculator])
  Bool(Bool)
  Float(Double)
  Int(Int)
  Abs
  Add
  Atan
  Ceiling
  Cos
  Cvi
  Cvr
  Div
  Exp
  Floor
  Idiv
  Ln
  Log
  Mod
  Mul
  Neg
  Round
  Sin
  Sqrt
  Sub
  Truncate
  And
  Bitshift
  Eq
  Ge
  Gt
  Le
  Lt
  Ne
  Not
  Or
  Xor
  Copy
  Exch
  Pop
  Dup
  Index
  Roll
}

///|
/// Sampled functions.
pub(all) struct Sampled {
  size : Array[Int]
  order : Int
  encode : Array[Double]
  decode : Array[Double]
  bps : Int
  samples : Array[Int]
}

///|
/// Interpolation functions.
pub(all) struct Interpolation {
  c0 : Array[Double]
  c1 : Array[Double]
  n : Double
}

///|
/// Stitching functions.
pub(all) struct Stitching {
  functions : Array[PdfFunction]
  bounds : Array[Double]
  stitch_encode : Array[Double]
}

///|
/// Function kinds.
pub(all) enum PdfFunctionKind {
  Interpolation(Interpolation)
  Stitching(Stitching)
  Sampled(Sampled)
  Calculator(Array[Calculator])
}

///|
/// Main function type.
pub(all) struct PdfFunction {
  func : PdfFunctionKind
  domain : Array[Double]
  range : Array[Double]?
}

///|
/// Bad inputs have been given to a function.
pub(all) suberror BadFunctionEvaluation {
  Msg(String)
}

///|
fn string_of_calculator_inner(op : Calculator) -> String {
  match op {
    Calculator::If(ops) => "\{string_of_calculator(ops)} if"
    Calculator::IfElse(a, b) =>
      "\{string_of_calculator(a)} \{string_of_calculator(b)} ifelse"
    Calculator::Bool(true) => "true"
    Calculator::Bool(false) => "false"
    Calculator::Float(f) => f.to_string()
    Calculator::Int(i) => i.to_string()
    Calculator::Abs => "abs"
    Calculator::Add => "add"
    Calculator::Atan => "atan"
    Calculator::Ceiling => "ceiling"
    Calculator::Cos => "cos"
    Calculator::Cvi => "cvi"
    Calculator::Cvr => "cvr"
    Calculator::Div => "div"
    Calculator::Exp => "exp"
    Calculator::Floor => "floor"
    Calculator::Idiv => "idiv"
    Calculator::Ln => "ln"
    Calculator::Log => "log"
    Calculator::Mod => "mod"
    Calculator::Mul => "mul"
    Calculator::Neg => "neg"
    Calculator::Round => "round"
    Calculator::Sin => "sin"
    Calculator::Sqrt => "sqrt"
    Calculator::Sub => "sub"
    Calculator::Truncate => "truncate"
    Calculator::And => "and"
    Calculator::Bitshift => "bitshift"
    Calculator::Eq => "eq"
    Calculator::Ge => "ge"
    Calculator::Gt => "gt"
    Calculator::Le => "le"
    Calculator::Lt => "lt"
    Calculator::Ne => "ne"
    Calculator::Not => "not"
    Calculator::Or => "or"
    Calculator::Xor => "xor"
    Calculator::Copy => "copy"
    Calculator::Exch => "exch"
    Calculator::Pop => "pop"
    Calculator::Dup => "dup"
    Calculator::Index => "index"
    Calculator::Roll => "roll"
  }
}

///|
fn string_of_calculator(ops : Array[Calculator]) -> String {
  let parts = ops.map(string_of_calculator_inner)
  "{" + parts.join(" ") + "}"
}

///|
fn log_line(message : String) -> Unit {
  @pdfe.log(message + "\n")
}

///|
fn print_doubles(values : Array[Double]) -> Unit {
  if values.length() == 0 {
    log_line("")
  } else {
    log_line(values.map(v => v.to_string()).join(" "))
  }
}

///|
fn print_ints(values : Array[Int]) -> Unit {
  if values.length() == 0 {
    log_line("")
  } else {
    log_line(values.map(v => v.to_string()).join(" "))
  }
}

///|
/// Print a function to stdout for debug.
pub fn print_function(f : PdfFunction) -> Unit {
  log_line("Domain...")
  print_doubles(f.domain)
  match f.range {
    None => log_line("null range")
    Some(values) => print_doubles(values)
  }
  match f.func {
    PdfFunctionKind::Sampled(s) => {
      log_line("Sampled")
      log_line("size: ")
      print_ints(s.size)
      log_line("order: \{s.order}")
      log_line("encode:")
      print_doubles(s.encode)
      log_line("decode:")
      print_doubles(s.decode)
      log_line("original bits per sample: \{s.bps}")
    }
    PdfFunctionKind::Interpolation(i) => {
      log_line("Interpolation")
      log_line("C0:")
      print_doubles(i.c0)
      log_line("C1:")
      print_doubles(i.c1)
      log_line("n = \{i.n}")
    }
    PdfFunctionKind::Stitching(s) => {
      log_line("Stitching")
      for fun in s.functions {
        print_function(fun)
      }
      log_line("Bounds:")
      print_doubles(s.bounds)
      log_line("Encode:")
      print_doubles(s.stitch_encode)
    }
    PdfFunctionKind::Calculator(c) => {
      log_line("Calculator:")
      log_line(string_of_calculator(c))
    }
  }
}

///|
fn keyword_of_string(value : String) -> Calculator? {
  match value {
    "abs" => Some(Calculator::Abs)
    "add" => Some(Calculator::Add)
    "atan" => Some(Calculator::Atan)
    "ceiling" => Some(Calculator::Ceiling)
    "cos" => Some(Calculator::Cos)
    "cvi" => Some(Calculator::Cvi)
    "cvr" => Some(Calculator::Cvr)
    "div" => Some(Calculator::Div)
    "exp" => Some(Calculator::Exp)
    "floor" => Some(Calculator::Floor)
    "idiv" => Some(Calculator::Idiv)
    "ln" => Some(Calculator::Ln)
    "log" => Some(Calculator::Log)
    "mod" => Some(Calculator::Mod)
    "mul" => Some(Calculator::Mul)
    "neg" => Some(Calculator::Neg)
    "round" => Some(Calculator::Round)
    "sin" => Some(Calculator::Sin)
    "sqrt" => Some(Calculator::Sqrt)
    "sub" => Some(Calculator::Sub)
    "truncate" => Some(Calculator::Truncate)
    "and" => Some(Calculator::And)
    "bitshift" => Some(Calculator::Bitshift)
    "eq" => Some(Calculator::Eq)
    "ge" => Some(Calculator::Ge)
    "gt" => Some(Calculator::Gt)
    "le" => Some(Calculator::Le)
    "lt" => Some(Calculator::Lt)
    "ne" => Some(Calculator::Ne)
    "not" => Some(Calculator::Not)
    "or" => Some(Calculator::Or)
    "xor" => Some(Calculator::Xor)
    "copy" => Some(Calculator::Copy)
    "exch" => Some(Calculator::Exch)
    "pop" => Some(Calculator::Pop)
    "dup" => Some(Calculator::Dup)
    "index" => Some(Calculator::Index)
    "roll" => Some(Calculator::Roll)
    _ => None
  }
}

///|
fn strip_outer_braces(
  tokens : Array[@pdfgenlex.Token],
) -> Array[@pdfgenlex.Token] {
  let mut start = 0
  let mut end = tokens.length()
  while start < end {
    match tokens[start] {
      @pdfgenlex.Token::LexName("{") | @pdfgenlex.Token::LexName("}") => {
        start = start + 1
        if end > start {
          end = end - 1
        }
      }
      _ => break
    }
  }
  tokens.sub(start~, end~).to_array()
}

///|
fn group_operators(
  tokens : Array[@pdfgenlex.Token],
) -> Array[Array[@pdfgenlex.Token]] {
  let groups = Array::new()
  let mut i = 0
  while i < tokens.length() {
    match tokens[i] {
      @pdfgenlex.Token::LexName("{") => {
        let mut j = i + 1
        while j < tokens.length() {
          match tokens[j] {
            @pdfgenlex.Token::LexName("}") => break
            _ => j = j + 1
          }
        }
        let group = tokens.sub(start=i + 1, end=j).to_array()
        groups.push(group)
        i = if j < tokens.length() { j + 1 } else { j }
      }
      _ => {
        groups.push([tokens[i]])
        i = i + 1
      }
    }
  }
  groups
}

///|
fn is_single_name(tokens : Array[@pdfgenlex.Token], name : String) -> Bool {
  match tokens {
    [@pdfgenlex.Token::LexName(value)] => value == name
    _ => false
  }
}

///|
fn parse_groups(
  groups : Array[Array[@pdfgenlex.Token]],
) -> Array[Calculator] raise {
  let out = Array::new()
  let mut i = 0
  while i < groups.length() {
    if i + 2 < groups.length() && is_single_name(groups[i + 2], "ifelse") {
      let a = parse_calculator_tokens(groups[i])
      let b = parse_calculator_tokens(groups[i + 1])
      out.push(Calculator::IfElse(a, b))
      i = i + 3
    } else if i + 1 < groups.length() && is_single_name(groups[i + 1], "if") {
      let body = parse_calculator_tokens(groups[i])
      out.push(Calculator::If(body))
      i = i + 2
    } else {
      let group = groups[i]
      match group {
        [@pdfgenlex.Token::LexName("true")] => out.push(Calculator::Bool(true))
        [@pdfgenlex.Token::LexName("false")] =>
          out.push(Calculator::Bool(false))
        [@pdfgenlex.Token::LexReal(f)] => out.push(Calculator::Float(f))
        [@pdfgenlex.Token::LexInt(v)] => out.push(Calculator::Int(v))
        [@pdfgenlex.Token::LexName(name)] =>
          match keyword_of_string(name) {
            Some(op) => out.push(op)
            None => {
              @pdfe.log("Bad keyword \{name}\n")
              raise @pdf.PdfError::Msg("Cannot parse Type 4 function")
            }
          }
        _ => raise @pdf.PdfError::Msg("Cannot parse Type 4 function")
      }
      i = i + 1
    }
  }
  out
}

///|
fn parse_calculator_tokens(
  tokens : Array[@pdfgenlex.Token],
) -> Array[Calculator] raise {
  let stripped = strip_outer_braces(tokens)
  let groups = group_operators(stripped)
  parse_groups(groups)
}

///|
fn parse_calculator(text : String) -> Array[Calculator] raise {
  let tokens = @pdfgenlex.lex(@pdfio.input_of_string(text))
  parse_calculator_tokens(tokens)
}

///|
fn pairs_of_list_eval(
  values : Array[Double],
) -> Array[(Double, Double)] raise BadFunctionEvaluation {
  if values.length() % 2 == 1 {
    raise BadFunctionEvaluation::Msg("Bad list length")
  }
  let out = Array::new()
  for i = 0; i + 1 < values.length(); i = i + 2 {
    out.push((values[i], values[i + 1]))
  }
  out
}

///|
fn split_pairs(
  values : Array[(Double, Double)],
) -> (Array[Double], Array[Double]) {
  let left = Array::new(capacity=values.length())
  let right = Array::new(capacity=values.length())
  for pair in values {
    left.push(pair.0)
    right.push(pair.1)
  }
  (left, right)
}

///|
fn many(value : Double, count : Int) -> Array[Double] {
  let out = Array::new(capacity=count)
  for _ in 0..<count {
    out.push(value)
  }
  out
}

///|
fn min(a : Int, b : Int) -> Int {
  if a < b { a } else { b }
}

///|
fn interleave_lists(a : Array[Double], b : Array[Double]) -> Array[Double] {
  let out = Array::new(capacity=a.length() + b.length())
  let len = min(a.length(), b.length())
  for i in 0..<len {
    out.push(a[i])
    out.push(b[i])
  }
  out
}

///|
fn product(values : Array[Int]) -> Int {
  let mut total = 1
  for value in values {
    total = total * value
  }
  total
}

///|
fn[A, B, C] map2(a : Array[A], b : Array[B], f : (A, B) -> C) -> Array[C] {
  let len = min(a.length(), b.length())
  let out = Array::new(capacity=len)
  for i in 0..<len {
    out.push(f(a[i], b[i]))
  }
  out
}

///|
fn[A, B, C, D] map3(
  a : Array[A],
  b : Array[B],
  c : Array[C],
  f : (A, B, C) -> D,
) -> Array[D] {
  let len = min(min(a.length(), b.length()), c.length())
  let out = Array::new(capacity=len)
  for i in 0..<len {
    out.push(f(a[i], b[i], c[i]))
  }
  out
}

///|
fn[A, B, C, D, E, F] map5(
  a : Array[A],
  b : Array[B],
  c : Array[C],
  d : Array[D],
  e : Array[E],
  f : (A, B, C, D, E) -> F,
) -> Array[F] {
  let len = min(
    min(min(a.length(), b.length()), c.length()),
    min(d.length(), e.length()),
  )
  let out = Array::new(capacity=len)
  for i in 0..<len {
    out.push(f(a[i], b[i], c[i], d[i], e[i]))
  }
  out
}

///|
fn[T] flatten(lists : Array[Array[T]]) -> Array[T] {
  let out = Array::new()
  for list in lists {
    for item in list {
      out.push(item)
    }
  }
  out
}

///|
fn[T] take(items : Array[T], count : Int) -> Array[T] {
  let len = min(count, items.length())
  let out = Array::new(capacity=len)
  for i in 0..<len {
    out.push(items[i])
  }
  out
}

///|
fn[T] select(index : Int, items : Array[T]) -> T raise BadFunctionEvaluation {
  if index <= 0 || index > items.length() {
    raise BadFunctionEvaluation::Msg("select")
  }
  items[index - 1]
}

///|
fn rad_of_deg(deg : Double) -> Double {
  deg * @math.PI / 180.0
}

///|
/// Parse a function given a document and function object.
pub fn parse_function(
  pdf : @pdf.Pdf,
  obj : @pdf.PdfObject,
) -> PdfFunction raise {
  let f = @pdf.direct(pdf, obj)
  let getnum_direct = (value : @pdf.PdfObject) => @pdf.getnum(pdf, value)
  let domain = match @pdf.lookup_fail("No /Domain", pdf, "/Domain", f) {
    @pdf.PdfObject::Array(values) => values.map(getnum_direct)
    _ => raise @pdf.PdfError::Msg("Bad /Domain")
  }
  let range = match @pdf.lookup_direct(pdf, "/Range", f) {
    Some(@pdf.PdfObject::Array(values)) => Some(values.map(getnum_direct))
    _ => None
  }
  let func = match
    @pdf.lookup_fail("no /FunctionType", pdf, "/FunctionType", f) {
    @pdf.PdfObject::Integer(0) => {
      let size = match
        @pdf.lookup_fail("no /Size (sampled fun)", pdf, "/Size", f) {
        @pdf.PdfObject::Array(values) =>
          values.map(value => match value {
            @pdf.PdfObject::Integer(n) => n
            _ => raise @pdf.PdfError::Msg("bad /Size (sampled fun)")
          })
        _ => raise @pdf.PdfError::Msg("Bad /Size (sampled fun)")
      }
      let order = match @pdf.lookup_direct(pdf, "/Order", f) {
        Some(@pdf.PdfObject::Integer(n)) => n
        _ => 1
      }
      let encode = match @pdf.lookup_direct(pdf, "/Encode", f) {
        Some(@pdf.PdfObject::Array(values)) if values.length() ==
          2 * size.length() => values.map(getnum_direct)
        _ =>
          interleave_lists(
            many(0.0, size.length()),
            size.map(x => (x - 1).to_double()),
          )
      }
      let decode = match @pdf.lookup_direct(pdf, "/Decode", f) {
        Some(@pdf.PdfObject::Array(values)) => values.map(getnum_direct)
        _ =>
          match range {
            Some(values) => values
            None => raise @pdf.PdfError::Msg("No /Range")
          }
      }
      let bitspersample = match
        @pdf.lookup_fail("no /BitsPerSample", pdf, "/BitsPerSample", f) {
        @pdf.PdfObject::Integer(i) => i
        _ => raise @pdf.PdfError::Msg("Bad /BitsPerSample")
      }
      @pdfcodec.decode_pdfstream(pdf, f)
      let samples_count = product(size) * (decode.length() / 2)
      let data = match f {
        @pdf.PdfObject::Stream(r) =>
          match r.val {
            (_, @pdf.Stream::Got(bytes)) => bytes
            _ => raise @pdf.PdfError::Msg("No stream data")
          }
        _ => raise @pdf.PdfError::Msg("This is not a function")
      }
      let samples = read_samples(data, samples_count, bitspersample)
      PdfFunctionKind::Sampled({
        size,
        order,
        encode,
        decode,
        bps: bitspersample,
        samples,
      })
    }
    @pdf.PdfObject::Integer(2) => {
      let c0 = match @pdf.lookup_direct(pdf, "/C0", f) {
        Some(@pdf.PdfObject::Array(values)) => values.map(getnum_direct)
        _ => [0.0]
      }
      let c1 = match @pdf.lookup_direct(pdf, "/C1", f) {
        Some(@pdf.PdfObject::Array(values)) => values.map(getnum_direct)
        _ => [1.0]
      }
      let n = getnum_direct(
        @pdf.lookup_fail("No /N in Type 2 fun", pdf, "/N", f),
      )
      PdfFunctionKind::Interpolation({ c0, c1, n })
    }
    @pdf.PdfObject::Integer(3) => {
      let functions = match
        @pdf.lookup_fail("no /Functions", pdf, "/Functions", f) {
        @pdf.PdfObject::Array(values) => values
        _ => raise @pdf.PdfError::Msg("Bad /Functions")
      }
      let bounds = match @pdf.lookup_fail("no /Bounds", pdf, "/Bounds", f) {
        @pdf.PdfObject::Array(values) => values.map(getnum_direct)
        _ => raise @pdf.PdfError::Msg("Bad /Bounds")
      }
      let encode = match @pdf.lookup_fail("no /Encode", pdf, "/Encode", f) {
        @pdf.PdfObject::Array(values) => values.map(getnum_direct)
        _ => raise @pdf.PdfError::Msg("Bad /Bounds")
      }
      PdfFunctionKind::Stitching({
        functions: functions.map(value => parse_function(pdf, value)),
        bounds,
        stitch_encode: encode,
      })
    }
    @pdf.PdfObject::Integer(4) => {
      @pdfcodec.decode_pdfstream(pdf, f)
      match f {
        @pdf.PdfObject::Stream(r) =>
          match r.val {
            (_, @pdf.Stream::Got(bytes)) =>
              PdfFunctionKind::Calculator(
                parse_calculator(@pdfio.string_of_bytes(bytes)),
              )
            _ => raise @pdf.PdfError::Msg("This is not a function")
          }
        _ => raise @pdf.PdfError::Msg("This is not a function")
      }
    }
    _ => raise @pdf.PdfError::Msg("Unknown function type")
  }
  { domain, range, func }
}

///|
fn read_samples(
  data : @pdfio.MutableBytes,
  count : Int,
  bits_per_sample : Int,
) -> Array[Int] {
  let out = Array::new(capacity=count)
  let bit_pos = Ref::new(0)
  for _ in 0..<count {
    out.push(read_bits(data, bit_pos, bits_per_sample))
  }
  out
}

///|
fn read_bits(data : @pdfio.MutableBytes, bit_pos : Ref[Int], bits : Int) -> Int {
  let mut value = 0
  for _ in 0..<bits {
    let byte_index = bit_pos.val / 8
    let bit_index = 7 - bit_pos.val % 8
    let byte = @pdfio.bget_unsafe(data, byte_index)
    let bit = (byte >> bit_index) & 1
    value = (value << 1) | bit
    bit_pos.val = bit_pos.val + 1
  }
  value
}

///|
fn interpolate(
  x : Double,
  xmin : Double,
  xmax : Double,
  ymin : Double,
  ymax : Double,
) -> Double {
  ymin + (x - xmin) * ((ymax - ymin) / (xmax - xmin))
}

///|
fn clamp_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn clampvals(
  values : Array[Double],
  domain : Array[Double],
) -> Array[Double] raise BadFunctionEvaluation {
  if domain.length() % 2 == 1 {
    raise BadFunctionEvaluation::Msg("Domain wrong")
  }
  let out = Array::new(capacity=values.length())
  for i in 0..<values.length() {
    let d = i * 2
    if d + 1 >= domain.length() {
      raise BadFunctionEvaluation::Msg("Domain wrong")
    }
    out.push(clamp_double(values[i], domain[d], domain[d + 1]))
  }
  out
}

///|
fn eval_function_sampled(
  f : PdfFunction,
  s : Sampled,
  clamped_inputs : Array[Double],
) -> Array[Double] raise BadFunctionEvaluation {
  let range = match f.range {
    Some(r) => r
    None => raise BadFunctionEvaluation::Msg("No Range")
  }
  let (d, d2) = split_pairs(pairs_of_list_eval(f.domain))
  let (e, e2) = split_pairs(pairs_of_list_eval(s.encode))
  let (dec, dec2) = split_pairs(pairs_of_list_eval(s.decode))
  let (r, r2) = split_pairs(pairs_of_list_eval(range))
  let encoded_inputs = map5(clamped_inputs, d, d2, e, e2, interpolate)
  let clamped_encoded = map2(encoded_inputs, s.size, (i, size) => clamp_double(
    i,
    0.0,
    size.to_double() - 1.0,
  ))
  let vals_to_read = range.length() / 2
  let read_table = (inputs : Array[Int]) => {
    if inputs.length() != s.size.length() {
      raise BadFunctionEvaluation::Msg("Incompatible /Size with inputs")
    }
    let multipliers = Array::new(capacity=inputs.length())
    multipliers.push(1)
    for idx in 1..<inputs.length() {
      multipliers.push(product(take(s.size, idx)))
    }
    let mut pos = 0
    for i in 0..<inputs.length() {
      pos = pos + inputs[i] * multipliers[i]
    }
    pos = pos * vals_to_read
    let out = Array::new(capacity=vals_to_read)
    for j in 0..<vals_to_read {
      out.push(s.samples[pos + j])
    }
    out
  }
  let ceilings = clamped_encoded.map(value => value.ceil().to_int())
  let floors = clamped_encoded.map(value => value.floor().to_int())
  let ceiling_results = read_table(ceilings)
  let floor_results = read_table(floors)
  let outputs = Array::new(capacity=ceiling_results.length())
  for i in 0..<ceiling_results.length() {
    let value = ceiling_results[i].to_double() / 2.0 +
      floor_results[i].to_double() / 2.0
    outputs.push(value)
  }
  let outputs_decoded = map5(
    outputs,
    many(0.0, outputs.length()),
    many(@math.pow(2.0, s.bps.to_double()) - 1.0, outputs.length()),
    dec,
    dec2,
    interpolate,
  )
  map3(outputs_decoded, r, r2, (x, rmin, rmax) => clamp_double(x, rmin, rmax))
}

///|
fn value_equal(a : Calculator, b : Calculator) -> Bool {
  match (a, b) {
    (Calculator::Bool(x), Calculator::Bool(y)) => x == y
    (Calculator::Float(x), Calculator::Float(y)) => x == y
    (Calculator::Int(x), Calculator::Int(y)) => x == y
    _ => false
  }
}

///|
fn value_compare(
  a : Calculator,
  b : Calculator,
) -> Int raise BadFunctionEvaluation {
  match (a, b) {
    (Calculator::Bool(x), Calculator::Bool(y)) =>
      if x == y {
        0
      } else if x {
        1
      } else {
        -1
      }
    (Calculator::Float(x), Calculator::Float(y)) =>
      if x < y {
        -1
      } else if x > y {
        1
      } else {
        0
      }
    (Calculator::Int(x), Calculator::Int(y)) =>
      if x < y {
        -1
      } else if x > y {
        1
      } else {
        0
      }
    (Calculator::Bool(_), _) => -1
    (Calculator::Float(_), Calculator::Int(_)) => -1
    (Calculator::Float(_), Calculator::Bool(_)) => 1
    (Calculator::Int(_), _) => 1
    _ => raise BadFunctionEvaluation::Msg("Type error")
  }
}

///|
fn pop_value(
  stack : Array[Calculator],
) -> Calculator raise BadFunctionEvaluation {
  match stack.pop() {
    Some(value) => value
    None => raise BadFunctionEvaluation::Msg("Type error")
  }
}

///|
fn pop_float(stack : Array[Calculator]) -> Double raise BadFunctionEvaluation {
  match pop_value(stack) {
    Calculator::Float(f) => f
    Calculator::Int(i) => i.to_double()
    _ => raise BadFunctionEvaluation::Msg("Type error")
  }
}

///|
fn pop_int(stack : Array[Calculator]) -> Int raise BadFunctionEvaluation {
  match pop_value(stack) {
    Calculator::Int(i) => i
    _ => raise BadFunctionEvaluation::Msg("Type error")
  }
}

///|
fn pop_bool(stack : Array[Calculator]) -> Bool raise BadFunctionEvaluation {
  match pop_value(stack) {
    Calculator::Bool(b) => b
    _ => raise BadFunctionEvaluation::Msg("Type error")
  }
}

///|
fn eval_function_calculator(
  clamped_inputs : Array[Double],
  ops : Array[Calculator],
) -> Array[Double] raise BadFunctionEvaluation {
  let stack = Array::new()
  for idx in (clamped_inputs.length() - 1)>=..0 {
    stack.push(Calculator::Float(clamped_inputs[idx]))
  }
  fn eval(
    op : Calculator,
    stack : Array[Calculator],
  ) -> Unit raise BadFunctionEvaluation {
    match op {
      Calculator::If(body) => {
        let cond = pop_bool(stack)
        if cond {
          for inner in body {
            eval(inner, stack)
          }
        }
      }
      Calculator::IfElse(a, b) => {
        let cond = pop_bool(stack)
        let body = if cond { a } else { b }
        for inner in body {
          eval(inner, stack)
        }
      }
      Calculator::Bool(_) | Calculator::Float(_) | Calculator::Int(_) =>
        stack.push(op)
      Calculator::Abs =>
        match pop_value(stack) {
          Calculator::Float(f) => stack.push(Calculator::Float(f.abs()))
          Calculator::Int(i) => stack.push(Calculator::Int(i.abs()))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Add => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Calculator::Int(x), Calculator::Int(y)) =>
            stack.push(Calculator::Int(x + y))
          (Calculator::Float(x), Calculator::Float(y)) =>
            stack.push(Calculator::Float(x + y))
          (Calculator::Int(x), Calculator::Float(y)) =>
            stack.push(Calculator::Float(x.to_double() + y))
          (Calculator::Float(x), Calculator::Int(y)) =>
            stack.push(Calculator::Float(x + y.to_double()))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      }
      Calculator::Atan => {
        let num = pop_float(stack)
        let den = pop_float(stack)
        stack.push(Calculator::Float(@math.atan2(num, den)))
      }
      Calculator::Ceiling =>
        match pop_value(stack) {
          Calculator::Float(f) => stack.push(Calculator::Float(f.ceil()))
          Calculator::Int(i) => stack.push(Calculator::Int(i))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Cos => {
        let f = pop_float(stack)
        stack.push(Calculator::Float(@math.cos(rad_of_deg(f))))
      }
      Calculator::Cvi =>
        match pop_value(stack) {
          Calculator::Float(f) =>
            stack.push(Calculator::Int(f.floor().to_int()))
          Calculator::Int(i) => stack.push(Calculator::Int(i))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Cvr =>
        match pop_value(stack) {
          Calculator::Int(i) => stack.push(Calculator::Float(i.to_double()))
          Calculator::Float(f) => stack.push(Calculator::Float(f))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Div => {
        let n = pop_float(stack)
        let d = pop_float(stack)
        stack.push(Calculator::Float(n / d))
      }
      Calculator::Exp => {
        let bse = pop_float(stack)
        let exp = pop_float(stack)
        stack.push(Calculator::Float(@math.pow(bse, exp)))
      }
      Calculator::Floor =>
        match pop_value(stack) {
          Calculator::Float(f) =>
            stack.push(Calculator::Int(f.floor().to_int()))
          Calculator::Int(i) => stack.push(Calculator::Int(i))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Idiv => {
        let a = pop_int(stack)
        let b = pop_int(stack)
        stack.push(Calculator::Int(a / b))
      }
      Calculator::Ln => {
        let f = pop_float(stack)
        stack.push(Calculator::Float(@math.ln(f)))
      }
      Calculator::Log => {
        let f = pop_float(stack)
        stack.push(Calculator::Float(@math.log10(f)))
      }
      Calculator::Mod => {
        let a = pop_int(stack)
        let b = pop_int(stack)
        stack.push(Calculator::Int(a % b))
      }
      Calculator::Mul => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Calculator::Int(x), Calculator::Int(y)) =>
            stack.push(Calculator::Int(x * y))
          (Calculator::Float(x), Calculator::Float(y)) =>
            stack.push(Calculator::Float(x * y))
          (Calculator::Int(x), Calculator::Float(y)) =>
            stack.push(Calculator::Float(x.to_double() * y))
          (Calculator::Float(x), Calculator::Int(y)) =>
            stack.push(Calculator::Float(x * y.to_double()))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      }
      Calculator::Neg =>
        match pop_value(stack) {
          Calculator::Float(f) => stack.push(Calculator::Float(-f))
          Calculator::Int(i) => stack.push(Calculator::Int(-i))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Round =>
        match pop_value(stack) {
          Calculator::Float(f) =>
            stack.push(Calculator::Int(f.round().to_int()))
          Calculator::Int(i) => stack.push(Calculator::Int(i))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Sin => {
        let f = pop_float(stack)
        stack.push(Calculator::Float(@math.sin(rad_of_deg(f))))
      }
      Calculator::Sqrt => {
        let f = pop_float(stack)
        stack.push(Calculator::Float(f.sqrt()))
      }
      Calculator::Sub => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Calculator::Int(x), Calculator::Int(y)) =>
            stack.push(Calculator::Int(y - x))
          (Calculator::Float(x), Calculator::Float(y)) =>
            stack.push(Calculator::Float(y - x))
          (Calculator::Int(x), Calculator::Float(y)) =>
            stack.push(Calculator::Float(y - x.to_double()))
          (Calculator::Float(x), Calculator::Int(y)) =>
            stack.push(Calculator::Float(y.to_double() - x))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      }
      Calculator::Truncate =>
        match pop_value(stack) {
          Calculator::Float(f) => stack.push(Calculator::Int(f.to_int()))
          Calculator::Int(i) => stack.push(Calculator::Int(i))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::And => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Calculator::Int(x), Calculator::Int(y)) =>
            stack.push(Calculator::Int(Int::land(x, y)))
          (Calculator::Bool(x), Calculator::Bool(y)) =>
            stack.push(Calculator::Bool(x && y))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      }
      Calculator::Bitshift => {
        let i = pop_int(stack)
        let shift = pop_int(stack)
        let result = if i < 0 {
          i << shift
        } else {
          let u = i.reinterpret_as_uint()
          let shifted = u >> (if shift < 0 { -shift } else { shift })
          shifted.reinterpret_as_int()
        }
        stack.push(Calculator::Int(result))
      }
      Calculator::Eq => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Calculator::Bool(value_equal(a, b)))
      }
      Calculator::Ge => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Calculator::Bool(value_compare(a, b) >= 0))
      }
      Calculator::Gt => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Calculator::Bool(value_compare(a, b) > 0))
      }
      Calculator::Le => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Calculator::Bool(value_compare(a, b) <= 0))
      }
      Calculator::Lt => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Calculator::Bool(value_compare(a, b) < 0))
      }
      Calculator::Ne => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Calculator::Bool(!value_equal(a, b)))
      }
      Calculator::Not =>
        match pop_value(stack) {
          Calculator::Int(i) => stack.push(Calculator::Int(Int::lnot(i)))
          Calculator::Bool(b) => {
            let _ = pop_bool(stack)
            stack.push(Calculator::Bool(!b))
          }
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Or => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Calculator::Int(x), Calculator::Int(y)) =>
            stack.push(Calculator::Int(Int::lor(x, y)))
          (Calculator::Bool(x), Calculator::Bool(y)) =>
            stack.push(Calculator::Bool(x || y))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      }
      Calculator::Xor => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Calculator::Int(x), Calculator::Int(y)) =>
            stack.push(Calculator::Int(Int::lxor(x, y)))
          (Calculator::Bool(x), Calculator::Bool(y)) =>
            stack.push(Calculator::Bool((x || y) && !(x && y)))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      }
      Calculator::Copy =>
        match pop_value(stack) {
          Calculator::Int(i) if i >= 0 => {
            let count = i
            let original_len = stack.length()
            let start = original_len - count
            if start < 0 {
              raise BadFunctionEvaluation::Msg("Type error")
            }
            let slice = stack.sub(start~, end=original_len).to_array()
            for value in slice {
              stack.push(value)
            }
          }
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Exch => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(a)
        stack.push(b)
      }
      Calculator::Pop => {
        let _ = pop_value(stack)

      }
      Calculator::Dup => {
        let a = pop_value(stack)
        stack.push(a)
        stack.push(a)
      }
      Calculator::Index =>
        match pop_value(stack) {
          Calculator::Int(i) if i >= 0 => {
            let idx = stack.length() - 1 - i
            if idx < 0 || idx >= stack.length() {
              raise BadFunctionEvaluation::Msg("Type error")
            }
            stack.push(stack[idx])
          }
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Roll => {
        let j = pop_int(stack)
        let n = pop_int(stack)
        if n < 1 {
          raise BadFunctionEvaluation::Msg("Type error")
        }
        let count = n
        let start = stack.length() - count
        if start < 0 {
          raise BadFunctionEvaluation::Msg("Type error")
        }
        let slice = stack.sub(start~, end=stack.length()).to_array()
        stack.truncate(start)
        let mut rotated = Array::new(capacity=slice.length())
        if j > 0 {
          for k in 0..<slice.length() {
            rotated.push(slice[(k + j) % slice.length()])
          }
        } else if j < 0 {
          let shift = -j
          for k in 0..<slice.length() {
            rotated.push(
              slice[(k + slice.length() - shift % slice.length()) %
              slice.length()],
            )
          }
        } else {
          rotated = slice
        }
        for value in rotated {
          stack.push(value)
        }
      }
    }
  }

  for op in ops {
    eval(op, stack)
  }
  let out = Array::new(capacity=stack.length())
  for i in (stack.length() - 1)>=..0 {
    match stack[i] {
      Calculator::Float(x) => out.push(x)
      Calculator::Int(i) => out.push(i.to_double())
      _ => raise BadFunctionEvaluation::Msg("Type 4-a")
    }
  }
  out
}

///|
/// Evaluate a function on some inputs.
pub fn eval_function(
  fun : PdfFunction,
  inputs : Array[Double],
) -> Array[Double] raise BadFunctionEvaluation {
  let clamped_inputs = clampvals(inputs, fun.domain)
  let outputs = match fun.func {
    PdfFunctionKind::Calculator(ops) =>
      eval_function_calculator(clamped_inputs, ops)
    PdfFunctionKind::Sampled(s) => eval_function_sampled(fun, s, clamped_inputs)
    PdfFunctionKind::Interpolation(i) => {
      let interp = fn(
        n : Double,
        c0 : Array[Double],
        c1 : Array[Double],
        v : Double,
      ) -> Array[Double] {
        map2(c0, c1, (a, b) => a + @math.pow(v, n) * (b - a))
      }
      let mapped = clamped_inputs.map(v => interp(i.n, i.c0, i.c1, v))
      flatten(mapped)
    }
    PdfFunctionKind::Stitching(s) => {
      if clamped_inputs.length() != 1 || fun.domain.length() != 2 {
        raise BadFunctionEvaluation::Msg("stitching: Bad arity")
      }
      let i = clamped_inputs[0]
      let points = concat_arrays(
        [fun.domain[0]],
        concat_arrays(s.bounds, [fun.domain[1]]),
      )
      let mut idx = 0
      let mut subfun : PdfFunction? = None
      while idx + 1 < points.length() {
        let p = points[idx]
        let p2 = points[idx + 1]
        if (i >= p && i < p2) || i == p2 {
          subfun = Some(s.functions[idx])
          break
        }
        idx = idx + 1
      }
      match subfun {
        None => raise BadFunctionEvaluation::Msg("stitching: funs")
        Some(f) => {
          let a = select(idx + 1, points)
          let b = select(idx + 2, points)
          let c = select(idx * 2 + 1, s.stitch_encode)
          let d = select(idx * 2 + 2, s.stitch_encode)
          let encode = (x : Double) => interpolate(x, a, b, c, d)
          eval_function(f, [encode(i)])
        }
      }
    }
  }
  match fun.range {
    None => outputs
    Some(range) => clampvals(outputs, range)
  }
}

///|
fn funtype_of_function(fun : PdfFunction) -> Int {
  match fun.func {
    PdfFunctionKind::Interpolation(_) => 2
    PdfFunctionKind::Stitching(_) => 3
    PdfFunctionKind::Sampled(_) => 0
    PdfFunctionKind::Calculator(_) => 4
  }
}

///|
fn mkreal(x : Double) -> @pdf.PdfObject {
  @pdf.PdfObject::Real(x)
}

///|
fn mkint(x : Int) -> @pdf.PdfObject {
  @pdf.PdfObject::Integer(x)
}

///|
fn max_value_for_bits(bits : Int) -> Int {
  let mut value = 0
  for _ in 0..<bits {
    value = (value << 1) | 1
  }
  value
}

///|
fn write_bits(
  data : @pdfio.MutableBytes,
  bit_pos : Ref[Int],
  bits : Int,
  value : Int,
) -> Unit {
  if bits <= 0 {
    return
  }
  let mut i = bits - 1
  while true {
    let bit = (value >> i) & 1
    if bit == 1 {
      let byte_index = bit_pos.val / 8
      let bit_index = 7 - bit_pos.val % 8
      let existing = @pdfio.bget_unsafe(data, byte_index)
      @pdfio.bset_unsafe(data, byte_index, existing | (1 << bit_index))
    }
    bit_pos.val = bit_pos.val + 1
    if i == 0 {
      break
    }
    i = i - 1
  }
}

///|
fn sampled_bytes(samples : Array[Int], bits : Int) -> @pdfio.MutableBytes {
  if bits <= 0 {
    return @pdfio.mkbytes(0)
  }
  let total_bits = samples.length() * bits
  let byte_len = if total_bits == 0 { 0 } else { (total_bits + 7) / 8 }
  let data = @pdfio.mkbytes(byte_len)
  let bit_pos = Ref::new(0)
  let max_value = max_value_for_bits(bits)
  for sample in samples {
    let clamped = if sample < 0 {
      0
    } else if sample > max_value {
      max_value
    } else {
      sample
    }
    write_bits(data, bit_pos, bits, clamped)
  }
  data
}

///|
fn entries_of_interpolation(
  i : Interpolation,
) -> Array[(String, @pdf.PdfObject)] {
  [
    ("/C0", @pdf.PdfObject::Array(i.c0.map(mkreal))),
    ("/C1", @pdf.PdfObject::Array(i.c1.map(mkreal))),
    ("/N", @pdf.PdfObject::Real(i.n)),
  ]
}

///|
fn entries_of_stitching(
  pdf : @pdf.Pdf,
  s : Stitching,
) -> Array[(String, @pdf.PdfObject)] {
  let numbers = s.functions.map(fun => @pdf.PdfObject::Indirect(
    @pdf.addobj(pdf, pdfobject_of_function(pdf, fun)),
  ))
  [
    ("/Functions", @pdf.PdfObject::Array(numbers)),
    ("/Bounds", @pdf.PdfObject::Array(s.bounds.map(mkreal))),
    ("/Encode", @pdf.PdfObject::Array(s.stitch_encode.map(mkreal))),
  ]
}

///|
fn extra_entries_of_function(
  pdf : @pdf.Pdf,
  fun : PdfFunction,
) -> Array[(String, @pdf.PdfObject)] {
  match fun.func {
    PdfFunctionKind::Interpolation(i) => entries_of_interpolation(i)
    PdfFunctionKind::Stitching(s) => entries_of_stitching(pdf, s)
    PdfFunctionKind::Sampled(_) => []
    PdfFunctionKind::Calculator(_) => []
  }
}

///|
/// Flatten a function to its PDF representation.
pub fn pdfobject_of_function(
  pdf : @pdf.Pdf,
  fun : PdfFunction,
) -> @pdf.PdfObject {
  let domain = @pdf.PdfObject::Array(fun.domain.map(mkreal))
  let range_entry = match fun.range {
    None => []
    Some(values) => [("/Range", @pdf.PdfObject::Array(values.map(mkreal)))]
  }
  let base = [
    ("/FunctionType", @pdf.PdfObject::Integer(funtype_of_function(fun))),
    ("/Domain", domain),
  ]
  match fun.func {
    PdfFunctionKind::Sampled(s) => {
      let encode_vals = if s.encode.length() == 0 {
        interleave_lists(
          many(0.0, s.size.length()),
          s.size.map(x => (x - 1).to_double()),
        )
      } else {
        s.encode
      }
      let decode_vals = if s.decode.length() == 0 {
        match fun.range {
          Some(values) => values
          None => []
        }
      } else {
        s.decode
      }
      let sampled_entries = [
        ("/Size", @pdf.PdfObject::Array(s.size.map(mkint))),
        ("/BitsPerSample", @pdf.PdfObject::Integer(s.bps)),
        ("/Encode", @pdf.PdfObject::Array(encode_vals.map(mkreal))),
      ]
      let sampled_entries = if decode_vals.length() > 0 {
        concat_arrays(sampled_entries, [
          ("/Decode", @pdf.PdfObject::Array(decode_vals.map(mkreal))),
        ])
      } else {
        sampled_entries
      }
      let entries = concat_arrays(
        concat_arrays(base, range_entry),
        sampled_entries,
      )
      let entries_with_order = if s.order != 1 {
        concat_arrays(entries, [("/Order", @pdf.PdfObject::Integer(s.order))])
      } else {
        entries
      }
      let data = sampled_bytes(s.samples, s.bps)
      let entries_with_length = concat_arrays(entries_with_order, [
        ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(data))),
      ])
      @pdf.PdfObject::Stream(
        Ref::new(
          (
            @pdf.PdfObject::Dictionary(entries_with_length),
            @pdf.Stream::Got(data),
          ),
        ),
      )
    }
    PdfFunctionKind::Calculator(ops) => {
      let entries = concat_arrays(base, range_entry)
      let data = @pdfio.bytes_of_string(string_of_calculator(ops))
      let entries_with_length = concat_arrays(entries, [
        ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(data))),
      ])
      @pdf.PdfObject::Stream(
        Ref::new(
          (
            @pdf.PdfObject::Dictionary(entries_with_length),
            @pdf.Stream::Got(data),
          ),
        ),
      )
    }
    _ => {
      let extras = extra_entries_of_function(pdf, fun)
      @pdf.PdfObject::Dictionary(
        concat_arrays(concat_arrays(base, range_entry), extras),
      )
    }
  }
}

///|
fn[T] concat_arrays(a : Array[T], b : Array[T]) -> Array[T] {
  let out = Array::new(capacity=a.length() + b.length())
  for item in a {
    out.push(item)
  }
  for item in b {
    out.push(item)
  }
  out
}
