#!/bin/bash

# Debian-like dependencies from K's README.md at https://github.com/kframework/k5/blob/master/README.md (untested).
deps_deb=(build-essential m4 openjdk-8-jdk libgmp-dev libmpfr-dev pkg-config flex z3 libz3-dev maven opam)

# Chakra-like dependencies: Translated from Debian-like deps and tested by this script's author.
deps_chakra=(base-devel m4 openjdk gmp mpfr pkg-config flex maven opam)

# Output a message, highlighted for some chance of visibility in the middle of other output.
msg() {
    echo -e "\e[1m$*\e[0m"
}

# Install all the dependencies for a given distro before building and installing K.
install_deps() {
    case "$1" in
        Debian|*buntu)
            sudo apt-get install "${deps_deb[@]}" || exit 1
                ;;
        Arch|Chakra)
            sudo pacman --needed -S "${deps_chakra[@]}" || exit 1
            install_aur_z3-bin || exit 1
            ;;
        *)
            msg "Distro not supported!"
            exit 1
            ;;
    esac
}

# Manually download, build, and install Z3 from https://github.com/Z3Prover/z3
install_aur_z3-bin() {
    if pacman -Qi z3-bin >/dev/null; then
        return 0
    fi
    msg "Manually installing from Arch User Repository's 'z3-bin' package."
    tmp="$(mktemp -d)"
    cd "$tmp" || exit 1
    curl "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=z3-bin" > PKGBUILD || exit 1
    makepkg --install || exit 1
    msg "Removing temporary folder."
    cd - || exit 1
    rm -rf "$tmp" || exit 1
}

# Install the K Framework, version 5
install_k() {
    msg "Installing dependencies."
    install_deps "$1" || exit 1
    cd "$(dirname "$(readlink -f "$0")")" || exit 1
    if [ -d ./k5 ]; then
        msg "Updating K 5 clone."
        cd k5 || exit 1
        git pull origin master || exit 1
        cd - || exit 1
    else
        msg "Cloning K 5."
        git clone https://github.com/kframework/k5.git || exit 1
    fi
    msg "Building K."
    cd k5 || exit 1
    export maven_opts="-xx:+tieredcompilation" || exit 1
    mvn package || exit 1
    msg "Setting up OCAML backend."
    ./k-distribution/target/release/k/bin/k-configure-opam; eval "$(opam config env)" || exit 1
    msg "Running fast tests."
    mvn verify -DskipKTest || exit 1
    msg "Building release."
    mvn install || exit 1
}

# Check parameter existence and (run installation xor show usage message)
main() {
    if [ "$#" != "1" ]; then
        msg "Please specify a distro, either 'Chakra' or 'Debian'." >&2
        exit 1
    fi
    install_k "$1" || exit 1
}

# Run it
main "$@" || exit 1
