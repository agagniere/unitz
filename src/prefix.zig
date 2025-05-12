/// A metric prefix precedes a basic unit of measure to indicate a multiple or submultiple of the unit
pub const Prefix = enum {
    tera,
    giga,
    mega,
    kilo,
    hecto,
    deca,
    one,
    deci,
    centi,
    milli,
    micro,
    nano,
    pico,
};

/// Expressed in term of the base unit
pub fn prefixFactor(comptime prefix: Prefix) comptime_float {
    return switch (prefix) {
        .tera => 1e12,
        .giga => 1e9,
        .mega => 1e6,
        .kilo => 1e3,
        .hecto => 100,
        .deca => 10,
        .one => 1,
        .deci => 0.1,
        .centi => 0.01,
        .milli => 1e-3,
        .micro => 1e-6,
        .nano => 1e-9,
        .pico => 1e-12,
    };
}
