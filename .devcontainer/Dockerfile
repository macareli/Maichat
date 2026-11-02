# Pin the Android/JDK base, then install the same Flutter revision used by CI.
FROM ghcr.io/cirruslabs/flutter@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8

ENV FLUTTER_VERSION=3.44.9

RUN git -C "$FLUTTER_ROOT" fetch --depth 1 origin "refs/tags/$FLUTTER_VERSION:refs/tags/$FLUTTER_VERSION" \
    && test "$(git -C "$FLUTTER_ROOT" rev-parse FETCH_HEAD)" = "6b182d2c7585eba26d4edce0f97630effd256c33" \
    && git -C "$FLUTTER_ROOT" checkout --detach FETCH_HEAD \
    && flutter config --no-analytics \
    && flutter precache --android \
    && flutter --version
