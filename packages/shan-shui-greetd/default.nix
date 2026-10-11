{ callPackage, fetchgit, ... }:
let
  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/shan-shui-greetd.git";
    rev = "18c4cf15c35117edd577c67e0e009bc3e5dfa37d";
    hash = "sha256-iCLC4UGrQy0+29qeK1gdsS2JI1fi5jkSCH5M07ImeeM=";
  };
in
callPackage "${src}/default.nix" { }
