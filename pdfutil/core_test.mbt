///|
test "arrays and assoc helpers" {
  let xs = [1, 2, 3]
  set_array(xs, 9)
  assert_eq(xs, [9, 9, 9])
  let swapped = [1, 2, 3]
  swap(swapped, 0, 2)
  assert_eq(swapped, [3, 2, 1])
  let sum = Ref::new(0)
  array_iter2((a, b) => sum.val = sum.val + a + b, [1, 2], [3, 4])
  assert_eq(sum.val, 10)
  assert_eq(array_map2((a, b) => a + b, [1, 2], [3, 4]), [4, 6])
  assert_is_err(try? array_iter2((_, _) => (), [1], [1, 2]))
  assert_is_err(try? array_map2((a, b) => a + b, [1], [1, 2]))
  let dict : Array[(String, Int)] = [("a", 1), ("b", 2)]
  assert_eq(lookup("a", dict), Some(1))
  assert_eq(lookup("c", dict), None)
  assert_eq(lookup_failnull("b", dict), 2)
  assert_is_err(try? lookup_failnull("z", dict))
  assert_eq(add("b", 5, dict), [("a", 1), ("b", 5)])
  assert_eq(add("c", 3, dict), [("a", 1), ("b", 2), ("c", 3)])
  assert_eq(replace("b", 9, dict), [("a", 1), ("b", 9)])
  assert_is_err(try? replace("c", 9, dict))
  assert_eq(remove("a", dict), [("b", 2)])
  assert_eq(mergedict([("a", 1)], [("a", 2), ("b", 3)]), [("a", 2), ("b", 3)])
}

///|
test "options and strings helpers" {
  assert_true(some(Some(1)))
  assert_true(none((None : Int?)))
  assert_eq(unopt(Some("ok")), "ok")
  assert_is_err(try? unopt((None : String?)))
  assert_eq(firstchar("abc"), Some('a'))
  assert_eq(lastchar("abc"), Some('c'))
  assert_eq(explode("ab"), ['a', 'b'])
  assert_eq(implode(['x', 'y']), "xy")
  assert_eq(string_of_char('z'), "z")
  assert_eq(string_replace_all("aba", "X", "abaaba"), "XX")
  assert_eq(string_replace_all("", "X", "aba"), "aba")
  let counter = Ref::new(0)
  let replaced = string_replace_all_lazy(
    "a",
    () => {
      counter.val = counter.val + 1
      "Z"
    },
    "aba",
  )
  assert_eq(replaced, "ZbZ")
  assert_eq(counter.val, 2)
  assert_eq(string_replace_all_lazy("", () => "Z", "aba"), "aba")
  assert_true(starts_with("prefix-suffix", "prefix"))
  assert_eq(roman(0), "")
  assert_eq(roman(1984), "MCMLXXXIV")
  assert_eq(roman_upper(4), "IV")
  assert_eq(roman_lower(9), "ix")
}

///|
test "functional helpers, refs, and memoize" {
  let is_even = notpred((value : Int) => value % 2 == 1)
  assert_true(is_even(2))
  assert_true(eq(1, 1))
  assert_true(neq(1, 2))
  assert_eq(rev_compare(1, 2), 1)
  assert_eq(rev_compare(2, 1), -1)
  assert_eq(rev_compare(2, 2), 0)
  assert_true(bool_xor(true, false))
  assert_eq(ident("x"), "x")
  assert_true(always(0))
  assert_true(!never(0))
  assert_eq(applyn(value => value + 1, 3, 0), 3)
  assert_eq(tuple("a", 1), ("a", 1))
  let unit_fn = mkunit((value : Int) => value * 2, 5)
  assert_eq(unit_fn(), 10)
  let called = Ref::new(0)
  let result = do_return(
    () => {
      called.val = called.val + 1
      42
    },
    () => called.val = called.val + 10,
  )
  assert_eq(result, 42)
  assert_eq(called.val, 11)
  let counter = Ref::new(0)
  do_many(() => counter.val = counter.val + 1, 3)
  assert_eq(counter.val, 3)
  assert_is_err(try? do_many(() => (), -1))
  let flag = Ref::new(false)
  set(flag)
  assert_true(flag.val)
  flip(flag)
  assert_true(!flag.val)
  clear(flag)
  assert_true(!flag.val)
  let int_ref = Ref::new(10)
  ref_add_int(int_ref, 2)
  ref_sub_int(int_ref, 1)
  ref_mul_int(int_ref, 3)
  ref_div_int(int_ref, 11)
  assert_eq(int_ref.val, 3)
  let double_ref = Ref::new(1.5)
  ref_add_double(double_ref, 0.5)
  ref_mul_double(double_ref, 3.0)
  ref_sub_double(double_ref, 1.0)
  ref_div_double(double_ref, 2.0)
  assert_true((double_ref.val - 2.5).abs() < 0.0001)
  let list_ref = Ref::new([2, 3])
  ref_cons(list_ref, 1)
  assert_eq(list_ref.val, [1, 2, 3])
  ref_prepend(list_ref, [-1, 0])
  assert_eq(list_ref.val, [-1, 0, 1, 2, 3])
  let memo_counter = Ref::new(0)
  let thunk = memoize(() => {
    memo_counter.val = memo_counter.val + 1
    memo_counter.val
  })
  assert_eq(thunk(), 1)
  assert_eq(thunk(), 1)
  assert_eq(memo_counter.val, 1)
  let table = hashtable_of_dictionary([("a", 1), ("b", 2)])
  assert_eq(tryfind(table, "b"), Some(2))
  assert_eq(list_of_hashtbl(table), [("a", 1), ("b", 2)])
  let set_table = hashset_of_list([1, 1, 2])
  assert_eq(set_table.length(), 2)
  let empty_map : Map[String, Int] = null_hash()
  assert_true(empty_map.is_empty())
  tt_prime()
}

///|
test "numbers, geometry, and boxes" {
  assert_eq(round(1.4), 1.0)
  assert_eq(round(1.6), 2.0)
  assert_eq(iround(2.2), 2)
  assert_eq(largest_pow2_divisible(12), 4)
  assert_eq(largest_pow2_divisible(0), 0)
  assert_eq(pow2lt(9), 8)
  assert_eq(pow2gt(9), 16)
  assert_eq(pow2gt(8), 8)
  assert_eq(log2of(8), 3)
  assert_eq(pow(3, 2), 8)
  assert_eq(pow(0, 5), 1)
  assert_eq(pow(2, 3), 9)
  assert_eq(compare_i(2, 3), -1)
  assert_eq(min(2, 1), 1)
  assert_eq(max(2, 1), 2)
  assert_eq(fmin(1.5, 2.5), 1.5)
  assert_eq(fmax(1.5, 2.5), 2.5)
  assert_eq(fmax(3.0, 2.0), 3.0)
  assert_eq(fabs(-2.0), 2.0)
  assert_true(even(4))
  assert_true(odd(5))
  assert_true((root2 * root2 - 2.0).abs() < 0.000000001)
  assert_true((deg_of_rad(pi) - 180.0).abs() < 0.000000001)
  assert_true((rad_of_deg(180.0) - pi).abs() < 0.000000001)
  assert_eq(sign_extend(7, 0xff), -1)
  assert_eq(sign_extend(7, 0x7f), 127)
  assert_true(isdigit('3'))
  assert_true(!isdigit('a'))
  assert_eq(toint(3.7), 3)
  assert_eq(safe_float(@double.not_a_number), 0.0)
  assert_eq(safe_float(@double.infinity), 0.0)
  assert_eq(safe_float(1.25), 1.25)
  let vec = mkvector((1.0, 2.0), (4.0, 6.0))
  assert_eq(vec, (3.0, 4.0))
  assert_eq(invert(vec), (-3.0, -4.0))
  assert_eq(offset_point((1.0, 1.0), (2.0, 3.0)), (3.0, 4.0))
  assert_eq(perpendicular((2.0, 3.0)), (-3.0, 2.0))
  assert_eq(sqr(3.0), 9.0)
  assert_true((veclength((3.0, 4.0)) - 5.0).abs() < 0.000000001)
  assert_eq(scalevectolength(10.0, (3.0, 4.0)), (6.0, 8.0))
  assert_eq(scalevectolength(5.0, (0.0, 0.0)), (0.0, 0.0))
  assert_eq(mkunitvector((0.0, 0.0), (0.0, 2.0)), (0.0, 1.0))
  assert_eq(between((0.0, 0.0), (2.0, 2.0)), (1.0, 1.0))
  assert_true(
    (distance_between((0.0, 0.0), (3.0, 4.0)) - 5.0).abs() < 0.000000001,
  )
  assert_eq(box_union((0, 1, 0, 1), (1, 2, -1, 3)), (0, 2, -1, 3))
  assert_eq(
    box_union_float((0.0, 1.0, 0.0, 1.0), (1.0, 2.0, -1.0, 3.0)),
    (0.0, 2.0, -1.0, 3.0),
  )
  assert_eq(box_overlap(0, 0, 2, 2, 1, 1, 3, 3), Some((1, 1, 2, 2)))
  assert_eq(box_overlap(0, 0, 1, 1, 2, 2, 3, 3), None)
  assert_eq(
    box_overlap_float(0.0, 0.0, 2.0, 2.0, 1.0, 1.0, 3.0, 3.0),
    Some((1.0, 1.0, 2.0, 2.0)),
  )
  assert_eq(box_overlap_float(0.0, 0.0, 1.0, 1.0, 2.0, 2.0, 3.0, 3.0), None)
}

///|
test "integer helpers" {
  assert_eq(i32ofi(3), 3)
  assert_eq(i32toi(4), 4)
  assert_eq(i32tof(5), 5.0)
  assert_eq(i32add(1, 2), 3)
  assert_eq(i32sub(5, 3), 2)
  assert_eq(i32div(7, 2), 3)
  assert_eq(i32mul(2, 3), 6)
  assert_eq(sr32(-4, 1), -2)
  assert_eq(lsr32(-1, 1), 2147483647)
  assert_eq(lsl32(1, 3), 8)
  assert_eq(lor32(1, 2), 3)
  assert_eq(land32(6, 3), 2)
  assert_eq(lnot32(0), -1)
  assert_eq(lxor32(5, 3), 6)
  assert_eq(i32succ(4), 5)
  assert_eq(i32pred(4), 3)
  assert_eq(i32max(2, 5), 5)
  assert_eq(i32max(5, 2), 5)
  assert_eq(i32min(2, 5), 2)
  assert_eq(i32min(5, 2), 2)
  let v64 = i64ofi(10)
  assert_eq(i64toi(v64), 10)
  assert_eq(i64tof(v64), 10.0)
  assert_eq(i64add(v64, 2), 12)
  assert_eq(i64sub(v64, 2), 8)
  assert_eq(i64div(Int64::from_int(9), 2), 4)
  assert_eq(i64mul(v64, 3), 30)
  assert_eq(sr64(Int64::from_int(-4), 1), Int64::from_int(-2))
  assert_eq(lsr64(Int64::from_int(8), 1), Int64::from_int(4))
  assert_eq(lsl64(v64, 2), Int64::from_int(40))
  assert_eq(lor64(Int64::from_int(1), Int64::from_int(2)), Int64::from_int(3))
  assert_eq(land64(Int64::from_int(6), Int64::from_int(3)), Int64::from_int(2))
  assert_eq(lnot64(Int64::from_int(0)), Int64::from_int(-1))
  assert_eq(lxor64(Int64::from_int(5), Int64::from_int(3)), Int64::from_int(6))
  assert_eq(i64succ(v64), Int64::from_int(11))
  assert_eq(i64pred(v64), Int64::from_int(9))
  assert_eq(i64max(Int64::from_int(2), Int64::from_int(5)), Int64::from_int(5))
  assert_eq(i64max(Int64::from_int(6), Int64::from_int(5)), Int64::from_int(6))
  assert_eq(i64min(Int64::from_int(2), Int64::from_int(5)), Int64::from_int(2))
  assert_eq(i64min(Int64::from_int(6), Int64::from_int(5)), Int64::from_int(5))
  assert_eq(i32ofi64(Int64::from_int(7)), 7)
  assert_eq(i64ofi32(7), Int64::from_int(7))
}

///|
test "output buffers" {
  stdout_buffer.val = ""
  stderr_buffer.val = ""
  flprint("hello")
  assert_eq(stdout_buffer.val, "hello")
  flprint(" world\n")
  assert_eq(stdout_buffer.val, "")
  fleprint("err")
  assert_eq(stderr_buffer.val, "err")
  print_ints([1, 2])
  print_int32s([3, 4])
  print_floats([1.5, 2.5])
  stdout_buffer.val = ""
}
