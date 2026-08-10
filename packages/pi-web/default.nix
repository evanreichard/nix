{ lib
, buildNpmPackage
, fetchurl
, jq
, nodejs_22
,
}:

buildNpmPackage rec {
  pname = "pi-web";
  version = "0.8.7";

  # Published Tarball Instead Of Git - The npm artifact ships a prebuilt `.next`,
  # so we avoid `next build`, which needs network access to fetch Google fonts.
  src = fetchurl {
    url = "https://registry.npmjs.org/@agegr/pi-web/-/pi-web-${version}.tgz";
    hash = "sha256-EkssguOD03UMzlIRDFPQFOKCRMueat+ER9CkLA8t9og=";
  };

  nodejs = nodejs_22;

  # Vendored Lockfile - The tarball ships none, and upstream's committed lockfile
  # omits `integrity` for the nested @earendil-works packages, which breaks
  # fetchNpmDeps. Ours covers runtime deps only, so devDependencies are stripped
  # to keep `npm ci` in sync. Regenerate with ./update-lockfile.sh.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    ${jq}/bin/jq 'del(.devDependencies)' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  # Fetcher v1 misses the duplicated @earendil-works tarballs in the npm cache.
  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-JzzPfHzH1WQgDk8jQsgJSSkFE5sHvATkCqlBNugHWSc=";

  dontNpmBuild = true;

  meta = {
    description = "Local web UI for the pi coding agent";
    homepage = "https://github.com/agegr/pi-web";
    downloadPage = "https://www.npmjs.com/package/@agegr/pi-web";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "pi-web";
  };
}
