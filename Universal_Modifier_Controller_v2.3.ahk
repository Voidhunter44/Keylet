#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; Universal Modifier Controller v2.3
; AutoHotkey v2
; ============================================================

DllCall("SetProcessDPIAware")

global AppName := "Universal Modifier Controller"
global ConfigFile := A_ScriptDir "\UniversalModifierController.ini"

; -----------------------------
; Runtime state
; -----------------------------

global IsHeld := false
global RecordingMode := ""
global RecordedKeys := []
global ActionKeys := ["LControl", "LAlt"]
global ActivationHotkey := "^!Space"

global WidgetVisible := true
global WidgetSize := "Medium"

global ShowWidgetStatus := true
global ShowWidgetName := true
global ShowWidgetKeys := true
global ShowWidgetToggle := true

global WidgetPosX := -1
global WidgetPosY := -1

global MainGui := 0
global WidgetGui := 0
global WidgetHwnd := 0

global MainActionEdit := 0
global MainHotkeyEdit := 0
global ActionListText := 0
global StatusText := 0
global RecordActionBtn := 0
global RecordHotkeyBtn := 0
global SizeDrop := 0
global WidgetStatusCheck := 0
global WidgetNameCheck := 0
global WidgetKeysCheck := 0
global WidgetToggleCheck := 0

global WidgetTitle := 0
global WidgetKeysText := 0
global WidgetStatusText := 0
global WidgetToggleBtn := 0
global WidgetMenuBtn := 0

global CurrentRecordedGui := 0
global CurrentInputHook := 0
global RecordedPreviewCtrl := 0

; -----------------------------
; Load & Build
; -----------------------------

LoadConfig()
BuildMainGui()
BuildWidgetGui()
SetupTray()
RegisterActivationHotkey()
UpdateMainUI()
ShowWidget()

OnExit(Cleanup)
return

; ============================================================
; CONFIG
; ============================================================

LoadConfig() {
    global ConfigFile
    global ActionKeys, ActivationHotkey
    global WidgetSize, ShowWidgetStatus, ShowWidgetName, ShowWidgetKeys, ShowWidgetToggle
    global WidgetPosX, WidgetPosY

    if !FileExist(ConfigFile)
        return

    keys := IniRead(ConfigFile, "General", "ActionKeys", "")
    hotkey := IniRead(ConfigFile, "General", "ActivationHotkey", "^!Space")

    WidgetSize := IniRead(ConfigFile, "Widget", "Size", "Medium")
    ShowWidgetStatus := IniRead(ConfigFile, "Widget", "ShowStatus", "1") = "1"
    ShowWidgetName := IniRead(ConfigFile, "Widget", "ShowName", "1") = "1"
    ShowWidgetKeys := IniRead(ConfigFile, "Widget", "ShowKeys", "1") = "1"
    ShowWidgetToggle := IniRead(ConfigFile, "Widget", "ShowToggle", "1") = "1"

    WidgetPosX := Integer(IniRead(ConfigFile, "Widget", "PosX", "-1"))
    WidgetPosY := Integer(IniRead(ConfigFile, "Widget", "PosY", "-1"))

    if keys != ""
        ActionKeys := StrSplit(keys, ",")
    if hotkey != ""
        ActivationHotkey := hotkey
}

SaveConfig() {
    global ConfigFile
    global ActionKeys, ActivationHotkey
    global WidgetSize, ShowWidgetStatus, ShowWidgetName, ShowWidgetKeys, ShowWidgetToggle
    global WidgetPosX, WidgetPosY

    keyString := ""
    for i, key in ActionKeys {
        if i > 1
            keyString .= ","
        keyString .= key
    }

    try {
        IniWrite(keyString, ConfigFile, "General", "ActionKeys")
        IniWrite(ActivationHotkey, ConfigFile, "General", "ActivationHotkey")
        IniWrite(WidgetSize, ConfigFile, "Widget", "Size")
        IniWrite(ShowWidgetStatus ? "1" : "0", ConfigFile, "Widget", "ShowStatus")
        IniWrite(ShowWidgetName ? "1" : "0", ConfigFile, "Widget", "ShowName")
        IniWrite(ShowWidgetKeys ? "1" : "0", ConfigFile, "Widget", "ShowKeys")
        IniWrite(ShowWidgetToggle ? "1" : "0", ConfigFile, "Widget", "ShowToggle")
        IniWrite(String(WidgetPosX), ConfigFile, "Widget", "PosX")
        IniWrite(String(WidgetPosY), ConfigFile, "Widget", "PosY")
    }
}

SaveWidgetPosition() {
    global WidgetGui, WidgetPosX, WidgetPosY, WidgetVisible
    if !WidgetVisible || !WidgetGui
        return
    try {
        WidgetGui.GetPos(&x, &y)
        WidgetPosX := x
        WidgetPosY := y
        SaveConfig()
    }
}

; ============================================================
; MAIN GUI
; ============================================================

BuildMainGui() {
    global MainGui
    global MainActionEdit, MainHotkeyEdit, ActionListText, StatusText
    global RecordActionBtn, RecordHotkeyBtn
    global WidgetSize, SizeDrop
    global WidgetStatusCheck, WidgetNameCheck, WidgetKeysCheck, WidgetToggleCheck
    global ShowWidgetStatus, ShowWidgetName, ShowWidgetKeys, ShowWidgetToggle

    MainGui := Gui("+MinSize480x400", AppName)
    MainGui.BackColor := "F5F5F5"
    MainGui.MarginX := 22
    MainGui.MarginY := 18

    MainGui.SetFont("s15 Bold", "Segoe UI")
    MainGui.Add("Text", "xm ym w600", "Universal Modifier Controller")

    MainGui.SetFont("s9 Norm", "Segoe UI")
    MainGui.Add("Text", "xm y+4 w600 c666666",
        "Record any group of keyboard keys and hold them with one toggle.")

    ; --- Action keys ---
    MainGui.SetFont("s11 Bold")
    MainGui.Add("Text", "xm y+25", "Action keys")

    MainGui.SetFont("s9 Norm")
    MainGui.Add("Text", "xm y+5 w600 c666666",
        "These are the keys that will be held when the controller is ON.")

    MainActionEdit := MainGui.Add("Edit", "xm y+10 w500 h32 ReadOnly", "")
    RecordActionBtn := MainGui.Add("Button", "x+10 yp w110 h32", "Record keys")
    RecordActionBtn.OnEvent("Click", StartActionRecorder)
    ActionListText := MainGui.Add("Text", "xm y+10 w620 h45 c444444", "")

    ; --- Activation hotkey ---
    MainGui.SetFont("s11 Bold")
    MainGui.Add("Text", "xm y+12", "Activation hotkey")

    MainGui.SetFont("s9 Norm")
    MainGui.Add("Text", "xm y+5 w620 c666666",
        "Press this shortcut anywhere to toggle the selected keys.")

    MainHotkeyEdit := MainGui.Add("Edit", "xm y+10 w500 h32 ReadOnly", "")
    RecordHotkeyBtn := MainGui.Add("Button", "x+10 yp w110 h32", "Record hotkey")
    RecordHotkeyBtn.OnEvent("Click", StartHotkeyRecorder)

    ; --- Status ---
    MainGui.SetFont("s11 Bold")
    MainGui.Add("Text", "xm y+24", "Controller status")

    MainGui.SetFont("s10 Norm")
    StatusText := MainGui.Add("Text", "xm y+8 w620 h28", "OFF")

    ; --- Widget options ---
    MainGui.SetFont("s11 Bold")
    MainGui.Add("Text", "xm y+20", "Floating widget")

    MainGui.SetFont("s9 Norm")
    MainGui.Add("Text", "xm y+5 w620 c666666",
        "Choose the widget size and what it displays.")

    MainGui.SetFont("s9 Bold")
    MainGui.Add("Text", "xm y+15", "Size")

    sizeIndex := 1
    switch WidgetSize {
        case "Extra Small": sizeIndex := 1
        case "Small":       sizeIndex := 2
        case "Medium":      sizeIndex := 3
        case "Large":       sizeIndex := 4
    }

    SizeDrop := MainGui.Add("DropDownList",
        "x+10 yp-3 w150 Choose" sizeIndex,
        ["Extra Small", "Small", "Medium", "Large"])
    SizeDrop.OnEvent("Change", WidgetSizeChanged)

    MainGui.SetFont("s9 Bold")
    MainGui.Add("Text", "xm y+18", "Show on widget")

    MainGui.SetFont("s9 Norm")
    WidgetStatusCheck := MainGui.Add("CheckBox", "xm y+8 Checked" (ShowWidgetStatus ? 1 : 0), "Status")
    WidgetNameCheck := MainGui.Add("CheckBox", "x+20 yp Checked" (ShowWidgetName ? 1 : 0), "Action name")
    WidgetKeysCheck := MainGui.Add("CheckBox", "x+20 yp Checked" (ShowWidgetKeys ? 1 : 0), "Key combination")
    WidgetToggleCheck := MainGui.Add("CheckBox", "x+20 yp Checked" (ShowWidgetToggle ? 1 : 0), "Toggle button")

    WidgetStatusCheck.OnEvent("Click", WidgetOptionsChanged)
    WidgetNameCheck.OnEvent("Click", WidgetOptionsChanged)
    WidgetKeysCheck.OnEvent("Click", WidgetOptionsChanged)
    WidgetToggleCheck.OnEvent("Click", WidgetOptionsChanged)

    MainGui.Add("Text", "xm y+14 w620 c777777",
        "Tip: right-click the widget for quick settings. Use 'Extra Small' for a minimal toggle button.")

    ; --- Buttons ---
    ShowWidgetBtn := MainGui.Add("Button", "xm y+20 w150 h32", "Show widget")
    ShowWidgetBtn.OnEvent("Click", ShowWidget)

    HideWidgetBtn := MainGui.Add("Button", "x+10 yp w150 h32", "Hide widget")
    HideWidgetBtn.OnEvent("Click", HideWidget)

    ReleaseBtn := MainGui.Add("Button", "x+10 yp w180 h32", "Release all keys")
    ReleaseBtn.OnEvent("Click", (*) => ReleaseModifiers())

    MainGui.OnEvent("Close", MainWindowClose)
    MainGui.OnEvent("Size", MainGuiSize)
    MainGui.Show("w680 h580")
}

MainGuiSize(guiObj, minMax, width, height) {
    if minMax = -1 {
        guiObj.Hide()
        ShowTrayTip("Modifier Controller", "Running in the system tray.")
    }
}

MainWindowClose(*) {
    global MainGui
    MainGui.Hide()
}

; ============================================================
; WIDGET GUI
; ============================================================

BuildWidgetGui() {
    global WidgetGui, WidgetHwnd
    global WidgetTitle, WidgetKeysText, WidgetStatusText
    global WidgetToggleBtn, WidgetMenuBtn

    ; KEY FIX: WS_EX_NOACTIVATE (0x08000000) prevents the widget from stealing
    ; focus/activation from other windows. This is why typing/scrolling was blocked.
    ; The widget will NOT take focus when clicked.
    WidgetGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    WidgetGui.BackColor := "1E1E2E"
    WidgetGui.MarginX := 14
    WidgetGui.MarginY := 12

    ; Title
    WidgetTitle := WidgetGui.Add("Text", "x14 y12 w150 h20 cE0E0E0", AppName)
    WidgetTitle.SetFont("s9 Bold", "Segoe UI")

    ; Menu button
    WidgetMenuBtn := WidgetGui.Add("Text", "x172 y10 w30 h22 cBBBBBB Center", "☰")
    WidgetMenuBtn.SetFont("s11", "Segoe UI")
    WidgetMenuBtn.OnEvent("Click", WidgetMenuClick)

    ; Status
    WidgetStatusText := WidgetGui.Add("Text", "x14 y36 w188 h18 c888888", "○ OFF")
    WidgetStatusText.SetFont("s9", "Segoe UI")

    ; Keys display
    WidgetKeysText := WidgetGui.Add("Text", "x14 y58 w188 h24 cFFFFFF", "Ctrl + Alt")
    WidgetKeysText.SetFont("s10 Bold", "Segoe UI")

    ; Toggle button
    WidgetToggleBtn := WidgetGui.Add("Button", "x14 y88 w188 h30", "Turn ON")
    WidgetToggleBtn.SetFont("s9 Bold", "Segoe UI")
    WidgetToggleBtn.OnEvent("Click", ToggleModifier)

    WidgetGui.OnEvent("Close", HideWidget)

    ; Get HWND.
    WidgetGui.Show("Hide")
    WidgetHwnd := WidgetGui.Hwnd

    ; Register WM_NCHITTEST ONLY for the widget window.
    OnMessage(0x0084, WidgetHitTest)
}

WidgetHitTest(wParam, lParam, msg, hwnd) {
    global WidgetHwnd

    ; CRITICAL: Only process our widget. Return nothing for all other windows
    ; so they behave completely normally.
    if (hwnd != WidgetHwnd)
        return

    ; Get widget window position.
    try WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " WidgetHwnd)
    catch
        return

    if (winW = 0 || winH = 0)
        return

    ; Extract signed screen coordinates from lParam.
    screenX := lParam & 0xFFFF
    if (screenX > 0x7FFF)
        screenX -= 0x10000
    screenY := (lParam >> 16) & 0xFFFF
    if (screenY > 0x7FFF)
        screenY -= 0x10000

    cx := screenX - winX
    cy := screenY - winY

    ; Let button and menu areas pass through to controls (return nothing = HTCLIENT default).
    ; Check toggle button.
    global WidgetToggleBtn
    if WidgetToggleBtn.Visible {
        try {
            WidgetToggleBtn.GetPos(&bx, &by, &bw, &bh)
            if (cx >= bx && cx <= bx + bw && cy >= by && cy <= by + bh)
                return  ; Default processing — button gets the click.
        }
    }

    ; Check menu button.
    global WidgetMenuBtn
    if WidgetMenuBtn.Visible {
        try {
            WidgetMenuBtn.GetPos(&mx, &my, &mw, &mh)
            if (cx >= mx && cx <= mx + mw && cy >= my && cy <= my + mh)
                return  ; Default processing — menu gets the click.
        }
    }

    ; Everything else: HTCAPTION allows dragging.
    return 2  ; HTCAPTION
}

ApplyRoundedCorners() {
    global WidgetHwnd
    if !WidgetHwnd
        return

    if VerCompare(A_OSVersion, "10.0.22000") >= 0 {
        ; Windows 11: native rounded corners.
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", WidgetHwnd, "Int", 33, "Int*", 2, "Int", 4)
    } else {
        ; Windows 10: region clipping.
        try {
            WinGetPos(, , &w, &h, "ahk_id " WidgetHwnd)
            if (w > 0 && h > 0) {
                hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0,
                    "Int", w + 1, "Int", h + 1, "Int", 12, "Int", 12, "Ptr")
                DllCall("SetWindowRgn", "Ptr", WidgetHwnd, "Ptr", hRgn, "Int", true)
            }
        }
    }
}

ShowWidget(*) {
    global WidgetGui, WidgetVisible, WidgetPosX, WidgetPosY

    WidgetVisible := true
    UpdateWidgetContent()
    LayoutWidget()

    if WidgetPosX >= 0 && WidgetPosY >= 0
        WidgetGui.Show("x" WidgetPosX " y" WidgetPosY " NoActivate")
    else
        WidgetGui.Show("x1200 y120 NoActivate")

    SetTimer(ApplyRoundedCorners, -50)
}

HideWidget(*) {
    global WidgetGui, WidgetVisible
    SaveWidgetPosition()
    WidgetVisible := false
    WidgetGui.Hide()
}

LayoutWidget() {
    global WidgetSize, WidgetGui, WidgetHwnd
    global ShowWidgetName, ShowWidgetStatus, ShowWidgetKeys, ShowWidgetToggle
    global WidgetTitle, WidgetStatusText, WidgetKeysText
    global WidgetToggleBtn, WidgetMenuBtn

    ; --- EXTRA SMALL: Just a square toggle button ---
    if WidgetSize = "Extra Small" {
        WidgetTitle.Visible := false
        WidgetStatusText.Visible := false
        WidgetKeysText.Visible := false
        WidgetMenuBtn.Visible := false

        ; Square button fills the widget.
        btnSize := 44
        pad := 6
        WidgetToggleBtn.SetFont("s10 Bold", "Segoe UI")
        WidgetToggleBtn.Move(pad, pad, btnSize, btnSize)
        WidgetToggleBtn.Visible := true

        totalSize := btnSize + (pad * 2)
        WidgetGui.Move(, , totalSize, totalSize)

        SetTimer(ApplyRoundedCorners, -50)
        return
    }

    ; --- Standard sizes ---
    pad := 14
    switch WidgetSize {
        case "Small":
            baseW := 185
            WidgetTitle.SetFont("s8 Bold", "Segoe UI")
            WidgetStatusText.SetFont("s8", "Segoe UI")
            WidgetKeysText.SetFont("s9 Bold", "Segoe UI")
            WidgetToggleBtn.SetFont("s8 Bold", "Segoe UI")
            WidgetMenuBtn.SetFont("s9", "Segoe UI")
        case "Medium":
            baseW := 215
            WidgetTitle.SetFont("s9 Bold", "Segoe UI")
            WidgetStatusText.SetFont("s9", "Segoe UI")
            WidgetKeysText.SetFont("s10 Bold", "Segoe UI")
            WidgetToggleBtn.SetFont("s9 Bold", "Segoe UI")
            WidgetMenuBtn.SetFont("s11", "Segoe UI")
        case "Large":
            baseW := 280
            WidgetTitle.SetFont("s10 Bold", "Segoe UI")
            WidgetStatusText.SetFont("s10", "Segoe UI")
            WidgetKeysText.SetFont("s12 Bold", "Segoe UI")
            WidgetToggleBtn.SetFont("s10 Bold", "Segoe UI")
            WidgetMenuBtn.SetFont("s12", "Segoe UI")
    }

    contentW := baseW - (pad * 2)
    y := pad

    ; Hide everything first.
    WidgetTitle.Visible := false
    WidgetStatusText.Visible := false
    WidgetKeysText.Visible := false
    WidgetToggleBtn.Visible := false

    if ShowWidgetName {
        WidgetTitle.Move(pad, y, contentW - 36, 22)
        WidgetTitle.Visible := true
        y += 26
    }

    ; Menu always top-right.
    WidgetMenuBtn.Move(baseW - pad - 30, pad - 2, 30, 22)
    WidgetMenuBtn.Visible := true

    if ShowWidgetStatus {
        WidgetStatusText.Move(pad, y, contentW, 20)
        WidgetStatusText.Visible := true
        y += 24
    }

    if ShowWidgetKeys {
        WidgetKeysText.Move(pad, y, contentW, 24)
        WidgetKeysText.Visible := true
        y += 30
    }

    if ShowWidgetToggle {
        y += 4
        btnH := WidgetSize = "Large" ? 34 : 30
        WidgetToggleBtn.Move(pad, y, contentW, btnH)
        WidgetToggleBtn.Visible := true
        y += btnH + 4
    }

    height := y + pad
    if height < 56
        height := 56

    WidgetGui.Move(, , baseW, height)
    SetTimer(ApplyRoundedCorners, -50)
}

UpdateWidgetContent() {
    global IsHeld, ActionKeys, AppName, WidgetVisible, WidgetSize
    global WidgetTitle, WidgetStatusText, WidgetKeysText, WidgetToggleBtn

    if !WidgetVisible
        return

    WidgetTitle.Text := AppName
    WidgetStatusText.Text := IsHeld ? "● ACTIVE" : "○ OFF"
    WidgetStatusText.Opt(IsHeld ? "c6FE38A" : "c888888")
    WidgetKeysText.Text := FormatKeys(ActionKeys)

    ; Extra Small: show icon only on button.
    if WidgetSize = "Extra Small"
        WidgetToggleBtn.Text := IsHeld ? "■" : "▶"
    else
        WidgetToggleBtn.Text := IsHeld ? "Turn OFF" : "Turn ON"
}

UpdateWidget() {
    global WidgetVisible
    if !WidgetVisible
        return
    UpdateWidgetContent()
    LayoutWidget()
}

; ============================================================
; WIDGET MENU
; ============================================================

WidgetMenuClick(*) {
    global IsHeld, WidgetSize
    global ShowWidgetStatus, ShowWidgetName, ShowWidgetKeys, ShowWidgetToggle

    menu := Menu()
    menu.Add(IsHeld ? "Turn OFF" : "Turn ON", ToggleModifier)
    menu.Add("Release all keys", (*) => ReleaseModifiers())
    menu.Add()

    sizeSub := Menu()
    sizeSub.Add("Extra Small", (*) => SetWidgetSize("Extra Small"))
    sizeSub.Add("Small", (*) => SetWidgetSize("Small"))
    sizeSub.Add("Medium", (*) => SetWidgetSize("Medium"))
    sizeSub.Add("Large", (*) => SetWidgetSize("Large"))
    sizeSub.Check(WidgetSize)
    menu.Add("Widget size", sizeSub)

    contentSub := Menu()
    contentSub.Add("Status", ToggleWidgetStatus)
    contentSub.Add("Action name", ToggleWidgetName)
    contentSub.Add("Key combination", ToggleWidgetKeys)
    contentSub.Add("Toggle button", ToggleWidgetToggle)
    if ShowWidgetStatus
        contentSub.Check("Status")
    if ShowWidgetName
        contentSub.Check("Action name")
    if ShowWidgetKeys
        contentSub.Check("Key combination")
    if ShowWidgetToggle
        contentSub.Check("Toggle button")

    menu.Add("Widget content", contentSub)
    menu.Add()
    menu.Add("Open settings", ShowMainGui)
    menu.Add("Hide widget", HideWidget)
    menu.Add()
    menu.Add("Exit", (*) => ExitApp())

    menu.Show()
}

SetWidgetSize(size) {
    global WidgetSize
    WidgetSize := size
    SaveConfig()
    UpdateWidgetContent()
    LayoutWidget()
}

ToggleWidgetStatus(*) {
    global ShowWidgetStatus
    ShowWidgetStatus := !ShowWidgetStatus
    SaveConfig()
    UpdateWidget()
}

ToggleWidgetName(*) {
    global ShowWidgetName
    ShowWidgetName := !ShowWidgetName
    SaveConfig()
    UpdateWidget()
}

ToggleWidgetKeys(*) {
    global ShowWidgetKeys
    ShowWidgetKeys := !ShowWidgetKeys
    SaveConfig()
    UpdateWidget()
}

ToggleWidgetToggle(*) {
    global ShowWidgetToggle
    ShowWidgetToggle := !ShowWidgetToggle
    SaveConfig()
    UpdateWidget()
}

; ============================================================
; TRAY
; ============================================================

SetupTray() {
    global AppName
    A_IconTip := AppName
    Tray := A_TrayMenu
    Tray.Delete()

    Tray.Add("Toggle", ToggleModifier)
    Tray.Add("Release all keys", (*) => ReleaseModifiers())
    Tray.Add()
    Tray.Add("Show widget", ShowWidget)
    Tray.Add("Hide widget", HideWidget)
    Tray.Add("Open settings", ShowMainGui)
    Tray.Add()
    Tray.Add("Exit", (*) => ExitApp())
    Tray.Default := "Toggle"
}

ShowMainGui(*) {
    global MainGui
    MainGui.Show()
    MainGui.Opt("+AlwaysOnTop")
    MainGui.Opt("-AlwaysOnTop")
    WinActivate("ahk_id " MainGui.Hwnd)
}

ShowTrayTip(title, text) {
    try TrayTip(text, title, 17)
}

; ============================================================
; TOGGLE / KEY CONTROL
; ============================================================

ToggleModifier(*) {
    global IsHeld
    if IsHeld
        ReleaseModifiers()
    else
        HoldModifiers()
}

HoldModifiers() {
    global IsHeld, ActionKeys
    if IsHeld
        return

    for key in ActionKeys
        SafeSend("{" key " Down}")

    IsHeld := true
    UpdateMainUI()
    UpdateWidget()
}

ReleaseModifiers(forceAll := false) {
    global IsHeld, ActionKeys

    for key in ActionKeys
        SafeSend("{" key " Up}")

    if forceAll
        SafeSend("{Ctrl Up}{Alt Up}{Shift Up}{LWin Up}{RWin Up}")

    IsHeld := false
    UpdateMainUI()
    UpdateWidget()
}

SafeSend(sequence) {
    try Send(sequence)
}

; ============================================================
; RECORDERS
; ============================================================

StartActionRecorder(*) {
    StartKeyRecorder("Action")
}

StartHotkeyRecorder(*) {
    StartKeyRecorder("Hotkey")
}

StartKeyRecorder(mode) {
    global RecordingMode, RecordedKeys
    global CurrentRecordedGui, CurrentInputHook, RecordedPreviewCtrl
    global RecordActionBtn, RecordHotkeyBtn

    if RecordingMode != ""
        return

    RecordingMode := mode
    RecordedKeys := []
    RecordActionBtn.Enabled := false
    RecordHotkeyBtn.Enabled := false

    CurrentRecordedGui := Gui("+AlwaysOnTop +ToolWindow", "Record " mode)
    CurrentRecordedGui.BackColor := "FAFAFA"
    CurrentRecordedGui.MarginX := 20
    CurrentRecordedGui.MarginY := 16

    CurrentRecordedGui.SetFont("s11 Bold", "Segoe UI")
    CurrentRecordedGui.Add("Text", "xm ym w420 h28 Center",
        mode = "Action"
            ? "Press the keys you want to HOLD"
            : "Press the shortcut you want to TOGGLE")

    CurrentRecordedGui.SetFont("s9 Norm", "Segoe UI")
    CurrentRecordedGui.Add("Text", "xm y+8 w420 h48 Center c666666",
        mode = "Action"
            ? "Press a combination such as Ctrl + Alt, A + D, or any other keys."
            : "Use modifier keys plus one main key, such as Ctrl + Alt + Space.")

    CurrentRecordedGui.SetFont("s12 Bold")
    RecordedPreviewCtrl := CurrentRecordedGui.Add("Text", "xm y+12 w420 h36 Center c1A1A2E", "Listening...")

    CurrentRecordedGui.SetFont("s9 Norm")
    FinishBtn := CurrentRecordedGui.Add("Button", "xm y+15 w200 h34", "Use these keys")
    CancelBtn := CurrentRecordedGui.Add("Button", "x+10 yp w200 h34", "Cancel")

    FinishBtn.OnEvent("Click", FinishKeyRecorderClick)
    CancelBtn.OnEvent("Click", CancelKeyRecorder)
    CurrentRecordedGui.OnEvent("Close", CancelKeyRecorder)
    CurrentRecordedGui.Show("w460 h240")

    CurrentInputHook := InputHook("V")
    CurrentInputHook.KeyOpt("{All}", "N")
    CurrentInputHook.OnKeyDown := RecordedKeyDown
    CurrentInputHook.Start()
}

RecordedKeyDown(ih, VK, SC) {
    global RecordingMode, RecordedKeys, RecordedPreviewCtrl

    if RecordingMode = ""
        return

    keyName := KeyNameFromVKSC(VK, SC)
    if keyName = ""
        return
    if keyName = "Enter" || keyName = "Escape"
        return

    for existing in RecordedKeys {
        if StrLower(existing) = StrLower(keyName)
            return
    }

    RecordedKeys.Push(keyName)
    try RecordedPreviewCtrl.Text := FormatKeys(RecordedKeys)
}

FinishKeyRecorderClick(*) {
    global RecordingMode, RecordedKeys, RecordedPreviewCtrl
    global ActionKeys, ActivationHotkey

    if RecordedKeys.Length = 0 {
        try RecordedPreviewCtrl.Text := "No keys recorded — press some keys first."
        return
    }

    if RecordingMode = "Action" {
        ActionKeys := RecordedKeys.Clone()
    } else {
        hotkeyString := BuildAHKHotkey(RecordedKeys)
        if hotkeyString = "" {
            try RecordedPreviewCtrl.Text := "Need modifier(s) + one main key."
            return
        }
        ActivationHotkey := hotkeyString
        RegisterActivationHotkey()
    }

    SaveConfig()
    CleanupRecorder()
    UpdateMainUI()
    UpdateWidget()
}

CancelKeyRecorder(*) {
    CleanupRecorder()
}

CleanupRecorder() {
    global RecordingMode, RecordedKeys
    global CurrentRecordedGui, CurrentInputHook, RecordedPreviewCtrl
    global RecordActionBtn, RecordHotkeyBtn

    try {
        if CurrentInputHook {
            CurrentInputHook.OnKeyDown := ""
            CurrentInputHook.Stop()
        }
    }
    CurrentInputHook := 0

    try CurrentRecordedGui.Destroy()
    CurrentRecordedGui := 0
    RecordedPreviewCtrl := 0
    RecordingMode := ""
    RecordedKeys := []

    RecordActionBtn.Enabled := true
    RecordHotkeyBtn.Enabled := true
}

KeyNameFromVKSC(VK, SC) {
    try {
        name := GetKeyName(Format("vk{:02X}", VK))
        if name != ""
            return name
    }
    try {
        name := GetKeyName(Format("sc{:03X}", SC))
        if name != ""
            return name
    }
    return ""
}

BuildAHKHotkey(keys) {
    if keys.Length = 0
        return ""

    modifierPart := ""
    mainKey := ""

    for key in keys {
        lower := StrLower(key)
        switch lower {
            case "lcontrol": modifierPart .= "<^"
            case "rcontrol": modifierPart .= ">^"
            case "control":  modifierPart .= "^"
            case "lalt":     modifierPart .= "<!"
            case "ralt":     modifierPart .= ">!"
            case "alt":      modifierPart .= "!"
            case "lshift":   modifierPart .= "<+"
            case "rshift":   modifierPart .= ">+"
            case "shift":    modifierPart .= "+"
            case "lwin":     modifierPart .= "<#"
            case "rwin":     modifierPart .= ">#"
            case "win":      modifierPart .= "#"
            default:
                if mainKey != ""
                    return ""
                mainKey := key
        }
    }

    if mainKey = ""
        return ""
    return modifierPart mainKey
}

RegisterActivationHotkey() {
    global ActivationHotkey
    static previous := ""

    if previous != ""
        try Hotkey(previous, "Off")

    try Hotkey(ActivationHotkey, ToggleModifier, "On")
    catch {
        ActivationHotkey := "^!Space"
        try Hotkey(ActivationHotkey, ToggleModifier, "On")
    }
    previous := ActivationHotkey
}

; ============================================================
; UI UPDATE
; ============================================================

UpdateMainUI() {
    global MainActionEdit, MainHotkeyEdit, ActionListText, StatusText
    global ActionKeys, ActivationHotkey, IsHeld

    MainActionEdit.Value := FormatKeys(ActionKeys)
    MainHotkeyEdit.Value := FormatAHKHotkey(ActivationHotkey)

    ActionListText.Text := ActionKeys.Length
        ? "Recorded: " FormatKeys(ActionKeys)
        : "No action keys recorded."

    StatusText.Text := IsHeld
        ? "● ACTIVE  |  Holding: " FormatKeys(ActionKeys)
        : "○ OFF  |  Ready"
    StatusText.Opt(IsHeld ? "c008000" : "c666666")
}

FormatKeys(keys) {
    if keys.Length = 0
        return "(none)"
    output := ""
    for i, key in keys {
        if i > 1
            output .= " + "
        output .= DisplayKeyName(key)
    }
    return output
}

DisplayKeyName(key) {
    switch StrLower(key) {
        case "lcontrol":    return "Ctrl"
        case "rcontrol":    return "R-Ctrl"
        case "lalt":        return "Alt"
        case "ralt":        return "R-Alt"
        case "lshift":      return "Shift"
        case "rshift":      return "R-Shift"
        case "lwin":        return "Win"
        case "rwin":        return "R-Win"
        case "space":       return "Space"
        case "backspace":   return "Backspace"
        case "capslock":    return "Caps Lock"
        case "printscreen": return "Print Screen"
        case "scrolllock":  return "Scroll Lock"
        case "numlock":     return "Num Lock"
        case "pgup":        return "Page Up"
        case "pgdn":        return "Page Down"
        default:            return key
    }
}

FormatAHKHotkey(hotkey) {
    text := hotkey

    ; Pass 1: symbols → placeholders (prevents "+" corruption).
    text := StrReplace(text, "<^", "«LC»")
    text := StrReplace(text, ">^", "«RC»")
    text := StrReplace(text, "<!", "«LA»")
    text := StrReplace(text, ">!", "«RA»")
    text := StrReplace(text, "<+", "«LS»")
    text := StrReplace(text, ">+", "«RS»")
    text := StrReplace(text, "<#", "«LW»")
    text := StrReplace(text, ">#", "«RW»")
    text := StrReplace(text, "^", "«C»")
    text := StrReplace(text, "!", "«A»")
    text := StrReplace(text, "+", "«S»")
    text := StrReplace(text, "#", "«W»")

    ; Pass 2: placeholders → readable.
    text := StrReplace(text, "«LC»", "L-Ctrl + ")
    text := StrReplace(text, "«RC»", "R-Ctrl + ")
    text := StrReplace(text, "«LA»", "L-Alt + ")
    text := StrReplace(text, "«RA»", "R-Alt + ")
    text := StrReplace(text, "«LS»", "L-Shift + ")
    text := StrReplace(text, "«RS»", "R-Shift + ")
    text := StrReplace(text, "«LW»", "L-Win + ")
    text := StrReplace(text, "«RW»", "R-Win + ")
    text := StrReplace(text, "«C»", "Ctrl + ")
    text := StrReplace(text, "«A»", "Alt + ")
    text := StrReplace(text, "«S»", "Shift + ")
    text := StrReplace(text, "«W»", "Win + ")

    return text
}

; ============================================================
; WIDGET OPTIONS FROM MAIN GUI
; ============================================================

WidgetSizeChanged(control, *) {
    global WidgetSize
    WidgetSize := control.Text
    SaveConfig()
    UpdateWidgetContent()
    LayoutWidget()
}

WidgetOptionsChanged(*) {
    global ShowWidgetStatus, ShowWidgetName, ShowWidgetKeys, ShowWidgetToggle
    global WidgetStatusCheck, WidgetNameCheck, WidgetKeysCheck, WidgetToggleCheck

    ShowWidgetStatus := WidgetStatusCheck.Value = 1
    ShowWidgetName := WidgetNameCheck.Value = 1
    ShowWidgetKeys := WidgetKeysCheck.Value = 1
    ShowWidgetToggle := WidgetToggleCheck.Value = 1

    SaveConfig()
    UpdateWidget()
}

; ============================================================
; CLEANUP
; ============================================================

Cleanup(*) {
    SaveWidgetPosition()
    ReleaseModifiers(true)
}
