{ lib
, stdenv
, maven
, fetchFromGitHub
, jdk17
, jre
, swt
, makeWrapper
, wrapGAppsHook3
, pkg-config
, alsa-lib
, jack2
, fluidsynth
, libpulseaudio
, lilv
, suil
, qt5
, which
}:

maven.buildMavenPackage rec {
  pname = "tuxguitar";
  version = "2.0.1";

  src = fetchFromGitHub {
    owner = "helge17";
    repo = "tuxguitar";
    rev = version;
    hash = "sha256-USdYj8ebosXkiZpDqyN5J+g1kjyWm225iQlx/szXmLA=";
  };

  mvnHash = "sha256-XTODH8SG7iwhACJT4AbIokORUe00r6theV18TEXbrIs=";

  doCheck = false;

  mvnJdk = jdk17;

  nativeBuildInputs = [
    makeWrapper
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    fluidsynth
    jack2
    lilv
    qt5.qtbase
    suil
  ];

  mvnFetchExtraArgs = {
    inherit buildInputs;
    dontWrapQtApps = true;
  };

  postPatch = ''
    substituteInPlace desktop/build-scripts/native-modules/tuxguitar-synth-lv2-linux/pom.xml \
      --replace-fail /usr/include/lilv-0/lilv ${lib.getDev lilv}/include/lilv-0/lilv \
      --replace-fail /usr/include/suil-0/suil ${lib.getDev suil}/include/suil-0/suil

    if [[ "$name" == maven-deps-* ]]; then
      mvn install:install-file \
        -Dfile=${swt}/jars/swt.jar \
        -DgroupId=org.eclipse.swt \
        -DartifactId=org.eclipse.swt.gtk.linux \
        -Dpackaging=jar \
        -Dversion=4.36 \
        -Dmaven.repo.local=$out/.m2
    fi
  '';

  mvnParameters = "-f desktop/build-scripts/tuxguitar-linux-swt/pom.xml verify -P native-modules";

  dontWrapGApps = true;
  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r desktop/build-scripts/tuxguitar-linux-swt/target/tuxguitar-*-linux-swt/{dist,lib,share,tuxguitar.sh} $out/
    ln -sf ${swt}/jars/swt.jar $out/lib/swt.jar
    ln -s ../tuxguitar.sh $out/bin/tuxguitar

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/tuxguitar.sh \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ jre which ]} \
      --prefix LD_LIBRARY_PATH : "$out/lib:${lib.makeLibraryPath [
        swt
        alsa-lib
        fluidsynth
        jack2
        libpulseaudio
        lilv
        qt5.qtbase
        suil
      ]}"
  '';

  meta = {
    description = "Multitrack guitar tablature editor";
    homepage = "https://github.com/helge17/tuxguitar";
    license = lib.licenses.lgpl2;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "tuxguitar";
    platforms = lib.platforms.linux;
  };
}
