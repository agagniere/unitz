# Unitz

Achieve compile-time unit correctness and avoid runtime surprises.

## Status

| Architecture \ OS | Linux | MacOS |
|:------------------|:-----:|:-----:|
| `x86_64`          | ✅    | ✅    |
| `arm64`           | ✅    | ✅    |

| Branch name | Zig version        |
|:------------|:-------------------|
| `master`    | `0.16.x`, `master` |
| `zig-0.15`  | `0.14.x`, `0.15.x` |
| `zig-0.13`  | `0.13.x`           |

## Showcase

Use units as types, to document your functions, and convert to units of the same dimension:

```zig
const unitz = @import("unitz");
const units = unitz.quantities(f32);

const m = units.meter;
const s = units.second;
const kt = units.knot;
const @"km/h" = unitz.evalQuantity(f32, "km / h", .{});

fn aircraft_speed(distance: m, duration: s) kt {
	const speed = distance.div(duration); // value is in m/s
	const result: kt = .from(speed); // convert to target unit
	std.debug.print("Speed: {} m/s = {} kt = {} km/h\n", .{
		speed.val(),
		result.val(),
		speed.toVal(@"km/h"),
	});
	return result;
}
```

A compilation error occurs when trying to perform an invalid conversion:

```zig
const J = units.joule;
const hp = units.imperial_horsepower;

const engine_power: hp = .init(130);
const energy = engine_power.to(J);
```
Will result in the compilation error:
```zig
src/quantity.zig:84:60: error: Units are only interconvertible if they measure the same kind of dimension
            comptime if (!unit_from.isCompatible(unit_to)) @compileError("Units are only interconvertible if they measure the same kind of dimension");
                                                           ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
foo.zig:8:35: note: called inline here
    const energy = engine_power.to(J);
                   ~~~~~~~~~~~~~~~^~~
```

No conversion is done implicitly, the value stored in memory is exactly the one provided to the constructor.

## Defining your own units

This library does not provide all variations of standard units: meter and hour are provided, but kilometer and kilometer per hour is not. Instead, you can define any unit you want from its definition, using prefixes if needed:

```zig
const nanosecond = unitz.evalQuantity(f32, "ns", .{});
const @"kg/m3" = unitz.evalQuantity(f32, "kg / m^3", .{});
const kilowatthour = unitz.evalQuantity(f32, "kW * h", .{});
const Cal = unitz.evalQuantity(f32, "kcal", .{}); // large calorie
```

## Simple example

```zig
const std = @import("std");
const unitz = @import("unitz");
const q = unitz.quantities(f32);

const m = q.meter;
const kg = q.kilogram;
const lb = q.pound;
const cm = unitz.evalQuantity(f32, "cm", .{});
const @"kg/m²" = unitz.evalQuantity(f32, "kg / m^2", .{});

fn body_mass_index(height: m, weight: kg) @"kg/m²" {
	return weight.div(height.pow(2));
}

pub fn main() void {
	const height: cm = .init(162);
	const weight: lb = .init(124);
	const bmi = body_mass_index(.from(height), .from(weight));
	std.debug.print("BMI: {}", .{bmi.val()});
}
```

## Advanced example

We redefine slug and pound-force to show how it can be done
```zig
const unitz = @import("unitz");

const slug = unitz.evalUnit("32.174_049 * lb", .{});
const lbf = unitz.evalQuantity(f32, "ft * my_slug / s^2", .{ .my_slug = slug });
const @"lbf.s" = unitz.evalQuantity(f32, "my_lbf * s", .{ .my_lbf = lbf.unit });
const @"N.s" = unitz.evalQuantity(f32, "N * s", .{});
const @"μs" = unitz.evalQuantity(f32, "us", .{});

fn compute_impulse(force: lbf, delta: @"μs") @"lbf.s" {
    return .from(force.mul(delta)); // The .from converts to the target unit
    // return force.mul(delta).to(@"lbf.s"); // equivalent
}

fn compute_trajectory(impulse: @"N.s") void {
    // ...
}

pub fn main() void {
    const force = lbf.init(123.0);
    const delta = @"μs".init(45.0);

    compute_trajectory(compute_impulse(force, delta)); // compilation error !
    // Adding .to(@"N.s") or using .from(...) will fix it:
    // compute_trajectory(compute_impulse(force, delta).to(@"N.s"));
    // compute_trajectory(.from(compute_impulse(force, delta)));
}
```

And just like that, you can avoid [crashing into the atmosphere](https://en.wikipedia.org/wiki/Mars_Climate_Orbiter#Cause_of_failure)

## Use in your project

Add the dependency in your build.zig.zon by running the following command:

```shell
zig fetch --save git+https://github.com/agagniere/unitz#master
```

Add it to your exe in your build.zig:
```zig
exe.root_module.addImport("unitz", b.dependency("unitz", .{ .target = target, .optimize = optimize }).module("unitz"));
```

Then you can import it from your code:
```zig
const unitz = @import("unitz");
```

## Generate documentation

```shell
zig build docs
# Then serve locally, for example:
python -m http.server 8000 -d zig-out/docs
open "http://localhost:8000"
```

## Bump dependencies

```shell
zig fetch --save git+https://codeberg.org/InKryption/comath#main
```
