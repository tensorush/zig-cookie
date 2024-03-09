## :lizard: :cookie: **zig cookie**

[![CI][ci-shd]][ci-url]
[![CD][cd-shd]][cd-url]
[![DC][dc-shd]][dc-url]
[![CC][cc-shd]][cc-url]
[![LC][lc-shd]][lc-url]

### Zig implementation of the [HTTP cookie specification](https://datatracker.ietf.org/doc/html/rfc6265).

### :rocket: Usage

1. Add `cookie` as a dependency in your `build.zig.zon`.

    <details>

    <summary><code>build.zig.zon</code> example</summary>

    ```zig
    .{
        .name = "<name_of_your_package>",
        .version = "<version_of_your_package>",
        .dependencies = .{
            .cookie = .{
                .url = "https://github.com/tensorush/zig-cookie/archive/<git_tag_or_commit_hash>.tar.gz",
                .hash = "<package_hash>",
            },
        },
    }
    ```

    Set `<package_hash>` to `12200000000000000000000000000000000000000000000000000000000000000000` and build your package to find the correct value specified in a compiler error message.

    </details>

2. Add `cookie` as a module in your `build.zig`.

    <details>

    <summary><code>build.zig</code> example</summary>

    ```zig
    const cookie = b.dependency("cookie", .{});
    lib.root_module.addImport("cookie", cookie.module("cookie"));
    ```

    </details>

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
[lc-url]: https://github.com/tensorush/zig-cookie/blob/main/LICENSE.md
