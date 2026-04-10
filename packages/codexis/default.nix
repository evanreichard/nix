{ lib
, buildGoModule
, fetchgit
}:

buildGoModule rec {
  pname = "codexis";
  version = "unstable-2026-04-10";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/codexis.git";
    rev = "39fcfc296857f52b962388e454f8161ff0442d23";
    hash = "sha256-B1VKY82tBxkd/L71Lq8Hh+1whQ03DzddkTcR82a+YXk=";
  };

  vendorHash = "sha256-8B1utE6bicIn1YO0qIcZhF7RaIK5cOu1/vm41EG+yyQ=";

  subPackages = [ "." ];

  meta = {
    description = "Code index database tool using tree-sitter";
    homepage = "https://gitea.va.reichard.io/evan/codexis";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "codexis";
  };
}
