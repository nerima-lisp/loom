{
  description = "Terminal text editor with Emacs-like keybindings in Common Lisp";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Sibling packages are ALWAYS pinned to a release tag. A bare
    # `github:nerima-lisp/cl-tty-kit` follows that repo's default branch,
    # which means an upstream push to main breaks this repo's CI without
    # warning. Only cl-weave is consumed as a flake (it is used as a built
    # test dependency, not merely a source tree), so it alone carries the
    # mandatory `inputs.nixpkgs.follows` -- without it, it would drag in its
    # own nixpkgs, inflating flake.lock and rebuilding the same derivations.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # loom's runtime dependencies. We only need each one's source tree
    # (built below as an SBCL lisp library via buildASDFSystem), so they are
    # consumed as non-flake sources. `flake = false` reaches the same goal
    # `inputs.nixpkgs.follows` exists for, and reaches it more completely: a
    # non-flake input has no inputs of its own, so it cannot contribute a
    # second nixpkgs to flake.lock at all.
    cl-tty-kit = {
      url = "github:nerima-lisp/cl-tty-kit/v1.4.0";
      flake = false;
    };
    # Not a dependency loom names anywhere: cl-tty-kit v1.4.0's own
    # `:depends-on ("cl-codec-kit")` needs it, and `buildASDFSystem` resolves a
    # system's dependencies only from the `lispLibs` it is handed, so a
    # transitive edge has to be spelled here or the build stops with
    # `Component "cl-codec-kit" not found, required by #<SYSTEM "cl-tty-kit">`.
    cl-codec-kit = {
      url = "github:nerima-lisp/cl-codec-kit/v0.4.0";
      flake = false;
    };
    cl-host-kit = {
      url = "github:nerima-lisp/cl-host-kit/v0.3.0";
      flake = false;
    };
    cl-history-kit = {
      url = "github:nerima-lisp/cl-history-kit/v1.0.2";
      flake = false;
    };
    cl-prolog = {
      url = "github:nerima-lisp/cl-prolog/v1.4.0";
      flake = false;
    };
    cl-cli = {
      url = "github:nerima-lisp/cl-cli/v1.3.0";
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
      cl-weave,
      cl-tty-kit,
      cl-codec-kit,
      cl-host-kit,
      cl-history-kit,
      cl-prolog,
      cl-cli,
      treefmt-nix,
      ...
    }:
    let
      # x86_64-linux is what CI gates; aarch64-darwin is the development
      # machine. Every per-system output -- packages, checks, apps AND devShells
      # -- comes from this one list, so leaving aarch64-darwin out takes `nix
      # build` and `nix develop` off the development machine as well. That trade
      # was made on 2026-08-01 and reverted on 2026-08-02; aarch64-darwin carries
      # no CI gate, which PACKAGE_STANDARD.md's "systems" section accepts
      # explicitly. aarch64-linux and x86_64-darwin are nobody's verification and
      # are not declared.
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Read an ASDF system's `:version` out of its .asd file. Nix regexes are
      # whole-string anchored and `.` never spans newlines, so the version is
      # extracted line-by-line rather than with one multi-line match.
      asdVersionOf =
        file:
        let
          lines = nixpkgs.lib.splitString "\n" (builtins.readFile file);
          versionLine = builtins.head (
            builtins.filter (line: builtins.match "[[:space:]]*:version \"[^\"]*\"" line != null) lines
          );
        in
        builtins.head (builtins.match "[[:space:]]*:version \"([^\"]*)\"" versionLine);

      # Single source of truth for the package version: the `:version` form
      # in loom.asd. Every Nix package follows automatically.
      version = asdVersionOf ./loom.asd;

      # Compiled Lisp artefacts must never enter the store: a stale .fasl from
      # a local REPL session would be preferred over the source beside it.
      sourceFor =
        pkgs:
        pkgs.lib.cleanSourceWith {
          src = ./.;
          filter =
            path: type:
            (pkgs.lib.cleanSourceFilter path type)
            && (
              let
                name = builtins.baseNameOf path;
              in
              !(
                pkgs.lib.hasSuffix ".fasl" name
                || pkgs.lib.hasSuffix ".cfasl" name
                || pkgs.lib.hasSuffix ".dfsl" name
                || pkgs.lib.hasSuffix ".ufasl" name
                || pkgs.lib.hasSuffix ".core" name
                || pkgs.lib.hasSuffix ".o" name
              )
            );
        };

      # CL_SOURCE_REGISTRY for every non-sandboxed entry point (dev shell) and
      # for the source-registry-based checks. Each .asd sits at the root of
      # its own tree. Defined once so a newly adopted dependency cannot be
      # added to the build but forgotten here.
      depSources = [
        cl-weave
        cl-tty-kit
        cl-codec-kit
        cl-host-kit
        cl-history-kit
        cl-prolog
        cl-cli
      ];
      depRegistry = nixpkgs.lib.concatMapStrings (dep: "${dep}//:") depSources;

      # loom's runtime dependencies, each built as an SBCL lisp
      # library. Defined once and consumed by both `packages` and `checks`.
      lispLibsFor =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # cl-tty-kit's own `:depends-on ("cl-codec-kit")`. `buildASDFSystem`
          # resolves a system's dependencies from its `lispLibs` alone, so the
          # edge has to be built here and handed over explicitly; it is not
          # discovered from the .asd.
          clCodecKit = pkgs.sbcl.buildASDFSystem {
            pname = "cl-codec-kit";
            version = asdVersionOf "${cl-codec-kit}/cl-codec-kit.asd";
            src = cl-codec-kit;
            systems = [ "cl-codec-kit" ];
          };
          clTtyKit = pkgs.sbcl.buildASDFSystem {
            pname = "cl-tty-kit";
            version = asdVersionOf "${cl-tty-kit}/cl-tty-kit.asd";
            src = cl-tty-kit;
            systems = [ "cl-tty-kit" ];
            lispLibs = [ clCodecKit ];
          };
          clHostKit = pkgs.sbcl.buildASDFSystem {
            pname = "cl-host-kit";
            version = asdVersionOf "${cl-host-kit}/cl-host-kit.asd";
            src = cl-host-kit;
            systems = [ "cl-host-kit" ];
          };
          clHistoryKit = pkgs.sbcl.buildASDFSystem {
            pname = "cl-history-kit";
            version = asdVersionOf "${cl-history-kit}/cl-history-kit.asd";
            src = cl-history-kit;
            systems = [ "cl-history-kit" ];
          };
          clProlog = pkgs.sbcl.buildASDFSystem {
            pname = "cl-prolog";
            version = asdVersionOf "${cl-prolog}/cl-prolog.asd";
            src = cl-prolog;
            systems = [ "cl-prolog" ];
          };
          # cl-cli's own :depends-on is uiop (already in SBCL) plus
          # cl-host-kit on SBCL, so clHostKit above covers it; no extra
          # transitive edge needs spelling out here the way cl-tty-kit's did.
          clCli = pkgs.sbcl.buildASDFSystem {
            pname = "cl-cli";
            version = asdVersionOf "${cl-cli}/cl-cli.asd";
            src = cl-cli;
            systems = [ "cl-cli" ];
            lispLibs = [ clHostKit ];
          };
        in
        [
          clTtyKit
          clHostKit
          clHistoryKit
          clProlog
          clCli
        ];

      # treefmt drives `nix fmt` and the `checks.<system>.formatting` gate.
      # Scope is Nix only: nixfmt (RFC-style) is a zero-footgun, low-diff
      # formatter.
      treefmtEval = forAllSystems (
        system:
        treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        }
      );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          src = sourceFor pkgs;
        in
        rec {
          loom = pkgs.sbcl.buildASDFSystem {
            pname = "loom";
            inherit version;
            inherit src;
            systems = [ "loom" ];
            lispLibs = lispLibsFor system;
            buildScript = pkgs.writeText "build-loom.lisp" ''
              (require :asdf)
              (setf asdf:*compile-file-warnings-behaviour* :warn)
              (setf asdf:*compile-file-failure-behaviour* :warn)
              (push (truename "./") asdf:*central-registry*)
              (asdf:load-system :loom)
              (sb-ext:save-lisp-and-die "loom"
                :executable t
                :compression t
                ;; Stop the SBCL C runtime from intercepting --version/--help
                ;; and other runtime flags before loom:main runs.
                :save-runtime-options t
                :toplevel #'loom:main)
            '';
            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              cp loom $out/bin/
              runHook postInstall
            '';
            meta = {
              description = "Terminal text editor with Emacs-like keybindings, written in Common Lisp";
              homepage = "https://github.com/nerima-lisp/loom";
              license = pkgs.lib.licenses.mit;
              platforms = systems;
              mainProgram = "loom";
            };
          };
          default = loom;

          # Rendered documentation site (Material for MkDocs).
          # Build fully offline: Material for MkDocs bundles all of its assets,
          # so no network access is required inside the Nix sandbox. --strict
          # promotes broken links and unlisted pages to build failures.
          docs = pkgs.stdenvNoCC.mkDerivation {
            pname = "loom-docs";
            inherit version;
            src = pkgs.lib.fileset.toSource {
              root = ./docs;
              fileset = pkgs.lib.fileset.unions [
                ./docs/mkdocs.yml
                ./docs/src
              ];
            };
            nativeBuildInputs = [ pkgs.python3Packages.mkdocs-material ];
            buildPhase = ''
              runHook preBuild
              mkdocs build --strict --config-file mkdocs.yml --site-dir "$out"
              runHook postBuild
            '';
            dontInstall = true;
            meta = {
              description = "Rendered MkDocs (Material) documentation for loom";
              homepage = "https://github.com/nerima-lisp/loom";
              license = pkgs.lib.licenses.mit;
            };
          };
        }
      );

      # `nix fmt` entry point.
      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

      # Granularity lives here, NOT in extra GitHub Actions jobs: `nix flake
      # check` evaluates each attribute as its own derivation, in parallel,
      # with build caching.
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          src = sourceFor pkgs;
          runSuite =
            name: script:
            pkgs.runCommand "loom-${name}"
              {
                nativeBuildInputs = [
                  pkgs.sbcl
                  pkgs.coreutils
                ];
              }
              ''
                cp -R ${src} source
                chmod -R u+w source
                cd source
                export HOME="$TMPDIR/home"
                export XDG_CACHE_HOME="$TMPDIR/cache"
                mkdir -p "$HOME" "$XDG_CACHE_HOME"
                export CL_SOURCE_REGISTRY="${depRegistry}$PWD//:"
                # Bounded so a hung suite fails in half an hour rather than
                # occupying a runner until GitHub's six-hour job ceiling.
                timeout 1800 sbcl --script ${script}
                touch $out
              '';
        in
        {
          # The primary regression suite, through the same run-tests.lisp
          # entry point a developer runs locally.
          default = runSuite "tests" "run-tests.lisp";

          # Verify the default package compiles and the image dumps.
          build = self.packages.${system}.default;

          # Fails `nix flake check` when any tracked file is unformatted,
          # turning the formatter into an enforced CI gate.
          formatting = treefmtEval.${system}.config.build.check self;

          # The docs package builds with `mkdocs --strict`, so a broken link or
          # a page missing from the nav fails the build. Without this the docs
          # are only ever built by the publish workflow, which runs after a
          # merge to main, meaning such a break surfaces as a failed deploy
          # rather than as a failed pull request.
          docs = self.packages.${system}.docs;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          test = pkgs.writeShellApplication {
            name = "loom-test";
            runtimeInputs = [
              pkgs.sbcl
              pkgs.coreutils
            ];
            text = ''
              export CL_SOURCE_REGISTRY="${depRegistry}${self}//:"
              cd "${self}"
              exec timeout 1800 sbcl --script run-tests.lisp
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/loom";
          };
          test = {
            type = "app";
            program = "${test}/bin/loom-test";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.sbcl
              cl-weave.packages.${system}.default
            ];
            shellHook = ''
              # Resolve every dependency from its source checkout: cl-weave,
              # the rest of the toolkit family, and loom itself. Each .asd
              # sits at the root of its tree.
              export CL_SOURCE_REGISTRY="${depRegistry}$PWD//:''${CL_SOURCE_REGISTRY:-}"
              export LOOM_ROOT=$PWD
              alias test='cd "$LOOM_ROOT" && sbcl --script "$LOOM_ROOT/run-tests.lisp"'
              echo ""
              echo "loom development environment"
              echo "  test - Run the full loom suite (cl-weave, loom/test)"
              echo "  sbcl - Interactive Common Lisp (with cl-weave)"
              echo ""
            '';
          };
        }
      );
    };
}
