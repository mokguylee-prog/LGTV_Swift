# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['/Users/kadelee/Developer/LGTV/lg_remote_template.py'],
    pathex=[],
    binaries=[],
    datas=[('/Users/kadelee/Developer/LGTV/assets', 'assets')],
    hiddenimports=['rumps', 'AppKit', 'Foundation', 'objc'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='LG NetCast Remote',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['/Users/kadelee/Developer/LGTV/assets/LGNetCast.icns'],
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='LG NetCast Remote',
)
app = BUNDLE(
    coll,
    name='LG NetCast Remote.app',
    icon='/Users/kadelee/Developer/LGTV/assets/LGNetCast.icns',
    bundle_identifier='com.kadelee.lgnetcast.menubar',
)
