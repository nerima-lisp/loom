{
  description = "Terminal text editor with Emacs-like keybindings in Common Lisp";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The org flake preset. Everything this file used to spell out by hand --
    # the `.asd` version extraction, `forAllSystems`, the treefmt eval wired
    # to both `formatter` and `checks.formatting`, the mkdocs package plus
    # its check, the run-tests.lisp gate, the `apps.test`/`apps.default`
    # pair, and the hand-written `save-lisp-and-die` that delivered the
    # binary -- is one `mkPackageFlake` call below. Pinned to a release TAG,
    # never to the branch: a bare `github:nerima-lisp/cl-nix-forge` follows
    # that repository's default branch and would change this build without
    # warning. See ../nshell/flake.nix for the sibling L4-application
    # migration this one mirrors.
    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Sibling packages are ALWAYS pinned to a release tag. A bare
    # `github:nerima-lisp/cl-tty-kit` follows that repo's default branch,
    # which means an upstream push to main breaks this repo's CI without
    # warning. cl-weave is consumed as a flake (it is used as a built test
    # dependency for the dev shell's interactive `sbcl`, not merely a source
    # tree), so it alone carries the mandatory `inputs.nixpkgs.follows` --
    # without it, it would drag in its own nixpkgs, inflating flake.lock and
    # rebuilding the same derivations.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.paredit-cli.follows = "paredit-cli";
    };

    # Structural Common Lisp parser/rewriter used by the development shell
    # and the source-level syntax gate below. Keep it explicit instead of
    # relying on cl-weave's test-only transitive input.
    paredit-cli = {
      url = "github:nerima-lisp/paredit-cli/v1.6.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # loom's runtime dependencies. We only need each one's source tree (built
    # below as an SBCL lisp library via `lispDerivation`), so they are
    # consumed as non-flake sources. `flake = false` reaches the same goal
    # `inputs.nixpkgs.follows` exists for, and reaches it more completely: a
    # non-flake input has no inputs of its own, so it cannot contribute a
    # second nixpkgs to flake.lock at all.
    cl-tty-kit = {
      url = "github:nerima-lisp/cl-tty-kit/v1.6.1";
      flake = false;
    };
    # cl-tty-kit v1.6.1's own `:depends-on` entries need these transitive
    # inputs, and `lispDerivation` resolves a system's dependencies only from
    # the `lispDependencies` it is handed, so they have to be spelled here
    # (see `siblingsFor` below) or the build stops with missing component
    # errors.
    cl-codec-kit = {
      url = "github:nerima-lisp/cl-codec-kit/v0.5.0";
      flake = false;
    };
    cl-host-kit = {
      url = "github:nerima-lisp/cl-host-kit/v0.3.1";
      flake = false;
    };
    cl-history-kit = {
      url = "github:nerima-lisp/cl-history-kit/v1.0.4";
      flake = false;
    };
    cl-prolog-kit = {
      url = "github:nerima-lisp/cl-prolog-kit/v1.5.0";
      flake = false;
    };
    cl-cli = {
      url = "github:nerima-lisp/cl-cli/v1.3.0";
      flake = false;
    };
    cl-regex-kit = {
      url = "github:nerima-lisp/cl-regex-kit/v2.0.0";
      flake = false;
    };
    cl-date-kit = {
      url = "github:nerima-lisp/cl-date-kit/v1.0.0";
      flake = false;
    };
    cl-concurrent-kit = {
      url = "github:nerima-lisp/cl-concurrent-kit/v0.6.1";
      flake = false;
    };
    # cl-regex-kit's v2 :depends-on includes cl-parser-kit in addition to
    # cl-concurrent-kit, which loom also names directly. Keep the parser edge
    # explicit here so its ASDF component is available during the build.
    cl-parser-kit = {
      url = "github:nerima-lisp/cl-parser-kit/v1.1.1";
      flake = false;
    };
    cl-boundary-kit = {
      url = "github:nerima-lisp/cl-boundary-kit/v2.3.0";
      flake = false;
    };
    cl-json-kit = {
      url = "github:nerima-lisp/cl-json-kit/v1.2.0";
      flake = false;
    };
    cl-log-kit = {
      url = "github:nerima-lisp/cl-log-kit/v2.2.0";
      flake = false;
    };
    cl-process-kit = {
      url = "github:nerima-lisp/cl-process-kit/v3.2.0";
      flake = false;
    };
    cl-vcs-kit = {
      url = "github:nerima-lisp/cl-vcs-kit/v0.2.0";
      flake = false;
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-nix-forge,
      cl-weave,
      paredit-cli,
      cl-tty-kit,
      cl-codec-kit,
      cl-host-kit,
      cl-history-kit,
      cl-prolog-kit,
      cl-cli,
      cl-regex-kit,
      cl-date-kit,
      cl-concurrent-kit,
      cl-parser-kit,
      cl-boundary-kit,
      cl-json-kit,
      cl-log-kit,
      cl-process-kit,
      cl-vcs-kit,
      treefmt-nix,
      ...
    }:
    let
      lib = nixpkgs.lib;

      # Keep every tracked ASDF component, including split test files, and the
      # complete MkDocs input tree in the filtered source passed to
      # cl-nix-forge. The filter also keeps .git and generated output out of
      # the source hash.
      sourceRoot = builtins.path {
        path = ./.;
        name = "loom-lisp-source";
        filter =
          path: type:
          let
            pathName = builtins.baseNameOf (toString path);
            sourcePath = toString path;
            sourceFile = builtins.any (suffix: lib.hasSuffix suffix sourcePath) [
              ".asd"
              ".lisp"
              ".md"
              ".nix"
              ".yml"
              ".yaml"
              ".css"
              ".svg"
              ".png"
              ".jpg"
              ".jpeg"
              ".gif"
              ".webp"
              ".ico"
            ];
          in
          (
            type == "directory"
            && !(builtins.elem pathName [
              ".git"
              ".serena"
              ".worktrees"
              "coverage"
              "result"
            ])
          )
          || (type == "regular" && sourceFile);
      };

      # x86_64-linux is what CI gates; aarch64-darwin is the development
      # machine. Every per-system output -- packages, checks, apps AND
      # devShells -- comes from this one list, so leaving aarch64-darwin out
      # takes `nix build` and `nix develop` off the development machine as
      # well. That trade was made on 2026-08-01 and reverted on 2026-08-02;
      # aarch64-darwin carries no CI gate, which PACKAGE_STANDARD.md's
      # "systems" section accepts explicitly (see ../nshell/flake.nix's
      # identical comment). aarch64-linux and x86_64-darwin are nobody's
      # verification and are not declared.
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      meta = {
        description = "Terminal text editor with Emacs-like keybindings, written in Common Lisp";
        homepage = "https://github.com/nerima-lisp/loom";
        license = lib.licenses.mit;
        platforms = systems;
        mainProgram = "loom";
      };

      # Coverage is a separate derivation because it force-compiles the full
      # source graph with SB-COVER enabled and writes an HTML report. Keep its
      # timeout independent from the ordinary test gate: report generation
      # must not inherit a shorter interactive-test budget.
      coverage-timeout-seconds = 1800;
      coverage-entry-point-text = ''
        (load "scripts/coverage.lisp")
      '';

      # loom's runtime toolkit family, each built from its pinned checkout as
      # an SBCL lisp library. Built here rather than taken from each
      # sibling's own `packages.<system>` because the tags this repository
      # pins predate those repositories' migration to cl-nix-forge: at these
      # tags they publish nixpkgs `buildASDFSystem` derivations, which a
      # `lispDependencies` entry would have to be wrapped for one by one.
      # Building the source with `lispDerivation` is the same library doing
      # the same job, and it keeps every dependency's ASDF registry --
      # including the transitive ones -- computed in one place. See
      # ../nshell/flake.nix's `siblingsFor` for the identical precedent.
      #
      # A function of `ctx` because a derivation is per-system: the preset
      # spans systems and hands each callback the system it is building for.
      siblingsFor =
        ctx:
        let
          sibling =
            {
              name,
              source,
              dependencies ? [ ],
            }:
            ctx.cl.lispDerivation {
              pname = name;
              # Read out of the sibling's own .asd, never written here, so a
              # hand-copied version string cannot silently drift from it.
              version = ctx.cl.fromAsdSystem "${source}/${name}.asd";
              src = source;
              lispSystem = name;
              lispDependencies = dependencies;
            };
        in
        rec {
          clCodecKit = sibling {
            name = "cl-codec-kit";
            source = cl-codec-kit;
          };
          clTtyKit = sibling {
            name = "cl-tty-kit";
            source = cl-tty-kit;
            dependencies = [
              clCodecKit
              clConcurrentKit
            ];
          };
          clHostKit = sibling {
            name = "cl-host-kit";
            source = cl-host-kit;
          };
          clHistoryKit = sibling {
            name = "cl-history-kit";
            source = cl-history-kit;
          };
          clPrologKit = sibling {
            name = "cl-prolog-kit";
            source = cl-prolog-kit;
          };
          # cl-cli's own :depends-on is uiop (already in SBCL) plus
          # cl-host-kit on SBCL, so clHostKit above covers it.
          clCli = sibling {
            name = "cl-cli";
            source = cl-cli;
            dependencies = [ clHostKit ];
          };
          clParserKit = sibling {
            name = "cl-parser-kit";
            source = cl-parser-kit;
          };
          clRegexKit = sibling {
            name = "cl-regex-kit";
            source = cl-regex-kit;
            dependencies = [
              clConcurrentKit
              clParserKit
            ];
          };
          clBoundaryKit = sibling {
            name = "cl-boundary-kit";
            source = cl-boundary-kit;
            dependencies = [ clHostKit ];
          };
          clJsonKit = sibling {
            name = "cl-json-kit";
            source = cl-json-kit;
          };
          clDateKit = sibling {
            name = "cl-date-kit";
            source = cl-date-kit;
          };
          clConcurrentKit = sibling {
            name = "cl-concurrent-kit";
            source = cl-concurrent-kit;
            dependencies = [
              clBoundaryKit
              clDateKit
            ];
          };
          clLogKit = sibling {
            name = "cl-log-kit";
            source = cl-log-kit;
            dependencies = [
              clDateKit
              clConcurrentKit
              clHostKit
            ];
          };
          clProcessKit = sibling {
            name = "cl-process-kit";
            source = cl-process-kit;
            dependencies = [
              clBoundaryKit
              clLogKit
              clCodecKit
              clConcurrentKit
            ];
          };
          clVcsKit = sibling {
            name = "cl-vcs-kit";
            source = cl-vcs-kit;
            dependencies = [
              clProcessKit
              clHostKit
              clLogKit
            ];
          };
          # cl-weave is a dependency of `loom/test` only (see loom.asd), so it
          # is built here for `lispCheckDependencies` below; it must not enter
          # the delivered binary's closure.
          clWeave = sibling {
            name = "cl-weave";
            source = cl-weave;
          };
        };
    in
    # `mkPackageFlake` spans systems -- it obtains a `pkgs` and its own
    # cl-nix-forge instance per entry in `systems` -- so the per-system `lib`
    # instance this function is *taken from* contributes nothing but the
    # function itself.
    cl-nix-forge.lib.${builtins.head systems}.mkPackageFlake {
      inherit
        self
        systems
        nixpkgs
        meta
        ;
      pname = "loom";

      # Single source of truth for the package version: the `:version` form
      # in loom.asd. Every Nix package follows automatically, and
      # release.yml refuses to publish a tag that disagrees with it.
      asd = ./loom.asd;

      # `root` is a path because cl-nix-forge passes it to lib.fileset. The
      # filtered materialized source belongs in `src`, whose derivation API
      # accepts the string-like result of builtins.path.
      root = ./.;
      src = sourceRoot;

      lispDependencies =
        ctx: with siblingsFor ctx; [
          clTtyKit
          clHostKit
          clHistoryKit
          clPrologKit
          clCli
          clRegexKit
          clBoundaryKit
          clConcurrentKit
          clJsonKit
          clLogKit
          clVcsKit
        ];

      lispCheckDependencies = ctx: [ (siblingsFor ctx).clWeave ];

      # Drives `checks.default` and `apps.test` from this one number, so the
      # command a contributor runs by hand and the gate CI runs cannot drift
      # apart. Bounded so a hung suite fails in half an hour rather than
      # occupying a runner until GitHub's six-hour job ceiling.
      timeoutSeconds = 1800;

      # The delivered `loom` binary: `packages.default`, `apps.default` and
      # `apps.loom`, all built from the same `lispDerivation` arguments as
      # `packages.loom`. Nothing here repeats what loom.asd already declares
      # -- `:build-operation "program-op"`, `:build-pathname "loom"` and
      # `:entry-point "loom:main"` live in the system definition, as does the
      # `:perform` that dumps the image with `:compression t` (the one thing
      # `mkExecutable` cannot pass, and the reason that method exists).
      #
      # `installSource = false`: loom runs only what was dumped into the
      # image -- no code path loads an ASDF system at run time -- so shipping
      # the source closure beside the binary would buy nothing and cost the
      # whole closure.
      executable = {
        installSource = false;
      };

      # docs/mkdocs.yml + docs/src/, built with `--strict` so a broken link or
      # a page missing from the nav is a build failure. `checks.docs` comes
      # with it.
      docs = {
        root = ./docs;
        fileset = lib.fileset.unions [
          ./docs/mkdocs.yml
          ./docs/src
        ];
      };

      # ONE treefmt evaluation drives `nix fmt` and the `checks.formatting`
      # gate, so the formatter and CI can never disagree about what
      # "formatted" means. Scope is Nix only (the preset's default module):
      # nixfmt (RFC-style) is a zero-footgun, low-diff formatter, whereas a
      # YAML formatter would mangle the GitHub Actions `on:` key and a
      # Markdown formatter would churn the whole docs tree.
      treefmt.evalModule = treefmt-nix.lib.evalModule;

      # The cl-weave CLI and paredit's structural editor, both of which are
      # documented contributor tools. Interactive only: the generated shell
      # is built from the check-enabled derivation, so cl-weave's source for
      # the registry is already on it.
      devShellPackages = ctx: [
        cl-weave.packages.${ctx.system}.default
        paredit-cli.packages.${ctx.system}.default
        nixpkgs.legacyPackages.${ctx.system}.python3Packages.mkdocs-material
      ];

      overrideOutputs = ctx: {
        # The generated shell, plus the aliases this repository's
        # README documents. Appended to the preset's own shellHook rather
        # than replacing it, so the CL_SOURCE_REGISTRY it exports (the
        # derivation's own resolved registry, including check dependencies)
        # is kept.
        devShells.default = ctx.generated.devShells.default.overrideAttrs (previous: {
          shellHook = previous.shellHook + ''
            export LOOM_ROOT=$PWD
            alias test='cd "$LOOM_ROOT" && sbcl --script "$LOOM_ROOT/run-tests.lisp"'
            alias coverage='cd "$LOOM_ROOT" && LOOM_COVERAGE_DIR="$LOOM_ROOT/coverage" timeout --signal=TERM --kill-after=15s ${toString coverage-timeout-seconds}s sbcl --script "$LOOM_ROOT/scripts/coverage.lisp"'
            echo ""
            echo "loom development environment"
            echo "  test     - Run the full loom suite (cl-weave, loom/test)"
            echo "  coverage - Run the test suite and write HTML coverage to coverage/"
            echo "  sbcl     - Interactive Common Lisp (with cl-weave and paredit)"
            echo "  paredit  - Inspect and structurally edit Lisp source"
            echo ""
          '';
        });

        # The preset's script check copies the complete build directory into
        # its output.  The test run compiles FASLs in that directory, and
        # their compiler metadata is not a package artifact (nor stable
        # across two otherwise identical builds).  Keep the check as a pure
        # pass/fail gate and do not publish the mutable test worktree.
        #
        # LOOM_SANDBOXED_CHECK tells the suite it is running inside this
        # sandboxed derivation (t/test-helpers.lisp's %SANDBOXED-CHECK-P), so
        # the handful of tests that spawn a real child process over a PTY or
        # a pipe can SKIP -- visibly, in cl-weave's own "N skipped" count --
        # instead of hanging or failing. The Nix Linux build sandbox does not
        # reliably deliver real child-process I/O; see ci.yml's "a real
        # PTY/TTY" note for the org-level statement of that limitation.
        # `apps.test` and the dev shell's `test` alias do not set this, so
        # the same tests run for real everywhere else.
        checks.default = ctx.generated.checks.default.overrideAttrs (previous: {
          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            runHook postInstall
          '';
          LOOM_SANDBOXED_CHECK = "1";
        });
      };

      # Granularity lives here, NOT in extra GitHub Actions jobs: `nix flake
      # check` evaluates each attribute as its own derivation, in parallel,
      # with build caching.
      extraOutputs = ctx: {
        # Make the documented test derivation addressable through both
        # `nix run .#test` and `nix build .#test`. It is the same isolated
        # check as `checks.default`, with the same child-process skips.
        packages.test = ctx.generated.checks.default.overrideAttrs (previous: {
          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            runHook postInstall
          '';
          LOOM_SANDBOXED_CHECK = "1";
        });

        # Verify the delivered package compiles and the image dumps.
        checks.build = ctx.executable;

        # Expose the same isolated coverage derivation as a buildable package
        # and as a flake check. `ctx.cl.mkCoverageReport` supplies the package
        # source registry and both runtime/check dependency closures. Both
        # build inside the same PTY-less Nix sandbox as `checks.default`, so
        # they need the same LOOM_SANDBOXED_CHECK skip signal (see that
        # check's comment above).
        packages.coverage =
          (ctx.cl.mkCoverageReport {
            drv = ctx.package;
            entryPointText = coverage-entry-point-text;
            timeoutSeconds = coverage-timeout-seconds;
          }).overrideAttrs
            (previous: {
              LOOM_SANDBOXED_CHECK = "1";
            });
        checks.coverage =
          (ctx.cl.mkCoverageReport {
            drv = ctx.package;
            entryPointText = coverage-entry-point-text;
            timeoutSeconds = coverage-timeout-seconds;
          }).overrideAttrs
            (previous: {
              LOOM_SANDBOXED_CHECK = "1";
            });

        # Parse every filtered Lisp source file with the same structural tool
        # contributors use in the development shell. This catches unbalanced
        # forms and malformed reader structure before compilation.
        checks.paredit-lint = paredit-cli.lib.${ctx.system}.mkLintCheck {
          inherit (ctx) src;
          name = "loom-paredit-lint";
        };
      };
    };
}
