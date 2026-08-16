name: Build and Release

on:
  push:
    branches:
      - main
    paths:
      - 'Tweak.xm'
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Install dependencies
        run: |
          brew install ldid dpkg
          echo "THEOS=$HOME/theos" >> $GITHUB_ENV

      - name: Setup Theos
        run: |
          git clone --depth 1 https://github.com/theos/theos.git $HOME/theos
          sudo ln -s $HOME/theos/bin/nic.pl /usr/local/bin/nic.pl || true

      - name: Build tweak
        run: |
          export THEOS="$HOME/theos"
          make clean
          make package
          echo "PACKAGE_PATH=$(ls packages/*.deb)" >> $GITHUB_ENV

      - name: Upload .deb artifact
        uses: actions/upload-artifact@v4
        with:
          name: ArtemisDiagnose.deb
          path: ${{ env.PACKAGE_PATH }}

      - name: Create Release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          files: ${{ env.PACKAGE_PATH }}
          generate_release_notes: true
