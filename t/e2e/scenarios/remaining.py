"""PTY coverage for catalogue entries missed by the group files."""

from loom_e2e.registry import scenario

from .scenario_helpers import probe_command


@scenario("movement/splice-sexp", commands=["splice-sexp"])
def splice_sexp(binary):
    probe_command(binary, "splice-sexp", b"(alpha (beta))\n")


@scenario("editing/backward-kill-word", commands=["backward-kill-word"])
def backward_kill_word(binary):
    probe_command(binary, "backward-kill-word", b"alpha beta\n")

