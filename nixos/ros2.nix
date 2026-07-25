{ config, pkgs, lib, ... }:

let
  nix-ros-overlay-src = builtins.fetchTarball {
    url = "https://github.com/lopsided98/nix-ros-overlay/archive/master.tar.gz";
    sha256 = "00f01wpx0qg5a6hmyqklqhhhbmx0afghhr79jc7y241zjav3d2l0";
  };

  rosPkgs = import nix-ros-overlay-src { };

  rosDistro = "jazzy";

  rosEnv = rosPkgs.rosPackages.${rosDistro}.buildEnv {
    paths = (with rosPkgs.rosPackages.${rosDistro}; [
      ros-core
      ros-base
      ros2cli
      ros2run
      ros2launch
      ros2topic
      ros2service
      ros2node
      ros2param
      ros2pkg
      ros2action
      ros2interface
      ros2lifecycle
      rclcpp
      rclpy
      ament-cmake
      ament-cmake-core
      python-cmake-module
      rosidl-default-generators
      rosidl-default-runtime
    ]) ++ [
      rosPkgs.colcon
    ];
  };
in
{
  nix.settings = {
    substituters = lib.mkAfter [
      "https://ros.cachix.org"
      "https://attic.iid.ciirc.cvut.cz/ros"
    ];
    trusted-public-keys = lib.mkAfter [
      "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo="
      "ros:JR95vUYsShSqfA1VTYoFt1Nz6uXasm5QrcOsGry9f6Q="
    ];
  };

  environment.systemPackages = [
    rosEnv
  ];

  environment.variables = {
    ROS_VERSION = "2";
    ROS_PYTHON_VERSION = "3";
  };
}
