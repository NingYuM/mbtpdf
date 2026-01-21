///|
fn[A] invalid_arg(name : String) -> A raise {
  fail("Invalid_argument: \{name}")
}

///|
fn check_len2(name : String, len_a : Int, len_b : Int) -> Unit raise {
  if len_a != len_b {
    invalid_arg(name)
  }
}

///|
fn check_len3(
  name : String,
  len_a : Int,
  len_b : Int,
  len_c : Int,
) -> Unit raise {
  if len_a != len_b || len_a != len_c {
    invalid_arg(name)
  }
}

///|
fn check_len4(
  name : String,
  len_a : Int,
  len_b : Int,
  len_c : Int,
  len_d : Int,
) -> Unit raise {
  if len_a != len_b || len_a != len_c || len_a != len_d {
    invalid_arg(name)
  }
}

///|
fn check_len5(
  name : String,
  len_a : Int,
  len_b : Int,
  len_c : Int,
  len_d : Int,
  len_e : Int,
) -> Unit raise {
  if len_a != len_b || len_a != len_c || len_a != len_d || len_a != len_e {
    invalid_arg(name)
  }
}

///|
fn check_len6(
  name : String,
  len_a : Int,
  len_b : Int,
  len_c : Int,
  len_d : Int,
  len_e : Int,
  len_f : Int,
) -> Unit raise {
  if len_a != len_b ||
    len_a != len_c ||
    len_a != len_d ||
    len_a != len_e ||
    len_a != len_f {
    invalid_arg(name)
  }
}

///|
fn[A : Compare] compare_values(left : A, right : A) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
pub fn[A] hd(xs : Array[A]) -> A raise {
  if xs.is_empty() {
    invalid_arg("Pdfutil.hd")
  }
  xs[0]
}

///|
pub fn[A] tl(xs : Array[A]) -> Array[A] raise {
  if xs.is_empty() {
    invalid_arg("Pdfutil.tl")
  }
  xs.sub(start=1).to_array()
}

///|
pub fn[A] rev(xs : Array[A]) -> Array[A] {
  xs.rev()
}

///|
pub fn[A] iter(f : (A) -> Unit raise?, xs : Array[A]) -> Unit raise? {
  for item in xs {
    f(item)
  }
}

///|
pub fn[A, B] iter2(
  f : (A, B) -> Unit raise?,
  xs : Array[A],
  ys : Array[B],
) -> Unit raise {
  let len = xs.length()
  check_len2("Pdfutil.iter2", len, ys.length())
  for i in 0..<len {
    f(xs[i], ys[i])
  }
}

///|
pub fn[A, B, C] iter3(
  f : (A, B, C) -> Unit raise?,
  xs : Array[A],
  ys : Array[B],
  zs : Array[C],
) -> Unit raise {
  let len = xs.length()
  check_len3("Pdfutil.iter3", len, ys.length(), zs.length())
  for i in 0..<len {
    f(xs[i], ys[i], zs[i])
  }
}

///|
pub fn[A] append(left : Array[A], right : Array[A]) -> Array[A] {
  let out : Array[A] = Array::new(capacity=left.length() + right.length())
  for item in left {
    out.push(item)
  }
  for item in right {
    out.push(item)
  }
  out
}

///|
pub fn[A] flatten(xs : Array[Array[A]]) -> Array[A] {
  xs.flatten()
}

///|
pub fn[A, B] rev_map(f : (A) -> B raise?, xs : Array[A]) -> Array[B] raise? {
  xs.map(f).rev()
}

///|
pub fn[A, B] map(f : (A) -> B raise?, xs : Array[A]) -> Array[B] raise? {
  xs.map(f)
}

///|
pub fn[A, B, C] map2(
  f : (A, B) -> C raise?,
  xs : Array[A],
  ys : Array[B],
) -> Array[C] raise {
  let len = xs.length()
  check_len2("Pdfutil.map2", len, ys.length())
  let out : Array[C] = Array::new(capacity=len)
  for i in 0..<len {
    out.push(f(xs[i], ys[i]))
  }
  out
}

///|
pub fn[A, B] split(pairs : Array[(A, B)]) -> (Array[A], Array[B]) {
  let left : Array[A] = Array::new(capacity=pairs.length())
  let right : Array[B] = Array::new(capacity=pairs.length())
  for pair in pairs {
    left.push(pair.0)
    right.push(pair.1)
  }
  (left, right)
}

///|
pub fn[A, B, C] split3(
  triples : Array[(A, B, C)],
) -> (Array[A], Array[B], Array[C]) {
  let a : Array[A] = Array::new(capacity=triples.length())
  let b : Array[B] = Array::new(capacity=triples.length())
  let c : Array[C] = Array::new(capacity=triples.length())
  for triple in triples {
    a.push(triple.0)
    b.push(triple.1)
    c.push(triple.2)
  }
  (a, b, c)
}

///|
pub fn[A, B, C, D, E] split5(
  tuples : Array[(A, B, C, D, E)],
) -> (Array[A], Array[B], Array[C], Array[D], Array[E]) {
  let a : Array[A] = Array::new(capacity=tuples.length())
  let b : Array[B] = Array::new(capacity=tuples.length())
  let c : Array[C] = Array::new(capacity=tuples.length())
  let d : Array[D] = Array::new(capacity=tuples.length())
  let e : Array[E] = Array::new(capacity=tuples.length())
  for tuple in tuples {
    a.push(tuple.0)
    b.push(tuple.1)
    c.push(tuple.2)
    d.push(tuple.3)
    e.push(tuple.4)
  }
  (a, b, c, d, e)
}

///|
pub fn[A, B, C, D, E, F] split6(
  tuples : Array[(A, B, C, D, E, F)],
) -> (Array[A], Array[B], Array[C], Array[D], Array[E], Array[F]) {
  let a : Array[A] = Array::new(capacity=tuples.length())
  let b : Array[B] = Array::new(capacity=tuples.length())
  let c : Array[C] = Array::new(capacity=tuples.length())
  let d : Array[D] = Array::new(capacity=tuples.length())
  let e : Array[E] = Array::new(capacity=tuples.length())
  let f : Array[F] = Array::new(capacity=tuples.length())
  for tuple in tuples {
    a.push(tuple.0)
    b.push(tuple.1)
    c.push(tuple.2)
    d.push(tuple.3)
    e.push(tuple.4)
    f.push(tuple.5)
  }
  (a, b, c, d, e, f)
}

///|
pub fn[A, B, C, D, E, F, G, H] split8(
  tuples : Array[(A, B, C, D, E, F, G, H)],
) -> (
  Array[A],
  Array[B],
  Array[C],
  Array[D],
  Array[E],
  Array[F],
  Array[G],
  Array[H],
) {
  let a : Array[A] = Array::new(capacity=tuples.length())
  let b : Array[B] = Array::new(capacity=tuples.length())
  let c : Array[C] = Array::new(capacity=tuples.length())
  let d : Array[D] = Array::new(capacity=tuples.length())
  let e : Array[E] = Array::new(capacity=tuples.length())
  let f : Array[F] = Array::new(capacity=tuples.length())
  let g : Array[G] = Array::new(capacity=tuples.length())
  let h : Array[H] = Array::new(capacity=tuples.length())
  for tuple in tuples {
    a.push(tuple.0)
    b.push(tuple.1)
    c.push(tuple.2)
    d.push(tuple.3)
    e.push(tuple.4)
    f.push(tuple.5)
    g.push(tuple.6)
    h.push(tuple.7)
  }
  (a, b, c, d, e, f, g, h)
}

///|
pub fn[A, B] combine(xs : Array[A], ys : Array[B]) -> Array[(A, B)] raise {
  let len = xs.length()
  check_len2("Pdfutil.combine", len, ys.length())
  let out : Array[(A, B)] = Array::new(capacity=len)
  for i in 0..<len {
    out.push((xs[i], ys[i]))
  }
  out
}

///|
pub fn[A, B, C] combine3(
  xs : Array[A],
  ys : Array[B],
  zs : Array[C],
) -> Array[(A, B, C)] raise {
  let len = xs.length()
  check_len3("Pdfutil.combine3", len, ys.length(), zs.length())
  let out : Array[(A, B, C)] = Array::new(capacity=len)
  for i in 0..<len {
    out.push((xs[i], ys[i], zs[i]))
  }
  out
}

///|
pub fn[A, B] fold_left(
  f : (B, A) -> B raise?,
  init : B,
  xs : Array[A],
) -> B raise? {
  xs.fold(init~, f)
}

///|
pub fn[A, B] fold_right(
  f : (A, B) -> B raise?,
  xs : Array[A],
  init : B,
) -> B raise? {
  xs.rev().fold(init~, (acc, item) => f(item, acc))
}

///|
pub fn[A] length(xs : Array[A]) -> Int {
  xs.length()
}

///|
pub fn[A] sort(cmp : (A, A) -> Int, xs : Array[A]) -> Array[A] {
  let out = xs.copy()
  out.sort_by(cmp)
  out
}

///|
pub fn sum(xs : Array[Int]) -> Int {
  xs.fold(init=0, (acc, value) => acc + value)
}

///|
pub fn fsum(xs : Array[Double]) -> Double {
  xs.fold(init=0.0, (acc, value) => acc + value)
}

///|
pub fn cumulative_sum(base : Int, xs : Array[Int]) -> Array[Int] {
  let out : Array[Int] = Array::new(capacity=xs.length())
  let mut total = base
  for value in xs {
    total = total + value
    out.push(total)
  }
  out
}

///|
pub fn[A] lcount(p : (A) -> Bool raise?, xs : Array[A]) -> Int raise? {
  let mut count = 0
  for value in xs {
    if p(value) {
      count += 1
    }
  }
  count
}

///|
pub fn[A] losenones(values : Array[A?]) -> Array[A] {
  let out : Array[A] = Array::new(capacity=values.length())
  for value in values {
    match value {
      Some(v) => out.push(v)
      None => ()
    }
  }
  out
}

///|
pub fn[A, B] option_map(f : (A) -> B? raise?, xs : Array[A]) -> Array[B] raise? {
  let out : Array[B] = Array::new(capacity=xs.length())
  for value in xs {
    match f(value) {
      Some(v) => out.push(v)
      None => ()
    }
  }
  out
}

///|
pub fn[A, B, C] option_map2(
  f : (A, B) -> C? raise?,
  xs : Array[A],
  ys : Array[B],
) -> Array[C] raise {
  let len = xs.length()
  check_len2("Pdfutil.option_map2", len, ys.length())
  let out : Array[C] = Array::new(capacity=len)
  for i in 0..<len {
    match f(xs[i], ys[i]) {
      Some(v) => out.push(v)
      None => ()
    }
  }
  out
}

///|
pub fn[A : Eq] mem(value : A, xs : Array[A]) -> Bool {
  xs.contains(value)
}

///|
pub fn[A : Eq] position(value : A, xs : Array[A]) -> Int? {
  for i, item in xs {
    if item == value {
      return Some(i)
    }
  }
  None
}

///|
pub fn[A : Eq] position_1(value : A, xs : Array[A]) -> Int? {
  for i, item in xs {
    if item == value {
      return Some(i + 1)
    }
  }
  None
}

///|
pub fn[A, B, C, D] rev_map3(
  f : (A, B, C) -> D raise?,
  xs : Array[A],
  ys : Array[B],
  zs : Array[C],
) -> Array[D] raise {
  let len = xs.length()
  check_len3("Pdfutil.rev_map3", len, ys.length(), zs.length())
  let out : Array[D] = Array::new(capacity=len)
  for i in 0..<len {
    out.push(f(xs[i], ys[i], zs[i]))
  }
  out.rev()
}

///|
pub fn[A, B, C, D] map3(
  f : (A, B, C) -> D raise?,
  xs : Array[A],
  ys : Array[B],
  zs : Array[C],
) -> Array[D] raise {
  rev_map3(f, xs, ys, zs).rev()
}

///|
pub fn[A, B, C, D, E] rev_map4(
  f : (A, B, C, D) -> E raise?,
  xs : Array[A],
  ys : Array[B],
  zs : Array[C],
  ws : Array[D],
) -> Array[E] raise {
  let len = xs.length()
  check_len4("Pdfutil.rev_map4", len, ys.length(), zs.length(), ws.length())
  let out : Array[E] = Array::new(capacity=len)
  for i in 0..<len {
    out.push(f(xs[i], ys[i], zs[i], ws[i]))
  }
  out.rev()
}

///|
pub fn[A, B, C, D, E] map4(
  f : (A, B, C, D) -> E raise?,
  xs : Array[A],
  ys : Array[B],
  zs : Array[C],
  ws : Array[D],
) -> Array[E] raise {
  rev_map4(f, xs, ys, zs, ws).rev()
}

///|
pub fn[A, B, C, D, E, F] rev_map5(
  f : (A, B, C, D, E) -> F raise?,
  xs : Array[A],
  ys : Array[B],
  zs : Array[C],
  ws : Array[D],
  vs : Array[E],
) -> Array[F] raise {
  let len = xs.length()
  check_len5(
    "Pdfutil.rev_map5",
    len,
    ys.length(),
    zs.length(),
    ws.length(),
    vs.length(),
  )
  let out : Array[F] = Array::new(capacity=len)
  for i in 0..<len {
    out.push(f(xs[i], ys[i], zs[i], ws[i], vs[i]))
  }
  out.rev()
}

///|
pub fn[A, B, C, D, E, F] map5(
  f : (A, B, C, D, E) -> F raise?,
  xs : Array[A],
  ys : Array[B],
  zs : Array[C],
  ws : Array[D],
  vs : Array[E],
) -> Array[F] raise {
  rev_map5(f, xs, ys, zs, ws, vs).rev()
}

///|
pub fn[A, B, C, D, E, F, G] rev_map6(
  f : (A, B, C, D, E, F) -> G raise?,
  xs : Array[A],
  ys : Array[B],
  zs : Array[C],
  ws : Array[D],
  vs : Array[E],
  us : Array[F],
) -> Array[G] raise {
  let len = xs.length()
  check_len6(
    "Pdfutil.rev_map6",
    len,
    ys.length(),
    zs.length(),
    ws.length(),
    vs.length(),
    us.length(),
  )
  let out : Array[G] = Array::new(capacity=len)
  for i in 0..<len {
    out.push(f(xs[i], ys[i], zs[i], ws[i], vs[i], us[i]))
  }
  out.rev()
}

///|
pub fn[A, B, C, D, E, F, G] map6(
  f : (A, B, C, D, E, F) -> G raise?,
  xs : Array[A],
  ys : Array[B],
  zs : Array[C],
  ws : Array[D],
  vs : Array[E],
  us : Array[F],
) -> Array[G] raise {
  rev_map6(f, xs, ys, zs, ws, vs, us).rev()
}

///|
pub fn[A] take(xs : Array[A], n : Int) -> Array[A] raise {
  let len = xs.length()
  if n < 0 || n > len {
    invalid_arg("Pdfutil.take")
  }
  xs.sub(end=n).to_array()
}

///|
pub fn[A] take_swapped(n : Int, xs : Array[A]) -> Array[A] raise {
  take(xs, n)
}

///|
pub fn[A] drop(xs : Array[A], n : Int) -> Array[A] raise {
  let len = xs.length()
  if n < 0 || n > len {
    invalid_arg("Pdfutil.drop")
  }
  xs.sub(start=n).to_array()
}

///|
pub fn[A] drop_swapped(n : Int, xs : Array[A]) -> Array[A] raise {
  drop(xs, n)
}

///|
pub fn[A] takewhile(p : (A) -> Bool raise?, xs : Array[A]) -> Array[A] raise? {
  let out : Array[A] = Array::new()
  let mut i = 0
  while i < xs.length() && p(xs[i]) {
    out.push(xs[i])
    i += 1
  }
  out
}

///|
pub fn[A] takewhile_reverse(
  p : (A) -> Bool raise?,
  xs : Array[A],
) -> Array[A] raise? {
  takewhile(p, xs).rev()
}

///|
pub fn[A] dropwhile(p : (A) -> Bool raise?, xs : Array[A]) -> Array[A] raise? {
  let mut i = 0
  while i < xs.length() && p(xs[i]) {
    i += 1
  }
  xs.sub(start=i).to_array()
}

///|
pub fn[A] cleave(xs : Array[A], n : Int) -> (Array[A], Array[A]) raise {
  let len = xs.length()
  if n < 0 {
    invalid_arg("Pdfutil.cleave: negative argument")
  }
  if n > len {
    invalid_arg("Pdfutil.cleave: not enough elements")
  }
  (xs.sub(end=n).to_array(), xs.sub(start=n).to_array())
}

///|
pub fn[A] cleavewhile(
  p : (A) -> Bool raise?,
  xs : Array[A],
) -> (Array[A], Array[A]) raise? {
  let mut i = 0
  while i < xs.length() && p(xs[i]) {
    i += 1
  }
  (xs.sub(end=i).to_array(), xs.sub(start=i).to_array())
}

///|
pub fn[A] cleavewhile_unordered(
  p : (A) -> Bool raise?,
  xs : Array[A],
) -> (Array[A], Array[A]) raise? {
  cleavewhile(p, xs)
}

///|
pub fn[A] isolate(
  p : (A) -> Bool raise?,
  p_prime : (A) -> Bool raise?,
  xs : Array[A],
) -> Array[A] raise? {
  let (_, during_and_after) = cleavewhile(value => !p(value), xs)
  if during_and_after.is_empty() {
    return Array::new()
  }
  let after = during_and_after.sub(start=1).to_array()
  let (middle, _) = cleavewhile(value => !p_prime(value), after)
  middle
}

///|
pub fn[A] interleave(element : A, xs : Array[A]) -> Array[A] {
  let len = xs.length()
  if len <= 1 {
    return xs.copy()
  }
  let out : Array[A] = Array::new(capacity=len * 2 - 1)
  out.push(xs[0])
  for i in 1..<len {
    out.push(element)
    out.push(xs[i])
  }
  out
}

///|
pub fn[A] interleave_lists(xs : Array[A], ys : Array[A]) -> Array[A] raise {
  let len = xs.length()
  check_len2("Pdfutil.interleave_lists", len, ys.length())
  let out : Array[A] = Array::new(capacity=len * 2)
  for i in 0..<len {
    out.push(xs[i])
    out.push(ys[i])
  }
  out
}

///|
pub fn[A] collate(cmp : (A, A) -> Int, xs : Array[A]) -> Array[Array[A]] {
  let out : Array[Array[A]] = Array::new()
  let mut i = 0
  let len = xs.length()
  while i < len {
    let base = xs[i]
    let group : Array[A] = Array::new()
    group.push(base)
    i += 1
    while i < len && cmp(base, xs[i]) == 0 {
      group.push(xs[i])
      i += 1
    }
    out.push(group)
  }
  out
}

///|
pub fn[A, B] map_lol(
  f : (A) -> B raise?,
  lists : Array[Array[A]],
) -> Array[Array[B]] raise? {
  lists.map(inner => inner.map(f))
}

///|
pub fn[A, B] conspair(
  pair_and_rest : ((A, B), (Array[A], Array[B])),
) -> (Array[A], Array[B]) {
  let (pair, rest) = pair_and_rest
  let (x, y) = pair
  let (xs, ys) = rest
  let xs_out : Array[A] = Array::new(capacity=xs.length() + 1)
  xs_out.push(x)
  for item in xs {
    xs_out.push(item)
  }
  let ys_out : Array[B] = Array::new(capacity=ys.length() + 1)
  ys_out.push(y)
  for item in ys {
    ys_out.push(item)
  }
  (xs_out, ys_out)
}

///|
pub fn[A, B] conspairopt(
  pair_and_rest : ((A?, B?), (Array[A], Array[B])),
) -> (Array[A], Array[B]) {
  let (pair, rest) = pair_and_rest
  let (xo, yo) = pair
  let (xs, ys) = rest
  let xextra = if xo is Some(_) { 1 } else { 0 }
  let yextra = if yo is Some(_) { 1 } else { 0 }
  let xs_out : Array[A] = Array::new(capacity=xs.length() + xextra)
  let ys_out : Array[B] = Array::new(capacity=ys.length() + yextra)
  match xo {
    Some(x) => xs_out.push(x)
    None => ()
  }
  for item in xs {
    xs_out.push(item)
  }
  match yo {
    Some(y) => ys_out.push(y)
    None => ()
  }
  for item in ys {
    ys_out.push(item)
  }
  (xs_out, ys_out)
}

///|
pub fn[A] pairs_of_list(xs : Array[A]) -> Array[(A, A)] raise {
  let len = xs.length()
  if len % 2 != 0 {
    invalid_arg("Pdfutil.pairs_of_list")
  }
  let out : Array[(A, A)] = Array::new(capacity=len / 2)
  for i = 0; i + 1 < len; i = i + 2 {
    out.push((xs[i], xs[i + 1]))
  }
  out
}

///|
pub fn[A] pairs(xs : Array[A]) -> Array[(A, A)] {
  let len = xs.length()
  if len < 2 {
    return Array::new()
  }
  let out : Array[(A, A)] = Array::new(capacity=len - 1)
  for i in 0..<(len - 1) {
    out.push((xs[i], xs[i + 1]))
  }
  out
}

///|
pub fn[A : Eq] mem_swapped(xs : Array[A], value : A) -> Bool {
  mem(value, xs)
}

///|
pub fn[A : Compare] setify(xs : Array[A]) -> Array[A] {
  if xs.is_empty() {
    return Array::new()
  }
  let sorted = sort(compare_values, xs)
  let out : Array[A] = Array::new(capacity=sorted.length())
  let mut current = sorted[0]
  out.push(current)
  for i in 1..<sorted.length() {
    let value = sorted[i]
    if compare_values(value, current) != 0 {
      out.push(value)
      current = value
    }
  }
  out
}

///|
pub fn[A : Eq] setify_preserving_order(xs : Array[A]) -> Array[A] {
  let out : Array[A] = Array::new()
  for value in xs {
    if !out.contains(value) {
      out.push(value)
    }
  }
  out
}

///|
pub fn[A : Hash + Eq] setify_large(xs : Array[A]) -> Array[A] {
  let seen : Map[A, Unit] = Map::new(capacity=xs.length())
  for value in xs {
    seen.set(value, ())
  }
  let out : Array[A] = Array::new(capacity=seen.length())
  for key, _ in seen {
    out.push(key)
  }
  out
}

///|
pub fn[A : Eq] setminus(xs : Array[A], ys : Array[A]) -> Array[A] {
  let out : Array[A] = Array::new(capacity=xs.length())
  for value in xs {
    if !mem(value, ys) {
      out.push(value)
    }
  }
  out.rev()
}

///|
pub fn[A : Eq] setminus_preserving_order(
  xs : Array[A],
  ys : Array[A],
) -> Array[A] {
  setminus(xs, ys).rev()
}

///|
pub fn[A] heads(xss : Array[Array[A]]) -> Array[A] raise {
  let out : Array[A] = Array::new(capacity=xss.length())
  for xs in xss {
    out.push(hd(xs))
  }
  out
}

///|
pub fn[A] tails(xss : Array[Array[A]]) -> Array[Array[A]] raise {
  let out : Array[Array[A]] = Array::new(capacity=xss.length())
  for xs in xss {
    out.push(tl(xs))
  }
  out
}

///|
pub fn[A] zipn(xss : Array[Array[A]]) -> Array[Array[A]] raise {
  let out : Array[Array[A]] = Array::new()
  let mut current = xss
  while !current.is_empty() {
    let mut any_empty = false
    for xs in current {
      if xs.is_empty() {
        any_empty = true
      }
    }
    if any_empty {
      break
    }
    out.push(heads(current))
    current = tails(current)
  }
  out
}

///|
pub fn[A, B] couple(f : (A, A) -> B raise?, xs : Array[A]) -> Array[B] raise? {
  let len = xs.length()
  if len < 2 {
    return Array::new()
  }
  let out : Array[B] = Array::new(capacity=len - 1)
  for i in 0..<(len - 1) {
    out.push(f(xs[i], xs[i + 1]))
  }
  out
}

///|
pub fn[A, B] couple_ext(
  f : (A, A) -> B raise?,
  g : (A) -> B raise?,
  xs : Array[A],
) -> Array[B] raise? {
  let len = xs.length()
  let out : Array[B] = Array::new(capacity=len)
  for i in 0..<(if len > 0 { len - 1 } else { 0 }) {
    out.push(f(xs[i], xs[i + 1]))
  }
  if len % 2 == 1 {
    out.push(g(xs[len - 1]))
  }
  out
}

///|
pub fn[A] couple_reduce(f : (A, A) -> A raise?, xs : Array[A]) -> A raise {
  if xs.is_empty() {
    invalid_arg("Pdfutil.couple_reduce")
  }
  let mut current = xs
  while current.length() > 1 {
    current = couple(f, current)
  }
  current[0]
}

///|
pub fn[A] pair(f : (A, A) -> A raise?, xs : Array[A]) -> Array[A] raise? {
  let len = xs.length()
  let out : Array[A] = Array::new(capacity=(len + 1) / 2)
  let mut i = 0
  while i < len {
    if i + 1 < len {
      out.push(f(xs[i], xs[i + 1]))
      i += 2
    } else {
      out.push(xs[i])
      i += 1
    }
  }
  out
}

///|
pub fn[A, B] pair_ext(
  f : (A, A) -> B raise?,
  g : (A) -> B raise?,
  xs : Array[A],
) -> Array[B] raise? {
  let len = xs.length()
  let out : Array[B] = Array::new(capacity=(len + 1) / 2)
  let mut i = 0
  while i < len {
    if i + 1 < len {
      out.push(f(xs[i], xs[i + 1]))
      i += 2
    } else {
      out.push(g(xs[i]))
      i += 1
    }
  }
  out
}

///|
pub fn[A] pair_reduce(f : (A, A) -> A raise?, xs : Array[A]) -> A raise {
  if xs.is_empty() {
    invalid_arg("Pdfutil.pair_reduce")
  }
  let mut current = xs
  while current.length() > 1 {
    current = pair(f, current)
  }
  current[0]
}

///|
pub fn[A] keep(p : (A) -> Bool raise?, xs : Array[A]) -> Array[A] raise? {
  xs.filter(p)
}

///|
pub fn[A] lose(p : (A) -> Bool raise?, xs : Array[A]) -> Array[A] raise? {
  xs.filter(value => !p(value))
}

///|
pub fn[A] many(value : A, n : Int) -> Array[A] raise {
  if n < 0 {
    invalid_arg("Pdfutil.many")
  }
  Array::make(n, value)
}

///|
pub fn[A] manyunique(f : () -> A raise?, n : Int) -> Array[A] raise {
  if n < 0 {
    invalid_arg("Pdfutil.manyunique")
  }
  let out : Array[A] = Array::new(capacity=n)
  for _ in 0..<n {
    out.push(f())
  }
  out
}

///|
pub fn[A] splitinto(n : Int, xs : Array[A]) -> Array[Array[A]] raise {
  if n <= 0 {
    invalid_arg("Pdfutil.splitinto")
  }
  let out : Array[Array[A]] = Array::new()
  let len = xs.length()
  let mut idx = 0
  while idx < len {
    let end = if idx + n > len { len } else { idx + n }
    out.push(xs.sub(start=idx, end~).to_array())
    idx = end
  }
  out
}

///|
pub fn[A] splitinto_small(n : Int, xs : Array[A]) -> Array[Array[A]] raise {
  splitinto(n, xs)
}

///|
pub fn[A] splitat(points : Array[Int], xs : Array[A]) -> Array[Array[A]] raise {
  let out : Array[Array[A]] = Array::new()
  let mut start = 0
  let mut prev = 0
  let len = xs.length()
  for point in points {
    let count = point - prev
    if count < 0 || start + count > len {
      invalid_arg("Pdfutil.splitat")
    }
    out.push(xs.sub(start~, end=start + count).to_array())
    start += count
    prev = point
  }
  if start < len {
    out.push(xs.sub(start~).to_array())
  }
  out
}

///|
pub fn[A] select(n : Int, xs : Array[A]) -> A raise {
  if n <= 0 || n > xs.length() {
    invalid_arg("Pdfutil.select")
  }
  xs[n - 1]
}

///|
pub fn[A] replace_number(n : Int, value : A, xs : Array[A]) -> Array[A] {
  let len = xs.length()
  if n <= 0 || n > len {
    return xs.copy()
  }
  let out = xs.copy()
  out[n - 1] = value
  out
}

///|
pub fn[A] isnull(xs : Array[A]) -> Bool {
  xs.is_empty()
}

///|
pub fn[A] notnull(xs : Array[A]) -> Bool {
  !xs.is_empty()
}

///|
pub fn[A] last(xs : Array[A]) -> A raise {
  match xs.last() {
    Some(value) => value
    None => invalid_arg("Pdfutil.last")
  }
}

///|
pub fn[A] all_but_last(xs : Array[A]) -> Array[A] {
  let len = xs.length()
  if len <= 1 {
    Array::new()
  } else {
    xs.sub(end=len - 1).to_array()
  }
}

///|
pub fn[A] extremes(xs : Array[A]) -> (A, A) raise {
  let len = xs.length()
  if len == 0 {
    invalid_arg("Pdfutil.extremes")
  }
  if len == 1 {
    let value = xs[0]
    return (value, value)
  }
  (xs[0], xs[len - 1])
}

///|
pub fn[A] extremes_and_middle(xs : Array[A]) -> (A, Array[A], A) raise {
  let len = xs.length()
  if len < 2 {
    invalid_arg("Pdfutil.extremes_and_middle")
  }
  let middle = if len == 2 {
    Array::new()
  } else {
    xs.sub(start=1, end=len - 1).to_array()
  }
  (xs[0], middle, xs[len - 1])
}

///|
pub fn ilist(start : Int, finish : Int) -> Array[Int] raise {
  if finish < start {
    invalid_arg("Pdfutil.ilist")
  }
  if start == finish {
    return [start]
  }
  let out : Array[Int] = Array::new(capacity=finish - start + 1)
  for i in start..<=finish {
    out.push(i)
  }
  out
}

///|
pub fn ilist_null(start : Int, finish : Int) -> Array[Int] raise {
  if finish < start {
    invalid_arg("Pdfutil.ilist_null")
  }
  if start == finish {
    return Array::new()
  }
  ilist(start, finish)
}

///|
pub fn ilist_fail_null(start : Int, finish : Int) -> Array[Int] {
  if finish < start {
    return Array::new()
  }
  if start == finish {
    return Array::new()
  }
  let out : Array[Int] = Array::new(capacity=finish - start + 1)
  for i in start..<=finish {
    out.push(i)
  }
  out
}

///|
pub fn[A] indx(xs : Array[A]) -> Array[Int] {
  indxn(1, xs)
}

///|
pub fn[A] indx0(xs : Array[A]) -> Array[Int] {
  indxn(0, xs)
}

///|
pub fn[A] indxn(base : Int, xs : Array[A]) -> Array[Int] {
  let out : Array[Int] = Array::new(capacity=xs.length())
  for i in 0..<xs.length() {
    out.push(base + i)
  }
  out
}

///|
pub fn[A] drop_evens(xs : Array[A]) -> Array[A] {
  let len = xs.length()
  let out : Array[A] = Array::new(capacity=len)
  for i in 0..<len {
    if i % 2 == 0 || (i == len - 1 && len % 2 == 0) {
      out.push(xs[i])
    }
  }
  out
}

///|
pub fn[A] really_drop_evens(xs : Array[A]) -> Array[A] {
  let len = xs.length()
  let out : Array[A] = Array::new(capacity=len)
  for i in 0..<len {
    if i % 2 == 0 {
      out.push(xs[i])
    }
  }
  out
}

///|
pub fn[A] drop_odds(xs : Array[A]) -> Array[A] {
  let len = xs.length()
  let out : Array[A] = Array::new(capacity=len / 2)
  for i in 0..<len {
    if i % 2 == 1 {
      out.push(xs[i])
    }
  }
  out
}

///|
pub fn[A] tail_no_fail(xs : Array[A]) -> Array[A] {
  if xs.is_empty() {
    Array::new()
  } else {
    xs.sub(start=1).to_array()
  }
}

///|
pub fn[A] append_rev(left : Array[A], right : Array[A]) -> Array[A] {
  append(right, left)
}

///|
pub fn[A] replaceinlist(
  p : (A) -> Bool raise?,
  value : A,
  xs : Array[A],
) -> Array[A] raise? {
  xs.map(item => if p(item) { value } else { item })
}

///|
pub fn[A] index(p : (A) -> Bool raise?, xs : Array[A]) -> Int raise {
  let mut i = 1
  for item in xs {
    if p(item) {
      return i
    }
    i += 1
  }
  fail("Not_found")
}

///|
pub fn[A] split_around(
  p : (A) -> Bool raise?,
  xs : Array[A],
) -> Array[Array[A]] raise? {
  let out : Array[Array[A]] = Array::new()
  let mut current : Array[A] = Array::new()
  for item in xs {
    if p(item) {
      out.push(current)
      current = Array::new()
    } else {
      current.push(item)
    }
  }
  if !current.is_empty() {
    out.push(current)
  }
  out
}
