"""
Canonical LG NetCast key map used by this project for 42LW5700-class TVs.

Primary sources used for this model family:
- Home Assistant forum, pre-2012 LG Smart TV command list including LW5700
  https://community.home-assistant.io/t/workaround-lg-tv-support/8929
- B4X forum snippet mirroring the older `lgremote` key definitions
  https://www.b4x.com/android/forum/threads/lg-tv-remote-app.27468/page-2

Note:
- This repo uses the legacy HDCP `HandleKeyInput` command path.
- 42LW5700-class pre-2012 TVs use the older small-integer key space such as
  `CH- = 1`, `VOL+ = 2`, `VOL- = 3`, `INPUT = 11`, `MENU = 67`.
- This is different from the newer NetCast UDAP virtual-key table.
"""

KEY_CODE = {
    # Channel / volume / power
    "CH+": 0,
    "CH_UP": 0,
    "CHANNEL_UP": 0,
    "CH-": 1,
    "CH_DOWN": 1,
    "CHANNEL_DOWN": 1,
    "VOL+": 2,
    "VOL_UP": 2,
    "VOL-": 3,
    "VOL_DOWN": 3,
    "POWER": 8,
    "MUTE": 9,

    # Inputs / setup
    "INPUT": 11,
    "EXTERNAL_INPUT": 11,
    "SOURCE": 11,
    "TV_RAD": 15,

    # Digits
    "0": 16,
    "1": 17,
    "2": 18,
    "3": 19,
    "4": 20,
    "5": 21,
    "6": 22,
    "7": 23,
    "8": 24,
    "9": 25,
    "LIST": 26,
    "Q_VIEW": 27,
    "FAV": 30,
    "TEXT": 32,
    "TELETEXT": 32,
    "T_OPT": 33,
    "STATUS_BAR": 35,
    "BACK": 40,

    # Navigation
    "RIGHT": 6,
    "LEFT": 7,
    "UP": 64,
    "DOWN": 65,
    "OK": 68,
    "ENTER": 68,
    "SELECT": 68,
    "EXIT": 91,

    # App / portal / menu
    "MENU": 67,
    "QUICK_MENU": 69,
    "HOME": 89,
    "NETCAST": 89,
    "PREMIUM": 89,
    "GUIDE": 169,
    "INFO": 170,

    # Colors
    "BLUE": 97,
    "YELLOW": 99,
    "GREEN": 113,
    "RED": 114,

    # Picture / sound
    "RATIO": 121,
    "ASPECT": 121,
    "SIMPLINK": 126,
    "AUDIO_DESCRIPTION": 145,
    "AD": 145,
    "ENERGY_SAVING": 149,
    "LIVE_TV": 158,
    "SUBTITLE": 57,

    # Component / HDMI direct selects seen in legacy maps
    "COMPONENT_RGB_HDMI": 152,
    "COMPONENT": 152,
    "RGB_HDMI": 152,
    "RGB_DVI": 153,
    "TV": 154,
    "HDMI": 155,
    "HDMI1": 206,
    "HDMI2": 207,
    "HDMI3": 208,
    "HDMI4": 209,

    # Playback
    "FAST_FORWARD": 142,
    "FF": 142,
    "REWIND": 143,
    "REW": 143,
    "PLAY": 176,
    "STOP": 177,
    "PAUSE": 186,
    "REC": 189,
    "RECORD": 189,

    # Model-specific extra key reported for pre-2012 family
    "3D": 220,
    "THREE_D": 220,
}
