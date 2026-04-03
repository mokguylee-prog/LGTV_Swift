import tkinter as tk

from lg_keymap import KEY_CODE


APP_BG = "#202020"
REMOTE_BODY_BG = "#070707"
REMOTE_INNER_BG = "#111111"
REMOTE_EDGE = "#2c2c2c"
LIGHT_BTN_BG = "#f0efe8"
LIGHT_BTN_ACTIVE_BG = "#e0ddd3"
LIGHT_BTN_FG = "#222222"
LIGHT_BTN_BORDER = "#575757"
LIGHT_BTN_DISABLED_FG = "#9b968c"
DARK_BTN_BG = "#171717"
DARK_BTN_ACTIVE_BG = "#262626"
DARK_BTN_FG = "#f1f1f1"
DARK_BTN_BORDER = "#303030"
DARK_BTN_DISABLED_FG = "#7c7c7c"
SIDE_BTN_BG = "#78a4eb"
SIDE_BTN_ACTIVE_BG = "#638fd6"
SIDE_BTN_FG = "#132235"
SIDE_BTN_BORDER = "#47699e"
CAPTION_FG = "#b9b9b9"
LOGO_FG = "#ebebeb"


class SkinButton(tk.Frame):
    def __init__(
        self,
        parent,
        *,
        text: str,
        command,
        width: int,
        height: int,
        bg: str,
        fg: str,
        border: str,
        active_bg: str | None = None,
        disabled_fg: str | None = None,
        font=("Helvetica", 10, "bold"),
        justify: str = "center",
    ):
        super().__init__(parent, bg=border, width=width, height=height, bd=0, highlightthickness=0)
        self.pack_propagate(False)
        self.grid_propagate(False)
        self._command = command
        self._enabled = True
        self._bg = bg
        self._fg = fg
        self._active_bg = active_bg or bg
        self._disabled_fg = disabled_fg or fg
        self.configure(cursor="hand2")

        self._face = tk.Label(
            self,
            text=text,
            bg=bg,
            fg=fg,
            font=font,
            justify=justify,
            bd=0,
            relief="flat",
        )
        self._face.pack(expand=True, fill="both", padx=1, pady=1)

        for widget in (self, self._face):
            widget.bind("<Enter>", self._on_enter)
            widget.bind("<Leave>", self._on_leave)
            widget.bind("<Button-1>", self._on_click)

    def _on_enter(self, _event=None):
        if self._enabled:
            self._face.configure(bg=self._active_bg)

    def _on_leave(self, _event=None):
        self._face.configure(bg=self._bg)

    def _on_click(self, _event=None):
        if self._enabled and self._command:
            self._command()

    def set_enabled(self, enabled: bool):
        self._enabled = enabled
        self.configure(cursor="hand2" if enabled else "arrow")
        self._face.configure(
            cursor="hand2" if enabled else "arrow",
            fg=self._fg if enabled else self._disabled_fg,
            bg=self._bg,
        )


class CircleButton(tk.Canvas):
    def __init__(
        self,
        parent,
        *,
        text: str,
        command,
        diameter: int,
        fill: str,
        text_fill: str,
        outline: str,
        active_fill: str | None = None,
        disabled_fill: str | None = None,
        disabled_text_fill: str | None = None,
        font=("Helvetica", 11, "bold"),
    ):
        super().__init__(
            parent,
            width=diameter,
            height=diameter,
            bg=parent.cget("bg"),
            highlightthickness=0,
            bd=0,
            relief="flat",
            cursor="hand2",
        )
        self._command = command
        self._enabled = True
        self._fill = fill
        self._text_fill = text_fill
        self._active_fill = active_fill or fill
        self._disabled_fill = disabled_fill or fill
        self._disabled_text_fill = disabled_text_fill or text_fill
        self._oval = self.create_oval(2, 2, diameter - 2, diameter - 2, fill=fill, outline=outline, width=1)
        self._text = self.create_text(
            diameter / 2,
            diameter / 2,
            text=text,
            fill=text_fill,
            font=font,
        )
        self.bind("<Enter>", self._on_enter)
        self.bind("<Leave>", self._on_leave)
        self.bind("<Button-1>", self._on_click)

    def _on_enter(self, _event=None):
        if self._enabled:
            self.itemconfigure(self._oval, fill=self._active_fill)

    def _on_leave(self, _event=None):
        self.itemconfigure(self._oval, fill=self._fill if self._enabled else self._disabled_fill)

    def _on_click(self, _event=None):
        if self._enabled and self._command:
            self._command()

    def set_enabled(self, enabled: bool):
        self._enabled = enabled
        self.configure(cursor="hand2" if enabled else "arrow")
        self.itemconfigure(self._oval, fill=self._fill if enabled else self._disabled_fill)
        self.itemconfigure(self._text, fill=self._text_fill if enabled else self._disabled_text_fill)


def build_remote_panel(parent, send_callback):
    buttons: list[object] = []
    left_scale = 0.8

    def left_px(value: int, minimum: int = 1) -> int:
        return max(minimum, int(round(value * left_scale)))

    def left_font(font_tuple, min_size: int = 7):
        family, size, *rest = font_tuple
        return (family, max(min_size, int(round(size * left_scale))), *rest)

    def distributed_widths(total: int, count: int, gap: int) -> list[int]:
        usable = total - gap * (count - 1)
        base = usable // count
        widths = [base] * count
        widths[-1] += usable - (base * count)
        return widths

    left_gap = left_px(6, minimum=3)
    right_gap = 6
    left_section_width = left_px(198, minimum=156)
    right_section_width = 260
    left_three_widths = distributed_widths(left_section_width, 3, left_gap)
    left_four_widths = distributed_widths(left_section_width, 4, left_gap)
    right_three_widths = distributed_widths(right_section_width, 3, right_gap)
    right_four_widths = distributed_widths(right_section_width, 4, right_gap)
    right_five_widths = distributed_widths(right_section_width, 5, right_gap)
    guide_side_width = 76
    guide_center_width = right_section_width - (guide_side_width * 2) - (right_gap * 2)
    nav_side_width = 52
    nav_inner_width = right_section_width - 20
    nav_center_width = nav_inner_width - (nav_side_width * 2) - (right_gap * 2)

    def row_pad(index: int, total: int, gap: int) -> tuple[int, int]:
        return (0, gap if index < total - 1 else 0)

    def sized_row(parent, width: int, *, pady=(0, 0), bg=REMOTE_INNER_BG):
        row = tk.Frame(parent, bg=bg, width=width)
        row.pack(anchor="w", fill="x", pady=pady)
        return row

    def rect_button(
        host,
        label,
        key_name,
        *,
        width,
        height,
        bg,
        fg,
        border,
        active_bg=None,
        disabled_fg=None,
        font=("Helvetica", 10, "bold"),
        justify="center",
    ):
        code = KEY_CODE.get(key_name, 0)
        widget = SkinButton(
            host,
            text=label,
            command=lambda c=code: send_callback(c),
            width=width,
            height=height,
            bg=bg,
            fg=fg,
            border=border,
            active_bg=active_bg,
            disabled_fg=disabled_fg,
            font=font,
            justify=justify,
        )
        buttons.append(widget)
        return widget

    def circle_button(
        host,
        label,
        key_name,
        *,
        diameter,
        fill,
        text_fill,
        outline,
        active_fill=None,
        disabled_fill=None,
        disabled_text_fill=None,
        font=("Helvetica", 11, "bold"),
    ):
        code = KEY_CODE.get(key_name, 0)
        widget = CircleButton(
            host,
            text=label,
            command=lambda c=code: send_callback(c),
            diameter=diameter,
            fill=fill,
            text_fill=text_fill,
            outline=outline,
            active_fill=active_fill,
            disabled_fill=disabled_fill,
            disabled_text_fill=disabled_text_fill,
            font=font,
        )
        buttons.append(widget)
        return widget

    wrapper = tk.Frame(parent, bg=APP_BG)

    tk.Label(
        wrapper,
        text="리모컨",
        bg=APP_BG,
        fg=CAPTION_FG,
        font=("Helvetica", 12, "bold"),
    ).pack(pady=(0, 6))

    shell = tk.Frame(
        wrapper,
        bg=REMOTE_BODY_BG,
        highlightbackground=REMOTE_EDGE,
        highlightthickness=1,
        bd=0,
        padx=14,
        pady=14,
    )
    shell.pack()

    remote_frame = tk.Frame(shell, bg=REMOTE_INNER_BG)
    remote_frame.pack()

    power_row = tk.Frame(remote_frame, bg=REMOTE_INNER_BG)
    power_row.pack(fill="x", pady=(0, 10))
    top_controls = tk.Frame(power_row, bg=REMOTE_INNER_BG)
    top_controls.pack(side="left", anchor="nw")
    circle_button(
        top_controls,
        "⏻",
        "POWER",
        diameter=54,
        fill="#c72b24",
        text_fill="#ffffff",
        outline="#6a201d",
        active_fill="#ab241e",
        disabled_fill="#6f3330",
        disabled_text_fill="#f2d5d4",
        font=("Helvetica", 19, "bold"),
    ).pack(side="left")
    rect_button(
        top_controls,
        "MUTE",
        "MUTE",
        width=76,
        height=34,
        bg=LIGHT_BTN_BG,
        fg=LIGHT_BTN_FG,
        border=LIGHT_BTN_BORDER,
        active_bg=LIGHT_BTN_ACTIVE_BG,
        disabled_fg=LIGHT_BTN_DISABLED_FG,
        font=("Helvetica", 10, "bold"),
    ).pack(side="left", padx=(10, 0), pady=(10, 0))
    logo_block = tk.Frame(power_row, bg=REMOTE_INNER_BG)
    logo_block.pack(side="right", anchor="ne", pady=(4, 0))
    tk.Label(
        logo_block,
        text="LG",
        bg=REMOTE_INNER_BG,
        fg=LOGO_FG,
        font=("Helvetica", 18, "bold"),
        anchor="e",
        justify="right",
    ).pack(anchor="e")
    tk.Label(
        logo_block,
        text="월평동 이상목 작품",
        bg=REMOTE_INNER_BG,
        fg=CAPTION_FG,
        font=("Helvetica", 24, "normal"),
        anchor="e",
        justify="right",
    ).pack(anchor="e", pady=(2, 0))

    grid = tk.Frame(remote_frame, bg=REMOTE_INNER_BG)
    grid.pack()

    left = tk.Frame(grid, bg=REMOTE_INNER_BG, width=left_section_width)
    right = tk.Frame(grid, bg=REMOTE_INNER_BG, width=right_section_width)
    left.pack(side="left", anchor="n", padx=(0, 8))
    right.pack(side="left", anchor="n")

    top_row = sized_row(left, left_section_width, pady=(0, left_px(8)))
    utility = tk.Frame(top_row, bg=REMOTE_INNER_BG)
    utility.pack(fill="x")
    for idx, (caption, symbol, key_name) in enumerate([
        ("RATIO", "▣", "RATIO"),
        ("INPUT", "↪", "INPUT"),
        ("TV/RAD", "TV", "TV_RAD"),
    ]):
        cell = tk.Frame(
            utility,
            bg=REMOTE_INNER_BG,
            width=left_three_widths[idx],
            height=left_px(62, minimum=44),
        )
        cell.pack(side="left", padx=row_pad(idx, 3, left_gap), fill="y")
        cell.pack_propagate(False)
        tk.Label(
            cell,
            text=caption,
            bg=REMOTE_INNER_BG,
            fg=CAPTION_FG,
            font=left_font(("Helvetica", 8, "bold")),
        ).pack(pady=(0, left_px(2)))
        circle_button(
            cell,
            symbol,
            key_name,
            diameter=min(left_px(38, minimum=24), left_three_widths[idx] - 8),
            fill=LIGHT_BTN_BG,
            text_fill=LIGHT_BTN_FG,
            outline=LIGHT_BTN_BORDER,
            active_fill=LIGHT_BTN_ACTIVE_BG,
            disabled_fill="#555555",
            disabled_text_fill=LIGHT_BTN_DISABLED_FG,
            font=left_font(("Helvetica", 10, "bold"), min_size=8),
        ).pack(anchor="n")

    number_pad = tk.Frame(left, bg=REMOTE_INNER_BG)
    number_pad.pack(anchor="w", pady=(0, left_px(10)))
    for row_index, row_keys in enumerate([("1", "2", "3"), ("4", "5", "6"), ("7", "8", "9")]):
        for col_index, key_name in enumerate(row_keys):
            rect_button(
                number_pad,
                key_name,
                key_name,
                width=left_three_widths[col_index],
                height=left_px(56, minimum=36),
                bg=LIGHT_BTN_BG,
                fg=LIGHT_BTN_FG,
                border=LIGHT_BTN_BORDER,
                active_bg=LIGHT_BTN_ACTIVE_BG,
                disabled_fg=LIGHT_BTN_DISABLED_FG,
                font=left_font(("Helvetica", 18, "bold"), min_size=11),
            ).grid(row=row_index, column=col_index, padx=row_pad(col_index, 3, left_gap), pady=left_px(4))

    rect_button(
        number_pad,
        "LIST",
        "LIST",
        width=left_three_widths[0],
        height=left_px(36, minimum=28),
        bg=LIGHT_BTN_BG,
        fg=LIGHT_BTN_FG,
        border=LIGHT_BTN_BORDER,
        active_bg=LIGHT_BTN_ACTIVE_BG,
        disabled_fg=LIGHT_BTN_DISABLED_FG,
        font=left_font(("Helvetica", 10, "bold"), min_size=8),
    ).grid(row=3, column=0, padx=row_pad(0, 3, left_gap), pady=left_px(4))
    rect_button(
        number_pad,
        "0",
        "0",
        width=left_three_widths[1],
        height=left_px(56, minimum=36),
        bg=LIGHT_BTN_BG,
        fg=LIGHT_BTN_FG,
        border=LIGHT_BTN_BORDER,
        active_bg=LIGHT_BTN_ACTIVE_BG,
        disabled_fg=LIGHT_BTN_DISABLED_FG,
        font=left_font(("Helvetica", 18, "bold"), min_size=11),
    ).grid(row=3, column=1, padx=row_pad(1, 3, left_gap), pady=left_px(4))
    rect_button(
        number_pad,
        "Q.VIEW",
        "Q_VIEW",
        width=left_three_widths[2],
        height=left_px(36, minimum=28),
        bg=LIGHT_BTN_BG,
        fg=LIGHT_BTN_FG,
        border=LIGHT_BTN_BORDER,
        active_bg=LIGHT_BTN_ACTIVE_BG,
        disabled_fg=LIGHT_BTN_DISABLED_FG,
        font=left_font(("Helvetica", 10, "bold"), min_size=8),
    ).grid(row=3, column=2, padx=row_pad(2, 3, left_gap), pady=left_px(4))

    side_group = sized_row(left, left_section_width, pady=(0, left_px(10)))

    volume_col = tk.Frame(side_group, bg=REMOTE_INNER_BG, width=left_three_widths[0])
    volume_col.pack(side="left", padx=row_pad(0, 3, left_gap), fill="y")
    for label, key_name in [("+", "VOL+"), ("◁", "VOL-"), ("−", "VOL-")]:
        rect_button(
            volume_col,
            label,
            key_name,
            width=left_three_widths[0],
            height=left_px(46, minimum=30),
            bg=SIDE_BTN_BG,
            fg=SIDE_BTN_FG,
            border=SIDE_BTN_BORDER,
            active_bg=SIDE_BTN_ACTIVE_BG,
            disabled_fg="#9eb7de",
            font=left_font(("Helvetica", 18, "bold"), min_size=11),
        ).pack(pady=left_px(3))

    middle_col = tk.Frame(side_group, bg=REMOTE_INNER_BG, width=left_three_widths[1])
    middle_col.pack(side="left", padx=row_pad(1, 3, left_gap), fill="y")
    for label, key_name in [("FAV", "FAV"), ("3D", "3D"), ("MUTE", "MUTE")]:
        rect_button(
            middle_col,
            label,
            key_name,
            width=left_three_widths[1],
            height=left_px(32, minimum=24),
            bg=LIGHT_BTN_BG,
            fg=LIGHT_BTN_FG,
            border=LIGHT_BTN_BORDER,
            active_bg=LIGHT_BTN_ACTIVE_BG,
            disabled_fg=LIGHT_BTN_DISABLED_FG,
            font=left_font(("Helvetica", 10, "bold"), min_size=8),
        ).pack(pady=left_px(4))

    channel_col = tk.Frame(side_group, bg=REMOTE_INNER_BG, width=left_three_widths[2])
    channel_col.pack(side="left", padx=row_pad(2, 3, left_gap), fill="y")
    for label, key_name in [("⌃", "CH+"), ("P", "GUIDE"), ("⌄", "CH-")]:
        rect_button(
            channel_col,
            label,
            key_name,
            width=left_three_widths[2],
            height=left_px(46, minimum=30),
            bg=SIDE_BTN_BG,
            fg=SIDE_BTN_FG,
            border=SIDE_BTN_BORDER,
            active_bg=SIDE_BTN_ACTIVE_BG,
            disabled_fg="#9eb7de",
            font=left_font(("Helvetica", 18, "bold"), min_size=11),
        ).pack(pady=left_px(3))

    apps_row = sized_row(left, left_section_width, pady=(0, left_px(6)))
    for idx, (label, key_name) in enumerate([("SETTINGS", "MENU"), ("Q.MENU", "QUICK_MENU"), ("MY APPS", "HOME")]):
        rect_button(
            apps_row,
            label,
            key_name,
            width=left_three_widths[idx],
            height=left_px(34, minimum=24),
            bg=DARK_BTN_BG,
            fg=DARK_BTN_FG,
            border=DARK_BTN_BORDER,
            active_bg=DARK_BTN_ACTIVE_BG,
            disabled_fg=DARK_BTN_DISABLED_FG,
            font=left_font(("Helvetica", 9, "bold"), min_size=7),
        ).pack(side="left", padx=row_pad(idx, 3, left_gap))

    nav_shell = tk.Frame(
        right,
        bg="#0b0b0b",
        highlightbackground="#202020",
        highlightthickness=1,
        bd=0,
        width=right_section_width,
        padx=10,
        pady=10,
    )
    nav_shell.pack(anchor="w", pady=(20, 10), fill="x")
    rect_button(
        nav_shell,
        "▲",
        "UP",
        width=nav_center_width,
        height=34,
        bg=DARK_BTN_BG,
        fg=DARK_BTN_FG,
        border=DARK_BTN_BORDER,
        active_bg=DARK_BTN_ACTIVE_BG,
        disabled_fg=DARK_BTN_DISABLED_FG,
        font=("Helvetica", 18, "bold"),
    ).grid(row=0, column=1, padx=(0, 0), pady=4)
    rect_button(
        nav_shell,
        "◀",
        "LEFT",
        width=nav_side_width,
        height=72,
        bg=DARK_BTN_BG,
        fg=DARK_BTN_FG,
        border=DARK_BTN_BORDER,
        active_bg=DARK_BTN_ACTIVE_BG,
        disabled_fg=DARK_BTN_DISABLED_FG,
        font=("Helvetica", 18, "bold"),
    ).grid(row=1, column=0, padx=(0, right_gap), pady=4)
    rect_button(
        nav_shell,
        "OK",
        "OK",
        width=nav_center_width,
        height=72,
        bg=DARK_BTN_BG,
        fg=DARK_BTN_FG,
        border=DARK_BTN_BORDER,
        active_bg=DARK_BTN_ACTIVE_BG,
        disabled_fg=DARK_BTN_DISABLED_FG,
        font=("Helvetica", 18, "bold"),
    ).grid(row=1, column=1, padx=(0, 0), pady=4)
    rect_button(
        nav_shell,
        "▶",
        "RIGHT",
        width=nav_side_width,
        height=72,
        bg=DARK_BTN_BG,
        fg=DARK_BTN_FG,
        border=DARK_BTN_BORDER,
        active_bg=DARK_BTN_ACTIVE_BG,
        disabled_fg=DARK_BTN_DISABLED_FG,
        font=("Helvetica", 18, "bold"),
    ).grid(row=1, column=2, padx=(right_gap, 0), pady=4)
    rect_button(
        nav_shell,
        "▼",
        "DOWN",
        width=nav_center_width,
        height=34,
        bg=DARK_BTN_BG,
        fg=DARK_BTN_FG,
        border=DARK_BTN_BORDER,
        active_bg=DARK_BTN_ACTIVE_BG,
        disabled_fg=DARK_BTN_DISABLED_FG,
        font=("Helvetica", 18, "bold"),
    ).grid(row=2, column=1, padx=(0, 0), pady=4)

    guide_row = sized_row(right, right_section_width, pady=(0, 8))
    for idx, (label, key_name, width) in enumerate([("↩", "BACK", guide_side_width), ("GUIDE", "GUIDE", guide_center_width), ("EXIT", "EXIT", guide_side_width)]):
        rect_button(
            guide_row,
            label,
            key_name,
            width=width,
            height=32,
            bg=DARK_BTN_BG,
            fg=DARK_BTN_FG,
            border=DARK_BTN_BORDER,
            active_bg=DARK_BTN_ACTIVE_BG,
            disabled_fg=DARK_BTN_DISABLED_FG,
            font=("Helvetica", 10, "bold"),
        ).pack(side="left", padx=row_pad(idx, 3, right_gap))

    color_row = sized_row(right, right_section_width, pady=(0, 8))
    for idx, (label, key_name, bg) in enumerate([
        ("•", "RED", "#c23836"),
        ("••", "GREEN", "#1ca85e"),
        ("••", "YELLOW", "#e0b640"),
        ("••", "BLUE", "#3b72c3"),
    ]):
        rect_button(
            color_row,
            label,
            key_name,
            width=right_four_widths[idx],
            height=24,
            bg=bg,
            fg="#ffffff",
            border=bg,
            active_bg=bg,
            disabled_fg="#f2f2f2",
            font=("Helvetica", 10, "bold"),
        ).pack(side="left", padx=row_pad(idx, 4, right_gap))

    service_row = sized_row(right, right_section_width, pady=(0, 8))
    for idx, (label, key_name) in enumerate([("TEXT", "TEXT"), ("T.OPT", "T_OPT"), ("SUB", "SUBTITLE"), ("Q.MENU", "QUICK_MENU")]):
        rect_button(
            service_row,
            label,
            key_name,
            width=right_four_widths[idx],
            height=28,
            bg=DARK_BTN_BG,
            fg=DARK_BTN_FG,
            border=DARK_BTN_BORDER,
            active_bg=DARK_BTN_ACTIVE_BG,
            disabled_fg=DARK_BTN_DISABLED_FG,
            font=("Helvetica", 8, "bold"),
        ).pack(side="left", padx=row_pad(idx, 4, right_gap))

    media_row = sized_row(right, right_section_width, pady=(0, 8))
    for idx, (label, key_name) in enumerate([("⏮", "REW"), ("▶", "PLAY"), ("⏸", "PAUSE"), ("⏹", "STOP"), ("⏭", "FF")]):
        rect_button(
            media_row,
            label,
            key_name,
            width=right_five_widths[idx],
            height=28,
            bg=DARK_BTN_BG,
            fg=DARK_BTN_FG,
            border=DARK_BTN_BORDER,
            active_bg=DARK_BTN_ACTIVE_BG,
            disabled_fg=DARK_BTN_DISABLED_FG,
            font=("Helvetica", 11, "bold"),
        ).pack(side="left", padx=row_pad(idx, 5, right_gap))

    bottom_row = sized_row(right, right_section_width, pady=(0, 8))
    for idx, (label, key_name) in enumerate([("INFO", "INFO"), ("AD", "AD"), ("APP/*", "HOME")]):
        rect_button(
            bottom_row,
            label,
            key_name,
            width=right_three_widths[idx],
            height=28,
            bg=DARK_BTN_BG,
            fg=DARK_BTN_FG,
            border=DARK_BTN_BORDER,
            active_bg=DARK_BTN_ACTIVE_BG,
            disabled_fg=DARK_BTN_DISABLED_FG,
            font=("Helvetica", 9, "bold"),
        ).pack(side="left", padx=row_pad(idx, 3, right_gap))

    return wrapper, buttons
