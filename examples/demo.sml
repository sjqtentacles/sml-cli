(* demo.sml - build a small CLI spec (a "deploy" tool with a "rollback"
   subcommand), parse literal argument lists against it, and read back the
   typed values. Deterministic: `parse` is pure and never touches
   CommandLine.arguments. *)

structure C = Cli

val rollbackSpec =
  C.flag "force" (SOME #"f") "skip confirmation"
    (C.spec "rollback" "roll back to the previous release")

val spec = C.spec "deploy" "ship a build to an environment"
val spec = C.flag "verbose" (SOME #"v") "enable verbose output" spec
val spec =
  C.strOpt "env" (SOME #"e") {required = true, default = NONE}
    "target environment" spec
val spec =
  C.intOpt "retries" NONE {required = false, default = SOME 3}
    "number of retries" spec
val spec = C.listOpt "tag" (SOME #"t") "attach a tag (repeatable)" spec
val spec = C.sub "rollback" rollbackSpec spec

fun show label args =
  let
    val () = print (label ^ "\n")
  in
    case C.parse spec args of
        C.Err e => print ("  ERROR: " ^ e ^ "\n")
      | C.Ok r =>
          let
            val () = print ("  command     = ["
                            ^ String.concatWith "," (C.command r) ^ "]\n")
            val () = print ("  positionals = ["
                            ^ String.concatWith "," (C.positionals r) ^ "]\n")
            val () = print ("  verbose     = "
                            ^ Bool.toString (C.getBool r "verbose") ^ "\n")
            val () = print ("  force       = "
                            ^ Bool.toString (C.getBool r "force") ^ "\n")
            val () = print ("  env         = "
                            ^ (case C.getString r "env" of
                                   SOME s => s
                                 | NONE => "(none)")
                            ^ "\n")
            val () = print ("  retries     = "
                            ^ (case C.getInt r "retries" of
                                   SOME i => Int.toString i
                                 | NONE => "(none)")
                            ^ "\n")
            val () = print ("  tags        = ["
                            ^ String.concatWith "," (C.getList r "tag")
                            ^ "]\n")
          in () end
  end

val () = show "Parsing: --env prod -v --tag release --tag hotfix extra1"
              ["--env", "prod", "-v", "--tag", "release", "--tag", "hotfix",
               "extra1"]
val () = print "\n"
val () = show "Parsing: rollback --force" ["rollback", "--force"]
val () = print "\n"
val () = show "Parsing: -v (missing required --env)" ["-v"]

val () = print "\nUsage:\n"
val () = print (C.usage spec)
