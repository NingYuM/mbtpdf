///|
test "lists basics and mapping" {
  let xs = [1, 2, 3, 4]
  assert_eq(hd(xs), 1)
  assert_eq(tl(xs), [2, 3, 4])
  assert_is_err(try? hd(([] : Array[Int])))
  assert_is_err(try? tl(([] : Array[Int])))
  assert_eq(rev(xs), [4, 3, 2, 1])
  assert_eq(append([1, 2], [3]), [1, 2, 3])
  assert_eq(flatten([[1], [2, 3]]), [1, 2, 3])
  let sum_ref = Ref::new(0)
  iter(value => sum_ref.val = sum_ref.val + value, [1, 2, 3])
  assert_eq(sum_ref.val, 6)
  let pair_sum = Ref::new(0)
  iter2((a, b) => pair_sum.val = pair_sum.val + a + b, [1, 2], [3, 4])
  assert_eq(pair_sum.val, 10)
  let triple_sum = Ref::new(0)
  iter3(
    (a, b, c) => triple_sum.val = triple_sum.val + a + b + c,
    [1, 2],
    [3, 4],
    [5, 6],
  )
  assert_eq(triple_sum.val, 21)
  assert_eq(map(value => value * 2, [1, 2]), [2, 4])
  assert_eq(rev_map(value => value + 1, [1, 2, 3]), [4, 3, 2])
  assert_eq(map2((a, b) => a + b, [1, 2], [10, 20]), [11, 22])
  assert_eq(map3((a, b, c) => a + b + c, [1, 2], [10, 20], [100, 200]), [
    111, 222,
  ])
  assert_is_err(try? map3((a, b, c) => a + b + c, [1], [2], [3, 4]))
  assert_eq(map4((a, b, c, d) => a + b + c + d, [1], [2], [3], [4]), [10])
  assert_is_err(try? map4((a, b, c, d) => a + b + c + d, [1], [2], [3], [4, 5]))
  assert_eq(
    map5((a, b, c, d, e) => a + b + c + d + e, [1], [2], [3], [4], [5]),
    [15],
  )
  assert_is_err(
    try? map5((a, b, c, d, e) => a + b + c + d + e, [1], [2], [3], [4], [5, 6]),
  )
  assert_eq(
    map6((a, b, c, d, e, f) => a + b + c + d + e + f, [1], [2], [3], [4], [5], [
      6,
    ]),
    [21],
  )
  assert_is_err(
    try? map6(
      (a, b, c, d, e, f) => a + b + c + d + e + f,
      [1],
      [2],
      [3],
      [4],
      [5],
      [6, 7],
    ),
  )
  assert_eq(combine([1, 2], ["a", "b"]), [(1, "a"), (2, "b")])
  assert_eq(combine3([1, 2], ["a", "b"], [true, false]), [
    (1, "a", true),
    (2, "b", false),
  ])
  assert_is_err(try? combine([1], ["a", "b"]))
  assert_eq(split([(1, "a"), (2, "b")]), ([1, 2], ["a", "b"]))
  assert_eq(
    split3([(1, "a", true), (2, "b", false)]),
    ([1, 2], ["a", "b"], [true, false]),
  )
  assert_eq(
    split5([(1, 2, 3, 4, 5), (6, 7, 8, 9, 10)]),
    ([1, 6], [2, 7], [3, 8], [4, 9], [5, 10]),
  )
  assert_eq(
    split6([(1, 2, 3, 4, 5, 6), (7, 8, 9, 10, 11, 12)]),
    ([1, 7], [2, 8], [3, 9], [4, 10], [5, 11], [6, 12]),
  )
  assert_eq(
    split8([(1, 2, 3, 4, 5, 6, 7, 8)]),
    ([1], [2], [3], [4], [5], [6], [7], [8]),
  )
  assert_eq(fold_left((acc, value) => acc + value, 0, [1, 2, 3]), 6)
  assert_eq(fold_right((value, acc) => value - acc, [1, 2, 3], 0), 2)
  assert_eq(length([1, 2, 3]), 3)
  assert_eq(sort(compare_i, [3, 1, 2]), [1, 2, 3])
  assert_eq(sum([1, 2, 3]), 6)
  assert_eq(fsum([1.0, 2.5]), 3.5)
  assert_eq(cumulative_sum(10, [1, 2, 3]), [11, 13, 16])
  assert_eq(lcount(value => value % 2 == 0, [1, 2, 3, 4]), 2)
  assert_eq(losenones([Some(1), None, Some(3)]), [1, 3])
  assert_eq(
    option_map(value => if value % 2 == 0 { Some(value * 2) } else { None }, [
      1, 2, 3, 4,
    ]),
    [4, 8],
  )
  assert_eq(
    option_map2((a, b) => if a == b { Some(a) } else { None }, [1, 2, 3], [
      1, 0, 3,
    ]),
    [1, 3],
  )
  assert_true(mem(2, [1, 2, 3]))
  assert_eq(position(3, [1, 2, 3]), Some(2))
  assert_eq(position_1(3, [1, 2, 3]), Some(3))
}

///|
test "lists slicing and splitting" {
  let xs = [1, 2, 3, 4, 5]
  assert_eq(take(xs, 2), [1, 2])
  assert_eq(take_swapped(2, xs), [1, 2])
  assert_eq(drop(xs, 2), [3, 4, 5])
  assert_eq(drop_swapped(2, xs), [3, 4, 5])
  assert_eq(takewhile(value => value < 4, xs), [1, 2, 3])
  assert_eq(takewhile_reverse(value => value < 4, xs), [3, 2, 1])
  assert_eq(dropwhile(value => value < 3, xs), [3, 4, 5])
  assert_eq(cleave(xs, 2), ([1, 2], [3, 4, 5]))
  assert_eq(cleavewhile(value => value < 4, xs), ([1, 2, 3], [4, 5]))
  assert_eq(cleavewhile_unordered(value => value < 4, xs), ([1, 2, 3], [4, 5]))
  assert_eq(
    isolate(value => value == 2, value => value == 5, [0, 2, 3, 4, 5, 6]),
    [3, 4],
  )
  assert_eq(isolate(value => value == 10, value => value == 20, [1, 2, 3]), [])
  assert_eq(interleave(0, [1, 2, 3]), [1, 0, 2, 0, 3])
  assert_eq(interleave(0, [1]), [1])
  assert_eq(interleave_lists([1, 2], [3, 4]), [1, 3, 2, 4])
  assert_is_err(try? interleave_lists([1], [2, 3]))
  assert_eq(collate(compare_i, [1, 1, 2, 2, 2, 3, 1]), [
    [1, 1],
    [2, 2, 2],
    [3],
    [1],
  ])
  assert_eq(map_lol(value => value + 1, [[1, 2], [3]]), [[2, 3], [4]])
  assert_eq(conspair(((1, "a"), ([2], ["b"]))), ([1, 2], ["a", "b"]))
  assert_eq(conspairopt(((Some(1), None), ([2], ["b"]))), ([1, 2], ["b"]))
  assert_eq(conspairopt(((None, Some("b")), ([1], ["a"]))), ([1], ["b", "a"]))
  assert_eq(pairs_of_list([1, 2, 3, 4]), [(1, 2), (3, 4)])
  assert_eq(pairs([1, 2, 3]), [(1, 2), (2, 3)])
  assert_eq(pairs([1]), [])
  assert_is_err(try? pairs_of_list([1, 2, 3]))
  assert_eq(replaceinlist(value => value == 2, 9, [1, 2, 3]), [1, 9, 3])
  assert_eq(index(value => value == 3, [1, 2, 3]), 3)
  assert_is_err(try? index(value => value == 9, [1, 2, 3]))
  assert_eq(split_around(value => value == 0, [0, 1, 0, 2]), [[], [1], [2]])
  assert_is_err(try? cleave(xs, -1))
  assert_is_err(try? cleave(xs, 6))
  assert_is_err(try? take(xs, -1))
  assert_is_err(try? drop(xs, 10))
}

///|
test "lists sets and grouping" {
  assert_true(mem_swapped([1, 2, 3], 2))
  assert_eq(setify([3, 1, 2, 1]), [1, 2, 3])
  assert_eq(setify(([] : Array[Int])), [])
  assert_eq(setify_preserving_order([3, 1, 2, 1]), [3, 1, 2])
  assert_eq(setify_large([3, 1, 2, 1]), [3, 1, 2])
  assert_eq(setminus([1, 2, 3, 4], [2, 4]), [3, 1])
  assert_eq(setminus_preserving_order([1, 2, 3, 4], [2, 4]), [1, 3])
  assert_eq(heads([[1, 2], [3, 4]]), [1, 3])
  assert_eq(tails([[1, 2], [3, 4]]), [[2], [4]])
  assert_eq(zipn([[1, 2], [3]]), [[1, 3]])
}

///|
test "lists pairing and generation" {
  let xs = [1, 2, 3, 4]
  assert_eq(couple((a, b) => a + b, xs), [3, 5, 7])
  assert_eq(couple((a, b) => a + b, [1]), [])
  assert_eq(couple_ext((a, b) => a + b, value => value, [1, 2, 3]), [3, 5, 3])
  assert_eq(couple_reduce((a, b) => a + b, xs), 20)
  assert_eq(pair((a, b) => a + b, [1, 2, 3]), [3, 3])
  assert_eq(pair_ext((a, b) => a + b, value => value * 10, [1, 2, 3]), [3, 30])
  assert_eq(pair_reduce((a, b) => a + b, xs), 10)
  assert_eq(keep(value => value % 2 == 0, xs), [2, 4])
  assert_eq(lose(value => value % 2 == 0, xs), [1, 3])
  assert_eq(many(7, 3), [7, 7, 7])
  let unique_count = Ref::new(0)
  assert_eq(
    manyunique(
      () => {
        unique_count.val = unique_count.val + 1
        unique_count.val
      },
      3,
    ),
    [1, 2, 3],
  )
  assert_eq(splitinto(2, [1, 2, 3, 4, 5]), [[1, 2], [3, 4], [5]])
  assert_eq(splitinto_small(2, [1, 2, 3, 4, 5]), [[1, 2], [3, 4], [5]])
  assert_eq(splitat([2, 4], [1, 2, 3, 4, 5]), [[1, 2], [3, 4], [5]])
  assert_eq(select(2, [1, 2, 3]), 2)
  assert_is_err(try? select(0, [1, 2, 3]))
  assert_eq(replace_number(2, 9, [1, 2, 3]), [1, 9, 3])
  assert_eq(replace_number(0, 9, [1, 2]), [1, 2])
  assert_true(isnull(([] : Array[Int])))
  assert_true(notnull([1]))
  assert_eq(last([1, 2]), 2)
  assert_is_err(try? last(([] : Array[Int])))
  assert_eq(all_but_last([1, 2, 3]), [1, 2])
  assert_eq(all_but_last([1]), [])
  assert_eq(extremes([1, 2, 3]), (1, 3))
  assert_is_err(try? extremes(([] : Array[Int])))
  assert_eq(extremes([5]), (5, 5))
  assert_eq(extremes_and_middle([1, 2, 3, 4]), (1, [2, 3], 4))
  assert_is_err(try? extremes_and_middle(([] : Array[Int])))
  assert_eq(extremes_and_middle([1, 2]), (1, ([] : Array[Int]), 2))
  assert_eq(ilist(2, 4), [2, 3, 4])
  assert_eq(ilist(2, 2), [2])
  assert_eq(ilist_null(2, 2), [])
  assert_eq(ilist_null(2, 3), [2, 3])
  assert_is_err(try? ilist_null(3, 2))
  assert_eq(ilist_fail_null(3, 2), [])
  assert_eq(ilist_fail_null(2, 2), [])
  assert_eq(ilist_fail_null(1, 3), [1, 2, 3])
  assert_is_err(try? ilist(3, 2))
  assert_eq(indx([10, 20, 30]), [1, 2, 3])
  assert_eq(indx0([10, 20, 30]), [0, 1, 2])
  assert_eq(indxn(5, [10, 20]), [5, 6])
  assert_eq(drop_evens([0, 1, 2, 3]), [0, 2, 3])
  assert_eq(really_drop_evens([0, 1, 2, 3]), [0, 2])
  assert_eq(drop_odds([0, 1, 2, 3]), [1, 3])
  assert_eq(tail_no_fail(([] : Array[Int])), ([] : Array[Int]))
  assert_eq(tail_no_fail([1, 2]), [2])
  assert_eq(append_rev([1, 2], [3, 4]), [3, 4, 1, 2])
  assert_is_err(
    try? pair_reduce((a : Int, b : Int) => a + b, ([] : Array[Int])),
  )
  assert_is_err(
    try? couple_reduce((a : Int, b : Int) => a + b, ([] : Array[Int])),
  )
  assert_is_err(try? many(1, -1))
  assert_is_err(try? manyunique(() => 1, -2))
  assert_is_err(try? splitinto(0, [1, 2]))
  assert_is_err(try? splitat([3], [1, 2]))
}
