name: Build and Release

on:
  push:
    branches: [ main ]
    paths:
      - 'Tweak.xm'
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

      - name: Install Theos dependencies
        run: |
          brew install dpkg ldid
          git clone --recursive https://github.com/theos/theos.git "$HOME/theos"

      - name: Verify Theos installation
        run: |
          ls -l $HOME/theos/bin/dm.pl   # 检查 dm.pl 是否存在

      - name: Build package
        run: |
          export THEOS="$HOME/theos"
          make package FINALPACKAGE=1 THEOS="$THEOS"   # 显式传递 THEOS

      - name: Upload deb
        uses: actions/upload-artifact@v4
        with:
          name: ArtemisDiagnose.deb
          path: packages/*.deb
