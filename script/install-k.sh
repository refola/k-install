#!/bin/bash

# Debian-like dependencies: Copied from K's README.md at https://github.com/kframework/k5/blob/master/README.md and untested.
deps_deb=(build-essential m4 openjdk-8-jdk libgmp-dev libmpfr-dev pkg-config flex z3 libz3-dev maven opam)

# Chakra-like (Arch-like-like) dependencies: Translated from Debian-like deps and tested by this script's author.
deps_chakra=(base-devel m4 openjdk gmp mpfr pkg-config flex maven opam)

# Install all the dependencies for a given distro before building and installing K.
install_deps() {
    case "$1" in
        Debian)
            sudo apt-get install "${deps_deb[@]}" || exit 1
                ;;
        Chakra)
            sudo pacman --needed -S "${deps_chakra[@]}" || exit 1
            install_z3_manually || exit 1
            ;;
        *)
            echo "Distro not supported!"
            exit 1
            ;;
    esac
}

# Manually download, build, and install Z3 from https://github.com/Z3Prover/z3
install_z3_manually() {
    if pacman -Qi z3-bin; then
        return 0
    fi
    echo "Manually installing from Arch User Repository's 'z3-bin' package."
    tmp="$(mktemp -d)"
    cd "$tmp" || exit 1
    curl "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=z3-bin" > PKGBUILD || exit 1
    makepkg --install || exit 1
    echo "Removing temporary folder."
    cd - || exit 1
    rm -rf "$tmp" || exit 1
}

install() {
    echo "Installing dependencies."
    install_deps "$DISTRO" || exit 1
    echo "Cloning K 5."
    cd "$(dirname "$(readlink -f "$0")")" || exit 1
    git clone https://github.com/kframework/k5.git || exit 1
    echo "Building K."
    cd k5 || exit 1
    export maven_opts="-xx:+tieredcompilation" || exit 1
    mvn package || exit 1
    echo "Setting up OCAML backend."
    ./k-distribution/target/release/k/bin/k-configure-opam; eval `opam config env` || exit 1
    echo "Running fast tests."
    mvn verify -DskipKTest || exit 1
    echo "Building release."
    mvn install || exit 1
}

main() {
    if [ -z "$1" ]; then
        echo "Please specify a distro, either 'Chakra' or 'Debian'." >&2
        exit 1
    fi
    DISTRO="$1"
    install || exit 1
}

main "$@" || exit 1
