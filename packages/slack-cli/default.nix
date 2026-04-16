{ lib
, fetchgit
, fetchurl
, python312
, snappy
,
}:

let
  pythonPackages = python312.pkgs;

  # ── Python Dependency Overrides ──────────────────────────────
  #
  # dfindexeddb pins python-snappy==0.6.1 and zstd==1.5.5.1.
  # nixpkgs ships newer versions, so we build the exact pins
  # from PyPI source tarballs.

  python-snappy = pythonPackages.buildPythonPackage rec {
    pname = "python-snappy";
    version = "0.6.1";
    format = "setuptools";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/98/7a/44a24bad98335b2c72e4cadcdecf79f50197d1bab9f22f863a274f104b96/python-snappy-0.6.1.tar.gz";
      hash = "sha256-tqEHqwYgasxTWdTFYyvZsi1EhwKnmzFpsMYuD7gIuyo=";
    };

    buildInputs = [ snappy ];

    doCheck = false;
  };

  zstd-python = pythonPackages.buildPythonPackage rec {
    pname = "zstd";
    version = "1.5.5.1";
    format = "setuptools";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/source/z/zstd/zstd-1.5.5.1.tar.gz";
      hash = "sha256-HvmAq/Dh4HKwKNLXbvlbR2YyZRyWIlzzC2Gcbu9iVnI=";
    };

    doCheck = false;
  };

  dfindexeddb = pythonPackages.buildPythonPackage rec {
    pname = "dfindexeddb";
    version = "20260210";
    format = "setuptools";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/source/d/dfindexeddb/dfindexeddb-20260210.tar.gz";
      hash = "sha256-4ahEe4Lpoh0oqGR6kI7J1HEGfvKVEzu3qQ+3ykgFd/Y=";
    };

    propagatedBuildInputs = [
      python-snappy
      zstd-python
    ];

    doCheck = false;
  };

in
pythonPackages.buildPythonApplication {
  pname = "slack-cli";
  version = "0.1.0";
  format = "pyproject";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/slack-cli.git";
    rev = "b06604788efc9f6e889a2cb1a24f7067e7c94775";
    hash = "sha256-sM3Dd9QNzQmOT3PrBmUUt7Zrowo9JdmCEAAGRi8O7aY=";
  };

  build-system = [ pythonPackages.setuptools ];

  dependencies = [ dfindexeddb ];

  doCheck = false;

  meta = {
    description = "Read Slack messages from local Chromium IndexedDB cache";
    homepage = "https://gitea.va.reichard.io/evan/slack-cli";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "slack-cli";
    platforms = lib.platforms.darwin;
  };
}
