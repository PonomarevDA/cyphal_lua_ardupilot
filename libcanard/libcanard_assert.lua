function assert_eq(first_int, second_int, msg)
  if first_int ~= second_int then
    print("Fail", first_int, second_int)
  elseif msg ~= nil then
    print("Good", first_int)
  end
end
