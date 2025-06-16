{
  inputs.basic-dev-shell.url = "github:necauqua/basic-dev-shell";
  outputs = { basic-dev-shell, ... }: basic-dev-shell.make (pkgs: with pkgs;
    {
      # this whole flake is only to have this for audio to work
      env.LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
        pkgsi686Linux.pulseaudio
      ];
      packages = [ just ];
    });
}
