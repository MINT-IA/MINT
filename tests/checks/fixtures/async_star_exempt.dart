// fixture — async* generator with bare catch is D-06 exempt.
Stream<int> streamInts() async* {
  try {
    yield* source();
  } catch (e) {}
}
