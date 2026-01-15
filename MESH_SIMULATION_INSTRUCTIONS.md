# Mesh Network Simulation Implementation Plan

This document outlines the instructions to build a NixOS Integration Test for simulating a mesh network with a "Master" node (Binary Cache/Gateway) and "Client" nodes.

## Objective
Create an interactive simulation environment to test:
1.  **Network Constraints:** Bandwidth limits (10 Mbit/s) and latency.
2.  **Binary Caching:** Clients pulling updates from the Master node via `harmonia`.
3.  **Air-Gapped Ops:** Master node acting as the sole source of truth when the internet is cut.

## Implementation Instructions

### 1. Create the Simulation File
Create a file at `tests/mesh-simulation.nix` with the following configuration:

*   **Structure:** A standard NixOS test returning `{ name, nodes, testScript }`.
*   **Nodes:**
    *   **`internet`**:
        *   IP: `192.168.1.1`
        *   Role: Upstream source (simulates `cache.nixos.org`).
        *   Service: Simple Nginx serving a "Hello" file or acting as a dummy upstream.
    *   **`master`**:
        *   IP (WAN): `192.168.1.2` (Connected to `internet`).
        *   IP (LAN): `10.0.0.1` (Connected to `clients`).
        *   Role: Gateway and Binary Cache.
        *   Service: `services.harmonia` enabled on port 5000.
        *   Firewall: Allow TCP 5000.
    *   **`client1`** & **`client2`**:
        *   IP: `10.0.0.2`, `10.0.0.3` etc.
        *   Role: End-user nodes.
        *   Configuration:
            *   `nix.settings.substituters = [ "http://10.0.0.1:5000" ];`
            *   `nix.settings.connect-timeout = 5;` (Fail fast if Master is down).

### 2. Implement the Test Script (Python)
The `testScript` string should provide an interactive Python environment.

*   **Helper Functions:**
    *   `setup_bandwidth_limit(node, interface, rate="10mbit")`: Use `tc` commands to enforce limits.
    *   `print_status()`: A function to ping between nodes and print a status report.
*   **Initialization:**
    *   Call `start_all()`.
    *   Apply bandwidth limits to `master` (LAN interface) and `clients`.
    *   Print the initial status.

### 3. Integrate into `flake.nix`
Update `flake.nix` to expose the test as a check or an app.

*   **Action:** Add the following to the `checks` output for `x86_64-linux`:
    ```nix
    mesh-simulation = pkgs.nixosTest (import ./tests/mesh-simulation.nix { inherit pkgs; });
    ```

### 4. Running the Simulation
Describe the commands to run the simulation:

*   **Non-Interactive (Automated Test):**
    ```bash
    nix flake check .#mesh-simulation
    ```
*   **Interactive (The "Lab"):**
    ```bash
    nix build .#checks.x86_64-linux.mesh-simulation.driverInteractive
    ./result/bin/nixos-test-driver
    ```

## Example `tests/mesh-simulation.nix` Content

```nix
{ pkgs, ... }:

let
  meshCommon = { pkgs, config, lib, ... }: {
    networking.firewall.enable = false;
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    documentation.enable = false;
  };

in {
  name = "mesh-airgap-simulation";

  nodes = {
    internet = { config, pkgs, ... }: {
      networking.interfaces.eth1.ipv4.addresses = [{ address = "192.168.1.1"; prefixLength = 24; }];
      services.nginx = {
        enable = true;
        virtualHosts."cache.nixos.org".locations."/".return = "200 'Internet Reachable'";
      };
    };

    master = { config, pkgs, ... }: {
      imports = [ meshCommon ];
      networking.interfaces.eth1.ipv4.addresses = [{ address = "192.168.1.2"; prefixLength = 24; }]; # WAN
      networking.interfaces.eth2.ipv4.addresses = [{ address = "10.0.0.1"; prefixLength = 24; }];    # LAN
      
      services.harmonia = {
        enable = true;
        settings.bind = "0.0.0.0:5000";
      };
      networking.firewall.allowedTCPPorts = [ 5000 ];
    };

    client1 = { config, pkgs, ... }: {
      imports = [ meshCommon ];
      networking.interfaces.eth1.ipv4.addresses = [{ address = "10.0.0.2"; prefixLength = 24; }];
      nix.settings.substituters = pkgs.lib.mkForce [ "http://10.0.0.1:5000" ];
    };
  };

  testScript = ''
    start_all()
    
    # Apply 10Mbit limit
    master.succeed("tc qdisc add dev eth2 root tbf rate 10mbit burst 32kbit latency 400ms")
    client1.succeed("tc qdisc add dev eth1 root tbf rate 10mbit burst 32kbit latency 400ms")

    print("Simulation Ready. Master: 10.0.0.1, Client1: 10.0.0.2")
  '';
}
```
