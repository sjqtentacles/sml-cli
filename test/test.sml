(* Tests for sml-cli: a declarative command-line argument parser. All parses
   use explicit argument lists, so output is deterministic across compilers. *)

structure CliTests =
struct
  open Harness

  infix |>
  fun x |> f = f x

  (* Convenience: assert a parse succeeded and hand the result to `k`; fail
     the named check (and skip `k`) if it errored. *)
  fun withOk name p k =
    case p of
        Cli.Ok r => k r
      | Cli.Err e => check name false

  (* Assert a parse failed and its message contains `needle`. *)
  fun expectErr name needle p =
    case p of
        Cli.Ok _ => check name false
      | Cli.Err e =>
          check name (String.isSubstring needle e)

  fun run () =
    let
      val () = section "basic mixed parse"

      val spec =
        Cli.spec "prog" "a demo program"
          |> Cli.flag "verbose" (SOME #"v") "be loud"
          |> Cli.strOpt "out" (SOME #"o") {required=false, default=NONE} "output file"
          |> Cli.intOpt "num" (SOME #"n") {required=false, default=NONE} "a number"

      val args = ["--verbose", "--out=file.txt", "-n", "3", "input1", "input2"]
      val () =
        withOk "mixed parse succeeds" (Cli.parse spec args) (fn r =>
          ( checkBool   "verbose flag true" (true, Cli.getBool r "verbose")
          ; checkString "out string"
              ("file.txt", Option.getOpt (Cli.getString r "out", "<none>"))
          ; checkInt    "num int" (3, Option.getOpt (Cli.getInt r "num", ~1))
          ; checkStringList "positionals"
              (["input1", "input2"], Cli.positionals r) ))

      val () = section "--key=value vs --key value"
      val () =
        withOk "equals form" (Cli.parse spec ["--out=a.txt"]) (fn r =>
          checkString "out via =" ("a.txt", Option.getOpt (Cli.getString r "out", "")))
      val () =
        withOk "space form" (Cli.parse spec ["--out", "b.txt"]) (fn r =>
          checkString "out via space" ("b.txt", Option.getOpt (Cli.getString r "out", "")))

      val () = section "clustered short flags"
      val clustered =
        Cli.spec "prog" "flags"
          |> Cli.flag "all"   (SOME #"a") "a"
          |> Cli.flag "blank" (SOME #"b") "b"
          |> Cli.flag "count" (SOME #"c") "c"
      val () =
        withOk "abc parses" (Cli.parse clustered ["-abc"]) (fn r =>
          ( checkBool "a set" (true, Cli.getBool r "all")
          ; checkBool "b set" (true, Cli.getBool r "blank")
          ; checkBool "c set" (true, Cli.getBool r "count") ))

      val () = section "attached short value -n5"
      val () =
        withOk "n5 parses" (Cli.parse spec ["-n5"]) (fn r =>
          checkInt "n is 5" (5, Option.getOpt (Cli.getInt r "num", ~1)))
      val () =
        withOk "n space parses" (Cli.parse spec ["-n", "5"]) (fn r =>
          checkInt "n is 5 (space)" (5, Option.getOpt (Cli.getInt r "num", ~1)))

      val () = section "-- terminates option parsing"
      val () =
        withOk "double dash" (Cli.parse spec ["--", "--notanopt"]) (fn r =>
          checkStringList "rest are positional"
            (["--notanopt"], Cli.positionals r))
      val () =
        withOk "double dash after pos" (Cli.parse spec ["x", "--", "-y"]) (fn r =>
          checkStringList "mixed positionals" (["x", "-y"], Cli.positionals r))

      val () = section "subcommand dispatch"
      val addSpec =
        Cli.spec "prog add" "add a thing"
          |> Cli.flag "force" (SOME #"f") "force it"
      val rmSpec =
        Cli.spec "prog rm" "remove a thing"
          |> Cli.flag "recursive" (SOME #"r") "recurse"
      val withSubs =
        Cli.spec "prog" "a tool"
          |> Cli.flag "verbose" (SOME #"v") "loud"
          |> Cli.sub "add" addSpec
          |> Cli.sub "rm" rmSpec
      val () =
        withOk "add dispatch" (Cli.parse withSubs ["add", "--force", "x"]) (fn r =>
          ( checkStringList "command path" (["add"], Cli.command r)
          ; checkBool "force set" (true, Cli.getBool r "force")
          ; checkStringList "sub positionals" (["x"], Cli.positionals r) ))
      val () =
        withOk "rm dispatch" (Cli.parse withSubs ["rm", "-r"]) (fn r =>
          ( checkStringList "rm command path" (["rm"], Cli.command r)
          ; checkBool "recursive set" (true, Cli.getBool r "recursive") ))

      val () = section "repeatable list option"
      val listSpec =
        Cli.spec "prog" "lists"
          |> Cli.listOpt "inc" (SOME #"I") "include path"
      val () =
        withOk "collects list"
          (Cli.parse listSpec ["--inc", "a", "-I", "b", "--inc=c"]) (fn r =>
            checkStringList "three includes" (["a", "b", "c"], Cli.getList r "inc"))

      val () = section "error cases"
      val reqSpec =
        Cli.spec "prog" "needs out"
          |> Cli.strOpt "out" (SOME #"o") {required=true, default=NONE} "output"
          |> Cli.intOpt "num" (SOME #"n") {required=false, default=NONE} "a number"
      val () = expectErr "missing required" "missing required option --out"
                 (Cli.parse reqSpec [])
      val () = expectErr "unknown long option" "unknown option --nope"
                 (Cli.parse reqSpec ["--nope"])
      val () = expectErr "unknown short option" "unknown option -z"
                 (Cli.parse reqSpec ["-z"])
      val () = expectErr "non-int value" "expects an integer"
                 (Cli.parse reqSpec ["-o", "f", "--num", "abc"])
      (* An oversized --opt value must not overflow the default `int`:
         Int.fromString raises Overflow past 2^31 on a 32-bit int (MLton) but
         accepts it on a 63-bit int (Poly/ML). The parser bounds it, so an
         out-of-range value takes the same "expects an integer" error path
         byte-identically on both compilers. *)
      val () = expectErr "oversized int value (12 digits)" "expects an integer"
                 (Cli.parse reqSpec ["-o", "f", "--num", "999999999999"])
      val () = expectErr "int value at 2^31" "expects an integer"
                 (Cli.parse reqSpec ["-o", "f", "--num", "2147483648"])
      val () = check "oversized int value does not raise"
                 ((Cli.parse reqSpec ["-o", "f", "--num", "999999999999"]; true)
                  handle _ => false)
      val () = withOk "in-range int value still parses"
                 (Cli.parse reqSpec ["-o", "f", "--num", "42"])
                 (fn r => checkInt "num is 42" (42, Option.getOpt (Cli.getInt r "num", ~1)))
      val () = expectErr "missing value" "requires a value"
                 (Cli.parse reqSpec ["-o", "f", "--num"])

      val () = section "usage / help (snapshot)"
      val helpSpec =
        Cli.spec "git-ish" "a tiny demo VCS"
          |> Cli.flag "verbose" (SOME #"v") "print more"
          |> Cli.strOpt "out" (SOME #"o") {required=false, default=NONE} "output file"
          |> Cli.intOpt "jobs" (SOME #"j") {required=false, default=SOME 1} "parallel jobs"
          |> Cli.sub "add" (Cli.spec "git-ish add" "stage files")
          |> Cli.sub "commit" (Cli.spec "git-ish commit" "record changes")
      val expectedUsage =
        "git-ish - a tiny demo VCS\n\
        \usage: git-ish [options] <command>\n\
        \\n\
        \options:\n\
        \  -v, --verbose  print more\n\
        \  -o, --out <str>  output file\n\
        \  -j, --jobs <int>  parallel jobs\n\
        \\n\
        \commands:\n\
        \  add  stage files\n\
        \  commit  record changes\n"
      val () = checkString "usage snapshot" (expectedUsage, Cli.usage helpSpec)
    in
      ()
    end
end
