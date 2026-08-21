#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; Universal Modifier Controller v3.3
; AutoHotkey v2
;
; Multi-profile modifier key holder with floating widget.
; NEW: Split mode — each button is an independent draggable widget.
; NEW: Micro size — ultra-compact 24x24 buttons.
; ============================================================

DllCall("SetProcessDPIAware")

global AppName := "Universal Modifier Controller"
global ConfigFile := A_ScriptDir "\UniversalModifierController.ini"

; -----------------------------
; Runtime state
; -----------------------------

global RecordingMode := ""
global RecordedKeys := []
global RecordingProfileIndex := 0

global WidgetVisible := true
global WidgetSize := "Medium"
global WidgetSnap := true
global SplitMode := false  ; NEW: each button = independent widget

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
global SnapCheck := 0
global SplitCheck := 0
global WidgetStatusCheck := 0
global WidgetNameCheck := 0
global WidgetKeysCheck := 0
global WidgetToggleCheck := 0
global ProfileListBox := 0
global ProfileNameEdit := 0
global SelectedProfile := 1

global WidgetTitle := 0
global WidgetMenuBtn := 0

global CurrentRecordedGui := 0
global CurrentInputHook := 0
global RecordedPreviewCtrl := 0

; --- Profiles ---
global Profiles := []
global ProfileWidgetBtns := []
global ProfileWidgetStatus := []
global ProfileWidgetKeys := []

; --- Split mode widgets ---
global SplitWidgets := []  ; Array of { Gui, Hwnd, Btn }

; -----------------------------
; Load & Build
; -----------------------------

LoadConfig()

if Profiles.Length = 0 {
    p := {}
    p.Name := "Ctrl + Alt"
    p.ActionKeys := ["LControl", "LAlt"]
    p.Hotkey := "^!Space"
    p.IsHeld := false
    p.SplitX := -1
    p.SplitY := -1
    Profiles.Push(p)
}

BuildMainGui()
BuildWidgetGui()
SetupTray()
RegisterAllHotkeys()
UpdateMainUI()

if SplitMode
    ShowSplitWidgets()
else
    ShowWidget()

OnExit(Cleanup)
return

; ============================================================
; CONFIG
; ============================================================

LoadConfig() {
    global ConfigFile, Profiles
    global WidgetSize, WidgetSnap, SplitMode
    global ShowWidgetStatus, ShowWidgetName, ShowWidgetKeys, ShowWidgetToggle
    global WidgetPosX, WidgetPosY

    if !FileExist(ConfigFile)
        return

    WidgetSize := IniRead(ConfigFile, "Widget", "Size", "Medium")
    WidgetSnap := IniRead(ConfigFile, "Widget", "Snap", "1") = "1"
    SplitMode := IniRead(ConfigFile, "Widget", "Split", "0") = "1"
    ShowWidgetStatus := IniRead(ConfigFile, "Widget", "ShowStatus", "1") = "1"
    ShowWidgetName := IniRead(ConfigFile, "Widget", "ShowName", "1") = "1"
    ShowWidgetKeys := IniRead(ConfigFile, "Widget", "ShowKeys", "1") = "1"
    ShowWidgetToggle := IniRead(ConfigFile, "Widget", "ShowToggle", "1") = "1"
    WidgetPosX := Integer(IniRead(ConfigFile, "Widget", "PosX", "-1"))
    WidgetPosY := Integer(IniRead(ConfigFile, "Widget", "PosY", "-1"))

    profileCount := Integer(IniRead(ConfigFile, "Profiles", "Count", "0"))
    Profiles := []

    Loop profileCount {
        section := "Profile" A_Index
        p := {}
        p.Name := IniRead(ConfigFile, section, "Name", "Profile " A_Index)
        keysStr := IniRead(ConfigFile, section, "ActionKeys", "")
        p.ActionKeys := keysStr != "" ? StrSplit(keysStr, ",") : []
        p.Hotkey := IniRead(ConfigFile, section, "Hotkey", "")
        p.IsHeld := false
        p.SplitX := Integer(IniRead(ConfigFile, section, "SplitX", "-1"))
        p.SplitY := Integer(IniRead(ConfigFile, section, "SplitY", "-1"))
        Profiles.Push(p)
    }
}

SaveConfig() {
    global ConfigFile, Profiles
    global WidgetSize, WidgetSnap, SplitMode
    global ShowWidgetStatus, ShowWidgetName, ShowWidgetKeys, ShowWidgetToggle
    global WidgetPosX, WidgetPosY

    try {
        IniWrite(WidgetSize, ConfigFile, "Widget", "Size")
        IniWrite(WidgetSnap ? "1" : "0", ConfigFile, "Widget", "Snap")
        IniWrite(SplitMode ? "1" : "0", ConfigFile, "Widget", "Split")
        IniWrite(ShowWidgetStatus ? "1" : "0", ConfigFile, "Widget", "ShowStatus")
        IniWrite(ShowWidgetName ? "1" : "0", ConfigFile, "Widget", "ShowName")
        IniWrite(ShowWidgetKeys ? "1" : "0", ConfigFile, "Widget", "ShowKeys")
        IniWrite(ShowWidgetToggle ? "1" : "0", ConfigFile, "Widget", "ShowToggle")
        IniWrite(String(WidgetPosX), ConfigFile, "Widget", "PosX")
        IniWrite(String(WidgetPosY), ConfigFile, "Widget", "PosY")

        IniWrite(String(Profiles.Length), ConfigFile, "Profiles", "Count")
        for i, p in Profiles {
            section := "Profile" i
            keyString := ""
            for j, key in p.ActionKeys {
                if j > 1
                    keyString .= ","
                keyString .= key
            }
            IniWrite(p.Name, ConfigFile, section, "Name")
            IniWrite(keyString, ConfigFile, section, "ActionKeys")
            IniWrite(p.Hotkey, ConfigFile, section, "Hotkey")
            IniWrite(String(p.SplitX), ConfigFile, section, "SplitX")
            IniWrite(String(p.SplitY), ConfigFile, section, "SplitY")
        }
    }
}

SaveWidgetPosition() {
    global WidgetGui, WidgetPosX, WidgetPosY, WidgetVisible, SplitMode
    if SplitMode || !WidgetVisible || !WidgetGui
        return
    try {
        WidgetGui.GetPos(&x, &y)
        WidgetPosX := x
        WidgetPosY := y
        SaveConfig()
    }
}

SaveSplitPositions() {
    global SplitWidgets, Profiles
    for i, sw in SplitWidgets {
        if i > Profiles.Length
            break
        try {
            sw.Gui.GetPos(&x, &y)
            Profiles[i].SplitX := x
            Profiles[i].SplitY := y
        }
    }
    SaveConfig()
}

; ============================================================
; MAIN GUI
; ============================================================

BuildMainGui() {
    global MainGui
    global MainActionEdit, MainHotkeyEdit, ActionListText, StatusText
    global RecordActionBtn, RecordHotkeyBtn
    global WidgetSize, SizeDrop, SnapCheck, SplitCheck, WidgetSnap, SplitMode
    global WidgetStatusCheck, WidgetNameCheck, WidgetKeysCheck, WidgetToggleCheck
    global ShowWidgetStatus, ShowWidgetName, ShowWidgetKeys, ShowWidgetToggle
    global ProfileListBox, ProfileNameEdit, SelectedProfile, Profiles

    MainGui := Gui("+MinSize520x520", AppName)
    MainGui.BackColor := "F5F5F5"
    MainGui.MarginX := 16
    MainGui.MarginY := 12

    MainGui.SetFont("s14 Bold", "Segoe UI")
    MainGui.Add("Text", "xm ym w640", "Universal Modifier Controller")

    MainGui.SetFont("s8 Norm", "Segoe UI")
    MainGui.Add("Text", "xm y+2 w640 c666666",
        "Create multiple shortcut profiles — each gets its own toggle button on the widget.")

    ; === TAB CONTROL ===
    MainGui.SetFont("s9 Norm", "Segoe UI")
    Tab := MainGui.Add("Tab3", "xm y+10 w650 h500", ["  Profiles  ", "  Widget  "])

    ; ==========================================
    ; TAB 1: PROFILES
    ; ==========================================
    Tab.UseTab(1)

    MainGui.SetFont("s10 Bold", "Segoe UI")
    MainGui.Add("Text", "x30 y68", "Your Profiles")

    MainGui.SetFont("s8 Norm")
    MainGui.Add("Text", "x30 y+3 w600 c666666",
        "Select a profile to edit it. Each one holds a different set of keys.")

    profileNames := []
    for p in Profiles
        profileNames.Push(p.Name "  —  " FormatKeys(p.ActionKeys))

    ProfileListBox := MainGui.Add("ListBox", "x30 y+8 w606 h85 Choose1", profileNames)
    ProfileListBox.OnEvent("Change", ProfileSelected)

    AddBtn := MainGui.Add("Button", "x30 y+6 w90 h26", "+ Add")
    AddBtn.OnEvent("Click", AddProfile)

    RemoveBtn := MainGui.Add("Button", "x+6 yp w90 h26", "− Remove")
    RemoveBtn.OnEvent("Click", RemoveProfile)

    DuplicateBtn := MainGui.Add("Button", "x+6 yp w90 h26", "Duplicate")
    DuplicateBtn.OnEvent("Click", DuplicateProfile)

    MainGui.Add("Text", "x30 y+14 w606 h1 Background999999")

    MainGui.SetFont("s10 Bold")
    MainGui.Add("Text", "x30 y+14", "Edit Selected Profile")
    MainGui.SetFont("s9 Norm")

    MainGui.Add("Text", "x30 y+12 w50 h22 +0x200", "Name:")
    ProfileNameEdit := MainGui.Add("Edit", "x+6 yp w220 h24",
        Profiles.Length > 0 ? Profiles[1].Name : "")
    ProfileNameEdit.OnEvent("Change", ProfileNameChanged)

    MainGui.Add("Text", "x30 y+14 w606 c555555", "Action Keys  (the keys that get held down)")
    MainActionEdit := MainGui.Add("Edit", "x30 y+4 w488 h26 ReadOnly", "")
    RecordActionBtn := MainGui.Add("Button", "x+6 yp w110 h26", "Record Keys")
    RecordActionBtn.OnEvent("Click", StartActionRecorder)
    ActionListText := MainGui.Add("Text", "x30 y+3 w606 h16 c444444 +0x100", "")

    MainGui.Add("Text", "x30 y+10 w606 c555555", "Activation Hotkey  (press anywhere to toggle this profile)")
    MainHotkeyEdit := MainGui.Add("Edit", "x30 y+4 w488 h26 ReadOnly", "")
    RecordHotkeyBtn := MainGui.Add("Button", "x+6 yp w110 h26", "Record Hotkey")
    RecordHotkeyBtn.OnEvent("Click", StartHotkeyRecorder)

    MainGui.Add("Text", "x30 y+14 w50 h18", "Status:")
    StatusText := MainGui.Add("Text", "x+6 yp w300 h18 c666666", "○ OFF")

    MainGui.Add("Text", "x30 y+10 w606 c999999",
        "Note: Fn key is hardware-level on most laptops and invisible to software.")

    ; ==========================================
    ; TAB 2: WIDGET SETTINGS
    ; ==========================================
    Tab.UseTab(2)

    MainGui.SetFont("s10 Bold", "Segoe UI")
    MainGui.Add("Text", "x30 y68", "Appearance")
    MainGui.SetFont("s9 Norm")

    MainGui.Add("Text", "x30 y+14 w40 h22 +0x200", "Size:")

    sizeIndex := 1
    switch WidgetSize {
        case "Micro":       sizeIndex := 1
        case "Extra Small": sizeIndex := 2
        case "Small":       sizeIndex := 3
        case "Medium":      sizeIndex := 4
        case "Large":       sizeIndex := 5
    }
    SizeDrop := MainGui.Add("DropDownList", "x+6 yp w140 Choose" sizeIndex,
        ["Micro", "Extra Small", "Small", "Medium", "Large"])
    SizeDrop.OnEvent("Change", WidgetSizeChanged)

    MainGui.Add("Text", "x30 y+6 w606 c777777",
        "Micro = tiny 24px dots. Extra Small = 40px squares. Others show full details.")

    ; Layout section.
    MainGui.Add("Text", "x30 y+14 w606 h1 Background999999")
    MainGui.SetFont("s10 Bold")
    MainGui.Add("Text", "x30 y+12", "Button Layout")
    MainGui.SetFont("s9 Norm")

    SnapCheck := MainGui.Add("CheckBox", "x30 y+8 Checked" (WidgetSnap ? 1 : 0), "Snap buttons together (compact spacing)")
    SnapCheck.OnEvent("Click", SnapChanged)

    SplitCheck := MainGui.Add("CheckBox", "x30 y+6 Checked" (SplitMode ? 1 : 0), "Split buttons into separate draggable widgets")
    SplitCheck.OnEvent("Click", SplitChanged)

    MainGui.Add("Text", "x30 y+4 w606 c777777",
        "Split mode: each profile becomes its own independent floating button you can place anywhere.")

    ; Display options.
    MainGui.Add("Text", "x30 y+14 w606 h1 Background999999")
    MainGui.SetFont("s10 Bold")
    MainGui.Add("Text", "x30 y+12", "Show on Widget")
    MainGui.SetFont("s9 Norm")

    WidgetStatusCheck := MainGui.Add("CheckBox", "x30 y+10 Checked" (ShowWidgetStatus ? 1 : 0), "Status indicator")
    WidgetNameCheck := MainGui.Add("CheckBox", "x30 y+6 Checked" (ShowWidgetName ? 1 : 0), "App title")
    WidgetKeysCheck := MainGui.Add("CheckBox", "x30 y+6 Checked" (ShowWidgetKeys ? 1 : 0), "Key combination")
    WidgetToggleCheck := MainGui.Add("CheckBox", "x30 y+6 Checked" (ShowWidgetToggle ? 1 : 0), "Toggle buttons")

    WidgetStatusCheck.OnEvent("Click", WidgetOptionsChanged)
    WidgetNameCheck.OnEvent("Click", WidgetOptionsChanged)
    WidgetKeysCheck.OnEvent("Click", WidgetOptionsChanged)
    WidgetToggleCheck.OnEvent("Click", WidgetOptionsChanged)

    ; Quick actions.
    MainGui.Add("Text", "x30 y+14 w606 h1 Background999999")
    MainGui.SetFont("s10 Bold")
    MainGui.Add("Text", "x30 y+12", "Quick Actions")
    MainGui.SetFont("s9 Norm")

    ShowWidgetBtn := MainGui.Add("Button", "x30 y+10 w120 h28", "Show Widget")
    ShowWidgetBtn.OnEvent("Click", ShowWidgetClick)

    HideWidgetBtn := MainGui.Add("Button", "x+8 yp w120 h28", "Hide Widget")
    HideWidgetBtn.OnEvent("Click", HideWidgetClick)

    ReleaseBtn := MainGui.Add("Button", "x+8 yp w140 h28", "Release All Keys")
    ReleaseBtn.OnEvent("Click", ReleaseAllClick)

    MainGui.Add("Text", "x30 y+14 w606 c888888",
        "When modifiers are held (Ctrl/Alt), Windows may interpret scroll as zoom.")

    Tab.UseTab()

    MainGui.OnEvent("Close", MainWindowClose)
    MainGui.OnEvent("Size", MainGuiSize)
    MainGui.Show("w690 h570")
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

ReleaseAllClick(*) {
    ReleaseAllModifiers()
}

ShowWidgetClick(*) {
    global SplitMode
    if SplitMode
        ShowSplitWidgets()
    else
        ShowWidget()
}

HideWidgetClick(*) {
    global SplitMode
    if SplitMode
        HideSplitWidgets()
    else
        HideWidget()
}

SnapChanged(*) {
    global WidgetSnap, SnapCheck, SplitMode
    WidgetSnap := SnapCheck.Value = 1
    SaveConfig()
    if !SplitMode
        UpdateWidget()
}

SplitChanged(*) {
    global SplitMode, SplitCheck, WidgetVisible
    SplitMode := SplitCheck.Value = 1
    SaveConfig()

    if SplitMode {
        ; Hide unified widget, show split widgets.
        HideWidget()
        ShowSplitWidgets()
    } else {
        ; Hide split widgets, show unified widget.
        HideSplitWidgets()
        ShowWidget()
    }
}

; ============================================================
; PROFILE MANAGEMENT
; ============================================================

AddProfile(*) {
    global Profiles, ProfileListBox, SplitMode

    p := {}
    p.Name := "Profile " (Profiles.Length + 1)
    p.ActionKeys := []
    p.Hotkey := ""
    p.IsHeld := false
    p.SplitX := -1
    p.SplitY := -1
    Profiles.Push(p)

    SaveConfig()
    RefreshProfileList()
    ProfileListBox.Choose(Profiles.Length)
    ProfileSelected(ProfileListBox)

    if SplitMode {
        HideSplitWidgets()
        ShowSplitWidgets()
    } else {
        RebuildWidget()
    }
}

RemoveProfile(*) {
    global Profiles, SelectedProfile, ProfileListBox, SplitMode

    if Profiles.Length <= 1 {
        MsgBox("You need at least one profile.", AppName, "Icon!")
        return
    }

    if Profiles[SelectedProfile].IsHeld
        ReleaseProfileKeys(SelectedProfile)

    if Profiles[SelectedProfile].Hotkey != ""
        try Hotkey(Profiles[SelectedProfile].Hotkey, "Off")

    Profiles.RemoveAt(SelectedProfile)
    if SelectedProfile > Profiles.Length
        SelectedProfile := Profiles.Length

    SaveConfig()
    RefreshProfileList()
    ProfileListBox.Choose(SelectedProfile)
    ProfileSelected(ProfileListBox)
    RegisterAllHotkeys()

    if SplitMode {
        HideSplitWidgets()
        ShowSplitWidgets()
    } else {
        RebuildWidget()
    }
}

DuplicateProfile(*) {
    global Profiles, SelectedProfile, ProfileListBox, SplitMode

    src := Profiles[SelectedProfile]
    p := {}
    p.Name := src.Name " (copy)"
    p.ActionKeys := src.ActionKeys.Clone()
    p.Hotkey := ""
    p.IsHeld := false
    p.SplitX := -1
    p.SplitY := -1
    Profiles.Push(p)

    SaveConfig()
    RefreshProfileList()
    ProfileListBox.Choose(Profiles.Length)
    ProfileSelected(ProfileListBox)

    if SplitMode {
        HideSplitWidgets()
        ShowSplitWidgets()
    } else {
        RebuildWidget()
    }
}

RefreshProfileList() {
    global Profiles, ProfileListBox
    ProfileListBox.Delete()
    for p in Profiles
        ProfileListBox.Add([p.Name "  —  " FormatKeys(p.ActionKeys)])
}

ProfileSelected(ctrl, *) {
    global SelectedProfile, Profiles, ProfileNameEdit
    global MainActionEdit, MainHotkeyEdit, ActionListText, StatusText

    SelectedProfile := ctrl.Value
    if SelectedProfile < 1 || SelectedProfile > Profiles.Length
        return

    p := Profiles[SelectedProfile]
    ProfileNameEdit.Value := p.Name
    MainActionEdit.Value := FormatKeys(p.ActionKeys)
    MainHotkeyEdit.Value := p.Hotkey != "" ? FormatAHKHotkey(p.Hotkey) : "(none)"
    ActionListText.Text := p.ActionKeys.Length ? "Recorded: " FormatKeys(p.ActionKeys) : "No keys recorded yet."
    StatusText.Text := p.IsHeld ? "● ACTIVE" : "○ OFF"
    StatusText.Opt(p.IsHeld ? "c008000" : "c666666")
}

ProfileNameChanged(ctrl, *) {
    global SelectedProfile, Profiles, ProfileListBox, SplitMode

    if SelectedProfile < 1 || SelectedProfile > Profiles.Length
        return

    Profiles[SelectedProfile].Name := ctrl.Value
    SaveConfig()
    RefreshProfileList()
    ProfileListBox.Choose(SelectedProfile)

    if SplitMode
        UpdateSplitWidgets()
    else
        RebuildWidget()
}

; ============================================================
; UNIFIED WIDGET (non-split mode)
; ============================================================

BuildWidgetGui() {
    global WidgetGui, WidgetHwnd, WidgetTitle, WidgetMenuBtn
    global Profiles, ProfileWidgetBtns, ProfileWidgetStatus, ProfileWidgetKeys

    WidgetGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    WidgetGui.BackColor := "1E1E2E"
    WidgetGui.MarginX := 14
    WidgetGui.MarginY := 12

    WidgetTitle := WidgetGui.Add("Text", "x14 y12 w150 h20 cE0E0E0", AppName)
    WidgetTitle.SetFont("s9 Bold", "Segoe UI")

    WidgetMenuBtn := WidgetGui.Add("Text", "x172 y10 w30 h22 cBBBBBB Center", "☰")
    WidgetMenuBtn.SetFont("s11", "Segoe UI")
    WidgetMenuBtn.OnEvent("Click", WidgetMenuClick)

    ProfileWidgetBtns := []
    ProfileWidgetStatus := []
    ProfileWidgetKeys := []

    for i, p in Profiles {
        st := WidgetGui.Add("Text", "x14 y0 w188 h16 c888888", "")
        st.SetFont("s8", "Segoe UI")
        ProfileWidgetStatus.Push(st)

        kt := WidgetGui.Add("Text", "x14 y0 w188 h20 cFFFFFF", "")
        kt.SetFont("s9 Bold", "Segoe UI")
        ProfileWidgetKeys.Push(kt)

        btn := WidgetGui.Add("Button", "x14 y0 w188 h28", "")
        btn.SetFont("s8 Bold", "Segoe UI")
        btn.OnEvent("Click", ToggleProfileClick.Bind(i))
        ProfileWidgetBtns.Push(btn)
    }

    WidgetGui.OnEvent("Close", HideWidget)
    WidgetGui.Show("Hide")
    WidgetHwnd := WidgetGui.Hwnd

    OnMessage(0x0084, WidgetHitTest)
}

ToggleProfileClick(index, *) {
    ToggleProfile(index)
}

RebuildWidget() {
    global WidgetGui, WidgetHwnd, WidgetVisible, WidgetPosX, WidgetPosY
    global WidgetTitle, WidgetMenuBtn
    global Profiles, ProfileWidgetBtns, ProfileWidgetStatus, ProfileWidgetKeys

    if WidgetVisible {
        try {
            WidgetGui.GetPos(&x, &y)
            WidgetPosX := x
            WidgetPosY := y
        }
    }

    try WidgetGui.Destroy()

    WidgetGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    WidgetGui.BackColor := "1E1E2E"
    WidgetGui.MarginX := 14
    WidgetGui.MarginY := 12

    WidgetTitle := WidgetGui.Add("Text", "x14 y12 w150 h20 cE0E0E0", AppName)
    WidgetTitle.SetFont("s9 Bold", "Segoe UI")

    WidgetMenuBtn := WidgetGui.Add("Text", "x172 y10 w30 h22 cBBBBBB Center", "☰")
    WidgetMenuBtn.SetFont("s11", "Segoe UI")
    WidgetMenuBtn.OnEvent("Click", WidgetMenuClick)

    ProfileWidgetBtns := []
    ProfileWidgetStatus := []
    ProfileWidgetKeys := []

    for i, p in Profiles {
        st := WidgetGui.Add("Text", "x14 y0 w188 h16 c888888", "")
        st.SetFont("s8", "Segoe UI")
        ProfileWidgetStatus.Push(st)

        kt := WidgetGui.Add("Text", "x14 y0 w188 h20 cFFFFFF", "")
        kt.SetFont("s9 Bold", "Segoe UI")
        ProfileWidgetKeys.Push(kt)

        btn := WidgetGui.Add("Button", "x14 y0 w188 h28", "")
        btn.SetFont("s8 Bold", "Segoe UI")
        btn.OnEvent("Click", ToggleProfileClick.Bind(i))
        ProfileWidgetBtns.Push(btn)
    }

    WidgetGui.OnEvent("Close", HideWidget)
    WidgetGui.Show("Hide")
    WidgetHwnd := WidgetGui.Hwnd

    if WidgetVisible {
        UpdateWidgetContent()
        LayoutWidget()
        if WidgetPosX >= 0 && WidgetPosY >= 0
            WidgetGui.Show("x" WidgetPosX " y" WidgetPosY " NoActivate")
        else
            WidgetGui.Show("x1200 y120 NoActivate")
        SetTimer(ApplyRoundedCorners, -50)
    }
}

WidgetHitTest(wParam, lParam, msg, hwnd) {
    global WidgetHwnd, ProfileWidgetBtns, WidgetMenuBtn, SplitWidgets

    ; Check unified widget.
    if (hwnd = WidgetHwnd) {
        return HandleHitTest(hwnd, lParam, ProfileWidgetBtns, WidgetMenuBtn)
    }

    ; Check split widgets.
    for sw in SplitWidgets {
        if (hwnd = sw.Hwnd) {
            return HandleSplitHitTest(hwnd, lParam, sw.Btn)
        }
    }

    return
}

HandleHitTest(hwnd, lParam, buttons, menuBtn) {
    try WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hwnd)
    catch
        return
    if (winW = 0 || winH = 0)
        return

    screenX := lParam & 0xFFFF
    if (screenX > 0x7FFF)
        screenX -= 0x10000
    screenY := (lParam >> 16) & 0xFFFF
    if (screenY > 0x7FFF)
        screenY -= 0x10000

    cx := screenX - winX
    cy := screenY - winY

    for btn in buttons {
        if btn.Visible {
            try {
                btn.GetPos(&bx, &by, &bw, &bh)
                if (cx >= bx && cx <= bx + bw && cy >= by && cy <= by + bh)
                    return
            }
        }
    }

    if menuBtn.Visible {
        try {
            menuBtn.GetPos(&mx, &my, &mw, &mh)
            if (cx >= mx && cx <= mx + mw && cy >= my && cy <= my + mh)
                return
        }
    }

    return 2  ; HTCAPTION
}

HandleSplitHitTest(hwnd, lParam, btn) {
    try WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hwnd)
    catch
        return
    if (winW = 0 || winH = 0)
        return

    screenX := lParam & 0xFFFF
    if (screenX > 0x7FFF)
        screenX -= 0x10000
    screenY := (lParam >> 16) & 0xFFFF
    if (screenY > 0x7FFF)
        screenY -= 0x10000

    cx := screenX - winX
    cy := screenY - winY

    ; Check if over the button.
    if btn.Visible {
        try {
            btn.GetPos(&bx, &by, &bw, &bh)
            if (cx >= bx && cx <= bx + bw && cy >= by && cy <= by + bh)
                return  ; HTCLIENT — button clickable.
        }
    }

    return 2  ; HTCAPTION — drag the mini widget.
}

ApplyRoundedCorners() {
    global WidgetHwnd
    if !WidgetHwnd
        return
    ApplyRoundToHwnd(WidgetHwnd)
}

ApplyRoundToHwnd(hwnd) {
    if VerCompare(A_OSVersion, "10.0.22000") >= 0 {
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 33, "Int*", 2, "Int", 4)
    } else {
        try {
            WinGetPos(, , &w, &h, "ahk_id " hwnd)
            if (w > 0 && h > 0) {
                hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0,
                    "Int", w + 1, "Int", h + 1, "Int", 12, "Int", 12, "Ptr")
                DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", hRgn, "Int", true)
            }
        }
    }
}

ShowWidget(*) {
    global WidgetGui, WidgetVisible, WidgetPosX, WidgetPosY, SplitMode
    if SplitMode
        return
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
    global WidgetSize, WidgetSnap, WidgetGui, WidgetHwnd
    global ShowWidgetName, ShowWidgetStatus, ShowWidgetKeys, ShowWidgetToggle
    global WidgetTitle, WidgetMenuBtn
    global Profiles, ProfileWidgetBtns, ProfileWidgetStatus, ProfileWidgetKeys

    profileGap := WidgetSnap ? 2 : 12

    ; --- MICRO ---
    if WidgetSize = "Micro" {
        WidgetTitle.Visible := false
        WidgetMenuBtn.Visible := false

        pad := 4
        btnSize := 24
        gap := WidgetSnap ? 2 : 6
        x := pad

        for i, btn in ProfileWidgetBtns {
            ProfileWidgetStatus[i].Visible := false
            ProfileWidgetKeys[i].Visible := false
            btn.SetFont("s7 Bold", "Segoe UI")
            btn.Move(x, pad, btnSize, btnSize)
            btn.Visible := true
            x += btnSize + gap
        }

        totalW := x - gap + pad
        totalH := btnSize + (pad * 2)
        WidgetGui.Move(, , totalW, totalH)
        SetTimer(ApplyRoundedCorners, -50)
        return
    }

    ; --- EXTRA SMALL ---
    if WidgetSize = "Extra Small" {
        WidgetTitle.Visible := false
        WidgetMenuBtn.Visible := false

        pad := 6
        btnSize := 40
        gap := WidgetSnap ? 2 : 8
        x := pad

        for i, btn in ProfileWidgetBtns {
            ProfileWidgetStatus[i].Visible := false
            ProfileWidgetKeys[i].Visible := false
            btn.SetFont("s9 Bold", "Segoe UI")
            btn.Move(x, pad, btnSize, btnSize)
            btn.Visible := true
            x += btnSize + gap
        }

        totalW := x - gap + pad
        totalH := btnSize + (pad * 2)
        WidgetGui.Move(, , totalW, totalH)
        SetTimer(ApplyRoundedCorners, -50)
        return
    }

    ; --- Standard sizes ---
    pad := 14
    baseW := WidgetSize = "Large" ? 280 : WidgetSize = "Medium" ? 230 : 195
    contentW := baseW - (pad * 2)
    y := pad

    if ShowWidgetName {
        WidgetTitle.SetFont(WidgetSize = "Large" ? "s10 Bold" : WidgetSize = "Medium" ? "s9 Bold" : "s8 Bold", "Segoe UI")
        WidgetTitle.Move(pad, y, contentW - 36, 20)
        WidgetTitle.Visible := true
        y += 24
    } else {
        WidgetTitle.Visible := false
        y += 4
    }

    WidgetMenuBtn.Move(baseW - pad - 28, pad - 2, 28, 22)
    WidgetMenuBtn.Visible := true

    for i, btn in ProfileWidgetBtns {
        if i > 1
            y += profileGap

        if ShowWidgetStatus {
            ProfileWidgetStatus[i].SetFont(WidgetSize = "Large" ? "s9" : "s8", "Segoe UI")
            ProfileWidgetStatus[i].Move(pad, y, contentW, 16)
            ProfileWidgetStatus[i].Visible := true
            y += 18
        } else {
            ProfileWidgetStatus[i].Visible := false
        }

        if ShowWidgetKeys {
            ProfileWidgetKeys[i].SetFont(WidgetSize = "Large" ? "s10 Bold" : "s9 Bold", "Segoe UI")
            ProfileWidgetKeys[i].Move(pad, y, contentW, 20)
            ProfileWidgetKeys[i].Visible := true
            y += 22
        } else {
            ProfileWidgetKeys[i].Visible := false
        }

        if ShowWidgetToggle {
            btnH := WidgetSize = "Large" ? 30 : 26
            btn.SetFont(WidgetSize = "Large" ? "s9 Bold" : "s8 Bold", "Segoe UI")
            btn.Move(pad, y, contentW, btnH)
            btn.Visible := true
            y += btnH + 2
        } else {
            btn.Visible := false
        }
    }

    height := y + pad
    if height < 56
        height := 56

    WidgetGui.Move(, , baseW, height)
    SetTimer(ApplyRoundedCorners, -50)
}

UpdateWidgetContent() {
    global Profiles, ProfileWidgetBtns, ProfileWidgetStatus, ProfileWidgetKeys
    global WidgetVisible, WidgetSize, AppName, WidgetTitle

    if !WidgetVisible
        return

    WidgetTitle.Text := AppName

    for i, btn in ProfileWidgetBtns {
        if i > Profiles.Length
            break
        p := Profiles[i]

        ProfileWidgetStatus[i].Text := p.Name " — " (p.IsHeld ? "● ON" : "○ OFF")
        ProfileWidgetStatus[i].Opt(p.IsHeld ? "c6FE38A" : "c888888")
        ProfileWidgetKeys[i].Text := FormatKeys(p.ActionKeys)

        if (WidgetSize = "Extra Small" || WidgetSize = "Micro")
            btn.Text := p.IsHeld ? "■" : "▶"
        else
            btn.Text := p.IsHeld ? p.Name ": OFF" : p.Name ": ON"
    }
}

UpdateWidget() {
    global WidgetVisible, SplitMode
    if SplitMode {
        UpdateSplitWidgets()
        return
    }
    if !WidgetVisible
        return
    UpdateWidgetContent()
    LayoutWidget()
}

; ============================================================
; SPLIT WIDGETS (each profile = own draggable window)
; ============================================================

ShowSplitWidgets() {
    global SplitWidgets, Profiles, WidgetSize, WidgetVisible

    ; Destroy old split widgets.
    for sw in SplitWidgets
        try sw.Gui.Destroy()
    SplitWidgets := []

    WidgetVisible := true

    ; Determine button size.
    btnSize := 40
    pad := 6
    switch WidgetSize {
        case "Micro":       btnSize := 24, pad := 4
        case "Extra Small": btnSize := 40, pad := 6
        case "Small":       btnSize := 52, pad := 8
        case "Medium":      btnSize := 64, pad := 10
        case "Large":       btnSize := 80, pad := 12
    }

    ; Default spread position.
    baseX := 1200
    baseY := 120

    for i, p in Profiles {
        sw := {}

        sw.Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
        sw.Gui.BackColor := "1E1E2E"
        sw.Gui.MarginX := pad
        sw.Gui.MarginY := pad

        ; Button.
        fontSize := WidgetSize = "Micro" ? "s7" : WidgetSize = "Extra Small" ? "s9" : "s10"
        sw.Btn := sw.Gui.Add("Button", "x" pad " y" pad " w" btnSize " h" btnSize, p.IsHeld ? "■" : "▶")
        sw.Btn.SetFont(fontSize " Bold", "Segoe UI")
        sw.Btn.OnEvent("Click", ToggleProfileClick.Bind(i))

        totalSize := btnSize + (pad * 2)
        sw.Gui.Show("Hide")
        sw.Hwnd := sw.Gui.Hwnd

        ; Position.
        posX := p.SplitX >= 0 ? p.SplitX : baseX + ((i - 1) * (totalSize + 10))
        posY := p.SplitY >= 0 ? p.SplitY : baseY

        sw.Gui.Show("x" posX " y" posY " w" totalSize " h" totalSize " NoActivate")
        SetTimer(ApplyRoundToHwndTimer.Bind(sw.Hwnd), -50)

        SplitWidgets.Push(sw)
    }
}

ApplyRoundToHwndTimer(hwnd, *) {
    ApplyRoundToHwnd(hwnd)
}

HideSplitWidgets() {
    global SplitWidgets, WidgetVisible

    SaveSplitPositions()
    for sw in SplitWidgets
        try sw.Gui.Destroy()
    SplitWidgets := []
    WidgetVisible := false
}

UpdateSplitWidgets() {
    global SplitWidgets, Profiles, WidgetSize

    for i, sw in SplitWidgets {
        if i > Profiles.Length
            break
        p := Profiles[i]
        sw.Btn.Text := p.IsHeld ? "■" : "▶"
    }
}

; ============================================================
; PROFILE TOGGLE
; ============================================================

ToggleProfile(index) {
    global Profiles
    if index < 1 || index > Profiles.Length
        return
    if Profiles[index].IsHeld
        ReleaseProfileKeys(index)
    else
        HoldProfileKeys(index)
}

HoldProfileKeys(index) {
    global Profiles
    if index < 1 || index > Profiles.Length
        return
    if Profiles[index].IsHeld
        return
    for key in Profiles[index].ActionKeys
        SafeSend("{" key " Down}")
    Profiles[index].IsHeld := true
    UpdateMainUI()
    UpdateWidget()
}

ReleaseProfileKeys(index) {
    global Profiles
    if index < 1 || index > Profiles.Length
        return
    for key in Profiles[index].ActionKeys
        SafeSend("{" key " Up}")
    Profiles[index].IsHeld := false
    UpdateMainUI()
    UpdateWidget()
}

ReleaseAllModifiers(forceAll := false) {
    global Profiles
    for i, p in Profiles {
        if p.IsHeld {
            for key in p.ActionKeys
                SafeSend("{" key " Up}")
            Profiles[i].IsHeld := false
        }
    }
    if forceAll
        SafeSend("{Ctrl Up}{Alt Up}{Shift Up}{LWin Up}{RWin Up}")
    UpdateMainUI()
    UpdateWidget()
}

SafeSend(sequence) {
    try Send(sequence)
}

; ============================================================
; HOTKEYS
; ============================================================

RegisterAllHotkeys() {
    global Profiles
    static registeredHotkeys := []

    for hk in registeredHotkeys
        try Hotkey(hk, "Off")
    registeredHotkeys := []

    for i, p in Profiles {
        if p.Hotkey = ""
            continue
        try {
            Hotkey(p.Hotkey, ToggleProfileHotkey.Bind(i), "On")
            registeredHotkeys.Push(p.Hotkey)
        }
    }
}

ToggleProfileHotkey(index, *) {
    ToggleProfile(index)
}

; ============================================================
; WIDGET MENU
; ============================================================

WidgetMenuClick(*) {
    global Profiles, WidgetSize, WidgetSnap, SplitMode
    global ShowWidgetStatus, ShowWidgetName, ShowWidgetKeys, ShowWidgetToggle

    local wMenu := Menu()

    for i, p in Profiles
        wMenu.Add(p.Name ": " (p.IsHeld ? "Turn OFF" : "Turn ON"), ToggleProfileHotkey.Bind(i))

    wMenu.Add()
    wMenu.Add("Release all", ReleaseAllClick)
    wMenu.Add()

    local sizeSub := Menu()
    sizeSub.Add("Micro", SetSizeMicro)
    sizeSub.Add("Extra Small", SetSizeXS)
    sizeSub.Add("Small", SetSizeS)
    sizeSub.Add("Medium", SetSizeM)
    sizeSub.Add("Large", SetSizeL)
    sizeSub.Check(WidgetSize)
    wMenu.Add("Widget size", sizeSub)

    local layoutSub := Menu()
    layoutSub.Add("Snap together", ToggleSnapMenu)
    layoutSub.Add("Split apart", ToggleSplitMenu)
    if WidgetSnap
        layoutSub.Check("Snap together")
    if SplitMode
        layoutSub.Check("Split apart")
    wMenu.Add("Layout", layoutSub)

    local contentSub := Menu()
    contentSub.Add("Status", ToggleWidgetStatus)
    contentSub.Add("App title", ToggleWidgetName)
    contentSub.Add("Key combination", ToggleWidgetKeys)
    contentSub.Add("Toggle buttons", ToggleWidgetToggle)
    if ShowWidgetStatus
        contentSub.Check("Status")
    if ShowWidgetName
        contentSub.Check("App title")
    if ShowWidgetKeys
        contentSub.Check("Key combination")
    if ShowWidgetToggle
        contentSub.Check("Toggle buttons")
    wMenu.Add("Show/Hide", contentSub)

    wMenu.Add()
    wMenu.Add("Open settings", ShowMainGui)
    wMenu.Add("Hide widget", HideWidgetClick)
    wMenu.Add()
    wMenu.Add("Exit", ExitClick)

    wMenu.Show()
}

SetSizeMicro(*) {
    SetWidgetSize("Micro")
}
SetSizeXS(*) {
    SetWidgetSize("Extra Small")
}
SetSizeS(*) {
    SetWidgetSize("Small")
}
SetSizeM(*) {
    SetWidgetSize("Medium")
}
SetSizeL(*) {
    SetWidgetSize("Large")
}
ExitClick(*) {
    ExitApp()
}
ToggleSnapMenu(*) {
    global WidgetSnap, SnapCheck, SplitMode
    WidgetSnap := !WidgetSnap
    SnapCheck.Value := WidgetSnap ? 1 : 0
    SaveConfig()
    if !SplitMode
        UpdateWidget()
}
ToggleSplitMenu(*) {
    global SplitMode, SplitCheck
    SplitMode := !SplitMode
    SplitCheck.Value := SplitMode ? 1 : 0
    SaveConfig()
    if SplitMode {
        HideWidget()
        ShowSplitWidgets()
    } else {
        HideSplitWidgets()
        ShowWidget()
    }
}

SetWidgetSize(size) {
    global WidgetSize, SplitMode
    WidgetSize := size
    SaveConfig()
    if SplitMode {
        HideSplitWidgets()
        ShowSplitWidgets()
    } else {
        UpdateWidgetContent()
        LayoutWidget()
    }
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
    Tray.Add("Open settings", ShowMainGui)
    Tray.Add()
    Tray.Add("Show widget", ShowWidgetClick)
    Tray.Add("Hide widget", HideWidgetClick)
    Tray.Add()
    Tray.Add("Release all", ReleaseAllClick)
    Tray.Add()
    Tray.Add("Exit", ExitClick)
    Tray.Default := "Open settings"
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
; RECORDERS
; ============================================================

StartActionRecorder(*) {
    global SelectedProfile, RecordingProfileIndex
    RecordingProfileIndex := SelectedProfile
    StartKeyRecorder("Action")
}

StartHotkeyRecorder(*) {
    global SelectedProfile, RecordingProfileIndex
    RecordingProfileIndex := SelectedProfile
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
        mode = "Action" ? "Press the keys you want to HOLD" : "Press the shortcut you want to TOGGLE")

    CurrentRecordedGui.SetFont("s9 Norm", "Segoe UI")
    CurrentRecordedGui.Add("Text", "xm y+8 w420 h48 Center c666666",
        mode = "Action"
            ? "Press any keys including Enter, Escape, etc. Click the buttons below when done."
            : "Use modifier keys plus one main key, such as Ctrl + Alt + Space.")

    CurrentRecordedGui.SetFont("s12 Bold")
    RecordedPreviewCtrl := CurrentRecordedGui.Add("Text", "xm y+12 w420 h36 Center c1A1A2E", "Listening...")

    CurrentRecordedGui.SetFont("s9 Norm")
    FinishBtn := CurrentRecordedGui.Add("Button", "xm y+15 w200 h34", "✓ Use These Keys")
    CancelBtn := CurrentRecordedGui.Add("Button", "x+10 yp w200 h34", "✕ Cancel")

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
    for existing in RecordedKeys {
        if StrLower(existing) = StrLower(keyName)
            return
    }
    RecordedKeys.Push(keyName)
    try RecordedPreviewCtrl.Text := FormatKeys(RecordedKeys)
}

FinishKeyRecorderClick(*) {
    global RecordingMode, RecordedKeys, RecordedPreviewCtrl
    global Profiles, RecordingProfileIndex

    if RecordedKeys.Length = 0 {
        try RecordedPreviewCtrl.Text := "No keys recorded — press some keys."
        return
    }
    if RecordingProfileIndex < 1 || RecordingProfileIndex > Profiles.Length {
        CleanupRecorder()
        return
    }

    if RecordingMode = "Action" {
        Profiles[RecordingProfileIndex].ActionKeys := RecordedKeys.Clone()
    } else {
        hotkeyString := BuildAHKHotkey(RecordedKeys)
        if hotkeyString = "" {
            try RecordedPreviewCtrl.Text := "Need modifier(s) + one main key."
            return
        }
        Profiles[RecordingProfileIndex].Hotkey := hotkeyString
        RegisterAllHotkeys()
    }

    SaveConfig()
    CleanupRecorder()
    RefreshProfileList()
    global ProfileListBox, SelectedProfile, SplitMode
    ProfileListBox.Choose(SelectedProfile)
    ProfileSelected(ProfileListBox)
    UpdateMainUI()
    if SplitMode {
        HideSplitWidgets()
        ShowSplitWidgets()
    } else {
        RebuildWidget()
    }
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

; ============================================================
; UI UPDATE
; ============================================================

UpdateMainUI() {
    global SelectedProfile, Profiles
    global MainActionEdit, MainHotkeyEdit, ActionListText, StatusText

    if SelectedProfile < 1 || SelectedProfile > Profiles.Length
        return
    p := Profiles[SelectedProfile]
    MainActionEdit.Value := FormatKeys(p.ActionKeys)
    MainHotkeyEdit.Value := p.Hotkey != "" ? FormatAHKHotkey(p.Hotkey) : "(none)"
    ActionListText.Text := p.ActionKeys.Length ? "Recorded: " FormatKeys(p.ActionKeys) : "No keys recorded yet."
    StatusText.Text := p.IsHeld ? "● ACTIVE" : "○ OFF"
    StatusText.Opt(p.IsHeld ? "c008000" : "c666666")
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
        case "enter":       return "Enter"
        case "escape":      return "Escape"
        case "backspace":   return "Backspace"
        case "capslock":    return "Caps Lock"
        case "tab":         return "Tab"
        case "printscreen": return "Print Screen"
        case "scrolllock":  return "Scroll Lock"
        case "numlock":     return "Num Lock"
        case "pgup":        return "Page Up"
        case "pgdn":        return "Page Down"
        case "delete":      return "Delete"
        case "insert":      return "Insert"
        case "home":        return "Home"
        case "end":         return "End"
        default:            return key
    }
}

FormatAHKHotkey(hotkey) {
    text := hotkey
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
    global WidgetSize, SplitMode
    WidgetSize := control.Text
    SaveConfig()
    if SplitMode {
        HideSplitWidgets()
        ShowSplitWidgets()
    } else {
        UpdateWidgetContent()
        LayoutWidget()
    }
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
    global SplitMode
    if SplitMode
        SaveSplitPositions()
    else
        SaveWidgetPosition()
    ReleaseAllModifiers(true)
}
