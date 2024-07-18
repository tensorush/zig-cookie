# zig-cookie

[![CI][ci-shd]][ci-url]
[![CD][cd-shd]][cd-url]
[![DC][dc-shd]][dc-url]
[![CC][cc-shd]][cc-url]
[![LC][lc-shd]][lc-url]

## Zig port of [cookie library](https://github.com/rwf2/cookie-rs) for HTTP cookie storage.

### :rocket: Usage

- Add `cookie` dependency to `build.zig.zon`.

```sh
zig fetch --save https://github.com/tensorush/zig-cookie/archive/<git_tag_or_commit_hash>.tar.gz
```

- Use `cookie` dependency in `build.zig`.

```zig
const cookie_dep = b.dependency("cookie", .{
    .target = target,
    .optimize = optimize,
});
const cookie_mod = cookie_dep.module("cookie");
<compile>.root_module.addImport("cookie", cookie_mod);
```

<!-- MARKDOWN LINKS -->

[ci-shd]: https://img.shields.io/github/actions/workflow/status/tensorush/zig-cookie/ci.yaml?branch=main&style=for-the-badge&logo=github&label=CI&labelColor=black
[ci-url]: https://github.com/tensorush/zig-cookie/blob/main/.github/workflows/ci.yaml
[cd-shd]: https://img.shields.io/github/actions/workflow/status/tensorush/zig-cookie/cd.yaml?branch=main&style=for-the-badge&logo=github&label=CD&labelColor=black
[cd-url]: https://github.com/tensorush/zig-cookie/blob/main/.github/workflows/cd.yaml
[dc-shd]: https://img.shields.io/badge/click-F6A516?style=for-the-badge&logo=zig&logoColor=F6A516&label=docs&labelColor=black
[dc-url]: https://tensorush.github.io/zig-cookie
[cc-shd]: https://img.shields.io/codecov/c/github/tensorush/zig-cookie?style=for-the-badge&labelColor=black
[cc-url]: https://app.codecov.io/gh/tensorush/zig-cookie
[lc-shd]: https://img.shields.io/github/license/tensorush/zig-cookie.svg?style=for-the-badge&labelColor=black
[lc-url]: https://github.com/tensorush/zig-cookie/blob/main/LICENSE
