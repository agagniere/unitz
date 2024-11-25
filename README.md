# Unitz

Achieve compile-time unit correctness and avoid runtime surprises.

## Showcase

Use units as types, to document your functions, and convert to units of the same dimension:

```zig
const units = @import("unitz").quantities(f32);

const m = units.meter;
const s = units.second;
const kt = units.knot;
const @"km/h" = units.kilometer_per_hour;

fn aircraft_speed(distance: m, duration: s) kt {
	const speed = distance.div(duration); // value is in m/s
	const result = speed.to(kt);
	std.debug.print("Speed: {} m/s = {} kt = {} km/h\n", .{
		speed.val(),
		result.val(),
		speed.to_val(@"km/h"),
	});
	return result;
}
```

A compilation error occurs when trying to perform an invalid conversion:

```zig
const J = units.joule;
const hp = units.imperial_horsepower;

const engine_power = hp.init(130);
const energy = engine_power.to(J);
```
Will result in the compilation error:
```zig
src/root.zig:233:61: error: Units are only interconvertible if they measure the same kind of dimension
            comptime if (!unit_from.is_compatible(unit_to)) @compileError("Units are only interconvertible if they measure the same kind of dimension");
                                                            ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
foo.zig:29:35: note: called from here
    const energy = engine_power.to(J);
                   ~~~~~~~~~~~~~~~^~~
```

No conversion is done implicitly, the value stored in memory is exactly the one provided to the constructor.

## Advanced usage

You can define your own units:

```zig
const unitz = @import("unitz");
const Quantity = unitz.Quantity;

const my_units = struct {
	const u = unitz.units; // here we use the abstract units, that don't store a value
	const ft = u.foot;
	const lb = u.pound;
	const s = u.second;
	const N = u.newton;

	const pound_force = ft.mul(lb).div(s.pow(2)).scale(32.174_049);
	const pound_force_seconds = pound_force.mul(s);
	const newton_seconds = N.mul(s);
	const microsecond = s.prefix(.micro);
};

// We can now create quantities, that is a value expressed relatively to its unit
const lbf = Quantity(my_units.pound_force, f32);
const @"lbf.s" = Quantity(my_units.pound_force_seconds, f32);
const @"N.s" = Quantity(my_units.newton_seconds, f32);
const @"μs" = Quantity(my_units.microsecond, f32);


fn compute_impulse(force: lbf, delta: @"μs") @"lbf.s" {
	return force.mul(delta).to(@"lbf.s"); // we need to convert from lbf.us to lbf.s, if we forget, a compilation error occurs
}

fn compute_trajectory(impulse: @"N.s") void {
	// ...
}

const force = lbf.init(123.0);
const delta = @"μs".init(5);
compute_trajectory(compute_impulse(force, delta)); // compilation error ! Adding .to(@"N.s") will fix it
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
zig fetch --save git+https://github.com/InKryption/comath#main
```
