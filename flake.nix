{
  description = "Terminal text editor with Emacs-like keybindings in Common Lisp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.paredit-cli.follows = "paredit-cli";
    };

    paredit-cli = {
      url = "github:nerima-lisp/paredit-cli/v1.6.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-tty-kit = {
      url = "github:nerima-lisp/cl-tty-kit/v1.6.1";
      flake = false;
    };
    # cl-tty-kit requires these transitive libraries explicitly.
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
    # cl-regex-kit requires cl-parser-kit explicitly.
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
    cl-resilience-kit = {
      url = "github:nerima-lisp/cl-resilience-kit/v1.0.0";
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
      cl-resilience-kit,
      treefmt-nix,
      ...
    }:
    let
      lib = nixpkgs.lib;

      # Keep source, documentation, and build inputs while excluding outputs.
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

      # CI targets Linux; aarch64-darwin is the development platform.
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

      # Coverage needs an independent timeout for report generation.
      coverage-timeout-seconds = 1800;
      coverage-entry-point-text = ''
        (load "scripts/coverage.lisp")
      '';

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
          clResilienceKit = sibling {
            name = "cl-resilience-kit";
            source = cl-resilience-kit;
            dependencies = [
              clBoundaryKit
              clConcurrentKit
              clDateKit
            ];
          };
          # cl-weave is test-only.
          clWeave = sibling {
            name = "cl-weave";
            source = cl-weave;
          };
        };
    in
    cl-nix-forge.lib.${builtins.head systems}.mkPackageFlake {
      inherit
        self
        systems
        nixpkgs
        meta
        ;
      pname = "loom";

      asd = ./loom.asd;

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
          clProcessKit
          clVcsKit
          clResilienceKit
        ];

      lispCheckDependencies = ctx: [ (siblingsFor ctx).clWeave ];

      # Share one bounded timeout between tests and CI.
      timeoutSeconds = 1800;

      # The binary runs from the dumped image and does not install source.
      executable = {
        installSource = false;
      };

      docs = {
        root = ./docs;
        fileset = lib.fileset.unions [
          ./docs/mkdocs.yml
          ./docs/src
        ];
      };

      treefmt.evalModule = treefmt-nix.lib.evalModule;

      devShellPackages =
        ctx:
        let
          pkgs = nixpkgs.legacyPackages.${ctx.system};
          loom-test = pkgs.writeShellScriptBin "loom-test" ''
            exec sbcl --script "$PWD/run-tests.lisp" "$@"
          '';
          loom-coverage = pkgs.writeShellScriptBin "loom-coverage" ''
            exec env LOOM_COVERAGE_DIR="''${LOOM_COVERAGE_DIR:-$PWD/coverage}" \
              timeout --signal=TERM --kill-after=15s ${toString coverage-timeout-seconds}s \
              sbcl --script "$PWD/scripts/coverage.lisp" "$@"
          '';
        in
        [
          cl-weave.packages.${ctx.system}.default
          paredit-cli.packages.${ctx.system}.default
          nixpkgs.legacyPackages.${ctx.system}.python3Packages.mkdocs-material
          (pkgs.python3.withPackages (ps: [ ps.pyte ]))
          loom-test
          loom-coverage
        ];

      overrideOutputs = ctx: {
        # Preserve the preset shell hook and its source registry.
        devShells.default = ctx.generated.devShells.default.overrideAttrs (previous: {
          shellHook = previous.shellHook + ''
            export LOOM_ROOT=$PWD
            alias test='cd "$LOOM_ROOT" && sbcl --script "$LOOM_ROOT/run-tests.lisp"'
            alias coverage='cd "$LOOM_ROOT" && LOOM_COVERAGE_DIR="$LOOM_ROOT/coverage" timeout --signal=TERM --kill-after=15s ${toString coverage-timeout-seconds}s sbcl --script "$LOOM_ROOT/scripts/coverage.lisp"'
            echo ""
            echo "loom development environment"
            echo "  loom-test     - Run the full loom suite (also works with nix develop -c)"
            echo "  loom-coverage - Run the test suite and write HTML coverage to coverage/"
            echo "  sbcl     - Interactive Common Lisp (with cl-weave and paredit)"
            echo "  paredit  - Inspect and structurally edit Lisp source"
            echo ""
          '';
        });

        # Skip child-process PTY tests that cannot run in the Nix sandbox.
        checks.default = ctx.generated.checks.default.overrideAttrs (previous: {
          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            runHook postInstall
          '';
          LOOM_SANDBOXED_CHECK = "1";
        });
      };

      extraOutputs = ctx: {
        packages.test = ctx.generated.checks.default.overrideAttrs (previous: {
          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            runHook postInstall
          '';
          LOOM_SANDBOXED_CHECK = "1";
        });

        checks.build = ctx.executable;

        # Run PTY tests outside the Nix sandbox.
        apps.e2e =
          let
            pkgs = nixpkgs.legacyPackages.${ctx.system};
            python = pkgs.python3.withPackages (ps: [ ps.pyte ]);
          in
          {
            type = "app";
            program = toString (
              pkgs.writeShellScript "loom-e2e" ''
                export PATH="${pkgs.nixd}/bin:$PATH"
                export LOOM_BINARY="${ctx.executable}/bin/loom"
                exec "${python}/bin/python3" "${self}/t/e2e/loom-test.py" "$@"
              ''
            );
          };

        # Coverage runs in the Nix sandbox and needs the skip signal.
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

        checks.paredit-lint = paredit-cli.lib.${ctx.system}.mkLintCheck {
          inherit (ctx) src;
          name = "loom-paredit-lint";
        };
      };
    };
}
