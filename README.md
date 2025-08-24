# zig-cookie

## Zig port of [cookie-rs library](https://github.com/rwf2/cookie-rs) for HTTP cookie storage.

### Usage

1. Add `cookie` dependency to `build.zig.zon`:

```sh
zig fetch --save git+https://github.com/tensorush/zig-cookie.git
```

2. Use `cookie` dependency in `build.zig`:

```zig
const cookie_dep = b.dependency("cookie", .{
    .target = target,
    .optimize = optimize,
});
const cookie_mod = cookie_dep.module("cookie");
<compile>.root_module.addImport("cookie", cookie_mod);
```
