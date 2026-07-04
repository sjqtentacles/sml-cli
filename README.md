# sml-cli

[![CI](https://github.com/sjqtentacles/sml-cli/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-cli/actions/workflows/ci.yml)

A declarative command-line argument parser for Standard ML. You describe a
program as a `spec` -- a set of options, flags and subcommands -- and parse an
explicit list of arguments into a typed `result`.

The core `parse` is **pure**: it takes an explicit `string list` and never
reads `CommandLine.arguments`, so behaviour is fully deterministic and easy to
test. A thin `parseArgv` wrapper is provided for real programs.

## Portability

Pure Standard ML using only the Basis library -- no FFI, no threads, no
dependencies. Verified on **MLton** and **Poly/ML**.

## Building and testing

```sh
make test        # build + run the suite under MLton (default)
make test-poly   # build + run the suite under Poly/ML
make all-tests   # run under both
make clean
```

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-cli
smlpkg sync
```

Then reference the library basis from your own `.mlb`:

```
lib/github.com/sjqtentacles/sml-cli/sml-cli.mlb
```

For Poly/ML, `use` the `cli.sig` and `cli.sml` sources in order.

## Recognised syntax

| Form | Meaning |
| --- | --- |
| `--key value` / `--key=value` | long option with a value |
| `--flag` | boolean long flag |
| `-n value` / `-n5` | short option with a value (space or attached) |
| `-abc` | clustered short boolean flags (`-a -b -c`) |
| `--` | stop option parsing; the rest are positionals |
| `cmd ...` | a leading subcommand name dispatches to its own spec |

Unknown options, missing required options, and ill-typed values are reported
as a distinguished `Err message`. An `intOpt` value is bounded to the signed
32-bit range, so an oversized number is an `Err` ("expects an integer")
identically on MLton and Poly/ML rather than overflowing the default `int`.

## Usage

```sml
open Cli
infix |>

val spec =
  Cli.spec "greet" "say hello"
    |> flag   "shout" (SOME #"s") "use capitals"
    |> strOpt "name"  (SOME #"n") {required = true, default = NONE} "who to greet"
    |> intOpt "times" (SOME #"t") {required = false, default = SOME 1} "repeat count"

val () =
  case parse spec ["--name=Ada", "-t", "3", "--shout"] of
      Ok r =>
        let
          val name  = Option.getOpt (getString r "name", "world")
          val times = Option.getOpt (getInt r "times", 1)
          val loud  = getBool r "shout"
        in
          (* name = "Ada", times = 3, loud = true *)
          ()
        end
    | Err msg => print ("error: " ^ msg ^ "\n")
```

Subcommands nest naturally; `command r` reports the dispatched path:

```sml
val tool =
  Cli.spec "tool" "a tool"
    |> flag "verbose" (SOME #"v") "loud"
    |> sub "add" (Cli.spec "tool add" "add a thing"
                    |> flag "force" (SOME #"f") "force it")

val Ok r = parse tool ["add", "--force", "x"]
val ["add"] = command r          (* dispatched subcommand path *)
val true    = getBool r "force"
val ["x"]   = positionals r
```

## API summary

| Function | Description |
| --- | --- |
| `spec : string -> string -> spec` | Start a spec from a name and blurb. |
| `flag / strOpt / intOpt / listOpt` | Smart constructors for declared options. |
| `addArg : arg -> spec -> spec` | Append a fully-specified option record. |
| `sub : string -> spec -> spec -> spec` | Register a named subcommand. |
| `parse : spec -> string list -> result parsed` | Pure parse of explicit args. |
| `parseArgv : spec -> result parsed` | Convenience parse of process argv. |
| `command : result -> string list` | Dispatched subcommand path. |
| `positionals : result -> string list` | Leftover non-option args, in order. |
| `getBool / getInt / getString / getList` | Typed accessors over a result. |
| `get : result -> string -> value option` | Raw tagged lookup by long name. |
| `usage : spec -> string` | Deterministic help/usage text. |

## License

MIT. See [LICENSE](LICENSE).
