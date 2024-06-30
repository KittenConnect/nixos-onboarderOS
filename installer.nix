{ lib, pkgs, system, modulesPath, ... }: {
  nixpkgs.hostPlatform = system;

  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  networking.hostName = lib.mkDefault "kitteNixOS-installer";

  environment.systemPackages = with pkgs; [
    wireguard-tools
    iproute2
    tmux

    interactiveTmux
    interactiveScript
  ];

  systemd.tmpfiles.rules = [ "d /var/shared 0777 root root - -" ];
  services.openssh.settings.PermitRootLogin = "yes";
  system.activationScripts.root-password = ''
    mkdir -p /var/shared
    ${pkgs.xkcdpass}/bin/xkcdpass --numwords 3 --delimiter - --count 1 > /var/shared/root-password
    echo "root:$(cat /var/shared/root-password)" | chpasswd
  '';

  console.earlySetup = true;
  console.font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-u22n.psf.gz";

# No one got time for xz compression.
  isoImage.squashfsCompression = "zstd";
  
# Less ipv6 addresses to reduce the noise
  networking.tempAddresses = "disabled";

  # Tango theme: https://yayachiken.net/en/posts/tango-colors-in-terminal/
  console.colors = lib.mkDefault [
    "000000"
    "CC0000"
    "4E9A06"
    "C4A000"
    "3465A4"
    "75507B"
    "06989A"
    "D3D7CF"
    "555753"
    "EF2929"
    "8AE234"
    "FCE94F"
    "739FCF"
    "AD7FA8"
    "34E2E2"
    "EEEEEC"
  ];

  services.getty.autologinUser = lib.mkForce "root";
  programs.bash.interactiveShellInit = ''
    if [[ "$(tty)" =~ /dev/(tty1|hvc0|ttyS0)$ ]]; then
      # workaround for https://github.com/NixOS/nixpkgs/issues/219239
      systemctl restart systemd-vconsole-setup.service

      ${pkgs.neofetch}/bin/neofetch

      ${pkgs.interactiveTmux}/bin/interactiveTmux.sh
      exit $?
    fi
  '';

  # Fallback quickly if substituters are not available.
  nix.settings.connect-timeout = 5;

  # Enable flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "repl-flake"
  ];

  # Not really needed. Saves a few bytes and the only service we are running is sshd, which we want to be reachable.
  networking.firewall.enable = false;

  networking.useNetworkd = true;
  systemd.network.enable = true;

  # mdns
  # networking.firewall.allowedUDPPorts = [ 5353 ];
  systemd.network.networks."99-ethernet-default-dhcp".networkConfig.MulticastDNS = lib.mkDefault "yes";
  systemd.network.networks."99-wireless-client-dhcp".networkConfig.MulticastDNS = lib.mkDefault "yes";
}
