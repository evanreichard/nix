{ inputs, ... }:
final: _prev: {
  firefox-addons = inputs.firefox-addons.packages.${final.system};
}
