{
  programs.btop = {
    enable = true;
  };

  home.file.".config/btop/btop.conf".text =
    builtins.readFile ./config/btop.conf;
  home.file.".config/btop/themes/catppuccin_mocha.theme".text =
    builtins.readFile ./config/catppuccin_mocha.theme;
}
