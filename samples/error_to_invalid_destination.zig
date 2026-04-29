// Passing a non-Quantity type as the destination of .to().

const u = @import("unitz").quantities(f32);

pub fn main() void {
    const distance: u.meter = .init(1);
    const x = distance.to(f32);
    _ = x;
}

// Expected error:
//   src/quantity.zig:80:17: error: to() expects a Quantity type, got 'f32'
