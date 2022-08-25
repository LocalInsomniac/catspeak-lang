//! Boilerplate for the `CatspeakOption` enum.

//# feather use syntax-errors

/// The set of feature flags Catspeak can be configured with.
enum CatspeakOption {
    NONE = 0,
    TOTAL = (1 << 0),
    UNSAFE = (1 << 1),
    NO_PRELUDE = (1 << 2),
    PERSISTENT = (1 << 3),
    ALL = (
        CatspeakOption.TOTAL
        | CatspeakOption.UNSAFE
        | CatspeakOption.NO_PRELUDE
        | CatspeakOption.PERSISTENT
    ),
}