B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=13.4
@EndOfDesignText@
#Region Shared Files
#CustomBuildAction: folders ready, %WINDIR%\System32\Robocopy.exe,"..\..\Shared Files" "..\Files"
'Ctrl + click to sync files: ide://run?file=%WINDIR%\System32\Robocopy.exe&args=..\..\Shared+Files&args=..\Files&FilesSync=True
#End Region

Sub Class_Globals
	Private Root As B4XView
	Private xui As XUI
	Private Store As KeyValueStore
	Private RuntimePermission As RuntimePermissions
	Private WakeState As PhoneWakeState

	Private Const STATION_2SM As String = "2sm"
	Private Const STATION_VISION As String = "vision"
	Private Const DEFAULT_2SM_URL As String = "https://cast4.asurahosting.com/proxy/2sm1269/stream"
	Private Const DEFAULT_VISION_URL As String = "https://streams2.vision.org.au/vision128.mp3"

	Private Const STATE_STOPPED As String = "stopped"
	Private Const STATE_CONNECTING As String = "connecting"
	Private Const STATE_PLAYING As String = "playing"
	Private Const STATE_PAUSED As String = "paused"
	Private Const STATE_RETRYING As String = "retrying"
	Private Const STATE_ERROR As String = "error"

	Private ColorBackground As Int = 0xFFF5F7FB
	Private ColorCard As Int = 0xFFFFFFFF
	Private ColorInk As Int = 0xFF172033
	Private ColorMuted As Int = 0xFF667085
	Private ColorBorder As Int = 0xFFE4E7EC
	Private Color2SM As Int = 0xFFD62839
	Private ColorVision As Int = 0xFF6246EA
	Private ColorSuccess As Int = 0xFF16875B
	Private ColorWarning As Int = 0xFFB54708
	Private ColorError As Int = 0xFFB42318

	Private pnlMain As B4XView
	Private pnlPlayer As B4XView
	Private pnlSettingsOverlay As B4XView
	Private pnlSettingsCard As B4XView
	Private lblTitle As B4XView
	Private lblSubtitle As B4XView
	Private lblStationPrompt As B4XView
	Private lblNowPlaying As B4XView
	Private lblStatus As B4XView
	Private lblVolume As B4XView
	Private lblFooter As B4XView
	Private lblSettingsTitle As B4XView
	Private lblSettingsHint As B4XView
	Private lbl2SMUrl As B4XView
	Private lblVisionUrl As B4XView
	Private btn2SM As B4XView
	Private btnVision As B4XView
	Private btnPlayPause As B4XView
	Private btnVolumeDown As B4XView
	Private btnVolumeUp As B4XView
	Private btnSaveSettings As B4XView
	Private btnResetStreams As B4XView
	Private btnTeamViewer As B4XView
	Private btnCloseSettings As B4XView
	Private sbVolume As SeekBar
	Private chkAutoPlay As CheckBox
	Private chkKeepAwake As CheckBox
	Private txt2SMUrl As EditText
	Private txtVisionUrl As EditText

	Private SelectedStation As String
	Private PlaybackState As String
	Private StatusMessage As String
	Private Url2SM As String
	Private UrlVision As String
	Private AutoPlay As Boolean
	Private KeepAwake As Boolean
	Private CurrentVolume As Int
End Sub

Public Sub Initialize
End Sub

Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	Store.Initialize(File.DirInternal, "radio_settings.dat")
	LoadSettings
	CreateInterface
	ResizeToNativeParent
	CallSubDelayed(Me, "ResizeAfterPageShown")
	RequestNotificationPermission
	SyncFromAudioService
	If AutoPlay And PlaybackState <> STATE_PLAYING And PlaybackState <> STATE_CONNECTING Then
		StartSelectedStation
	End If
End Sub

Public Sub ResizeToNativeParent
	#if B4A
	Dim NativeParent As Activity = B4XPages.GetNativeParent(Me)
	Dim PageWidth As Int = NativeParent.Width
	Dim PageHeight As Int = NativeParent.Height
	If PageWidth <= 0 Or PageHeight <= 0 Then
		PageWidth = Root.Width
		PageHeight = Root.Height
	End If
	Root.SetLayoutAnimated(0, 0, 0, PageWidth, PageHeight)
	B4XPage_Resize(PageWidth, PageHeight)
	#else
	B4XPage_Resize(Root.Width, Root.Height)
	#End If
End Sub

Private Sub ResizeAfterPageShown
	ResizeToNativeParent
End Sub

Private Sub LoadSettings
	SelectedStation = Store.GetDefault("selected_station", STATION_2SM)
	If SelectedStation <> STATION_2SM And SelectedStation <> STATION_VISION Then SelectedStation = STATION_2SM
	Url2SM = Store.GetDefault("url_2sm", DEFAULT_2SM_URL)
	UrlVision = Store.GetDefault("url_vision", DEFAULT_VISION_URL)
	AutoPlay = Store.GetDefault("auto_play", False)
	KeepAwake = Store.GetDefault("keep_awake", False)
	CurrentVolume = Store.GetDefault("volume", 60)
	CurrentVolume = Max(0, Min(100, CurrentVolume))
	PlaybackState = STATE_STOPPED
	StatusMessage = "Ready"
End Sub

Private Sub CreateInterface
	Root.RemoveAllViews
	Root.Color = ColorBackground

	pnlMain = xui.CreatePanel("")
	Root.AddView(pnlMain, 0, 0, Root.Width, Root.Height)
	pnlMain.Color = ColorBackground

	lblTitle = CreateLabel(pnlMain, "Title", "GRANDMA'S RADIO", 30, True, ColorInk, "CENTER")
	lblSubtitle = CreateLabel(pnlMain, "", "Two favourite stations. No fiddling required.", 16, False, ColorMuted, "CENTER")
	lblStationPrompt = CreateLabel(pnlMain, "", "CHOOSE A STATION", 14, True, ColorMuted, "LEFT")

	btn2SM = CreateButton(pnlMain, "Station", "2SM" & CRLF & "SUPER NETWORK", 22, True)
	btn2SM.Tag = STATION_2SM
	btnVision = CreateButton(pnlMain, "Station", "VISION" & CRLF & "CHRISTIAN RADIO", 22, True)
	btnVision.Tag = STATION_VISION

	pnlPlayer = xui.CreatePanel("")
	pnlMain.AddView(pnlPlayer, 0, 0, 1dip, 1dip)
	pnlPlayer.SetColorAndBorder(ColorCard, 1dip, ColorBorder, 24dip)
	lblNowPlaying = CreateLabel(pnlPlayer, "", "", 24, True, ColorInk, "CENTER")
	lblStatus = CreateLabel(pnlPlayer, "", "Ready", 16, True, ColorSuccess, "CENTER")
	btnPlayPause = CreateButton(pnlPlayer, "PlayPause", "PLAY", 28, True)
	lblVolume = CreateLabel(pnlPlayer, "", "VOLUME 60%", 17, True, ColorInk, "CENTER")
	btnVolumeDown = CreateButton(pnlPlayer, "VolumeDown", "–", 32, True)
	btnVolumeUp = CreateButton(pnlPlayer, "VolumeUp", "+", 30, True)
	sbVolume.Initialize("Volume")
	pnlPlayer.AddView(sbVolume, 0, 0, 1dip, 1dip)
	sbVolume.Max = 100
	sbVolume.Value = CurrentVolume

	lblFooter = CreateLabel(pnlMain, "", "Long-press the title for settings", 13, False, ColorMuted, "CENTER")

	CreateSettingsPanel
	RefreshInterface
End Sub

Private Sub CreateSettingsPanel
	pnlSettingsOverlay = xui.CreatePanel("SettingsOverlay")
	Root.AddView(pnlSettingsOverlay, 0, 0, Root.Width, Root.Height)
	pnlSettingsOverlay.Color = 0xD9172033
	pnlSettingsOverlay.Visible = False

	pnlSettingsCard = xui.CreatePanel("")
	pnlSettingsOverlay.AddView(pnlSettingsCard, 0, 0, 1dip, 1dip)
	pnlSettingsCard.SetColorAndBorder(ColorCard, 1dip, ColorBorder, 24dip)

	lblSettingsTitle = CreateLabel(pnlSettingsCard, "", "RADIO SETTINGS", 24, True, ColorInk, "LEFT")
	lblSettingsHint = CreateLabel(pnlSettingsCard, "", "These controls are tucked away to keep the main screen simple.", 14, False, ColorMuted, "LEFT")
	lbl2SMUrl = CreateLabel(pnlSettingsCard, "", "2SM stream address", 14, True, ColorInk, "LEFT")
	lblVisionUrl = CreateLabel(pnlSettingsCard, "", "Vision stream address", 14, True, ColorInk, "LEFT")

	txt2SMUrl.Initialize("")
	pnlSettingsCard.AddView(txt2SMUrl, 0, 0, 1dip, 1dip)
	txt2SMUrl.SingleLine = True
	txt2SMUrl.TextSize = 14
	txt2SMUrl.TextColor = ColorInk
	Dim x2SM As B4XView = txt2SMUrl
	x2SM.SetColorAndBorder(0xFFF8FAFC, 1dip, ColorBorder, 12dip)

	txtVisionUrl.Initialize("")
	pnlSettingsCard.AddView(txtVisionUrl, 0, 0, 1dip, 1dip)
	txtVisionUrl.SingleLine = True
	txtVisionUrl.TextSize = 14
	txtVisionUrl.TextColor = ColorInk
	Dim xVision As B4XView = txtVisionUrl
	xVision.SetColorAndBorder(0xFFF8FAFC, 1dip, ColorBorder, 12dip)

	chkAutoPlay.Initialize("")
	pnlSettingsCard.AddView(chkAutoPlay, 0, 0, 1dip, 1dip)
	chkAutoPlay.Text = "Play automatically when the app opens"
	chkAutoPlay.TextSize = 16
	chkAutoPlay.TextColor = ColorInk

	chkKeepAwake.Initialize("")
	pnlSettingsCard.AddView(chkKeepAwake, 0, 0, 1dip, 1dip)
	chkKeepAwake.Text = "Keep the screen awake while playing"
	chkKeepAwake.TextSize = 16
	chkKeepAwake.TextColor = ColorInk

	btnSaveSettings = CreateButton(pnlSettingsCard, "SaveSettings", "SAVE SETTINGS", 17, True)
	btnResetStreams = CreateButton(pnlSettingsCard, "ResetStreams", "RESET STREAM ADDRESSES", 14, True)
	btnTeamViewer = CreateButton(pnlSettingsCard, "TeamViewer", "OPEN / INSTALL REMOTE SUPPORT", 14, True)
	btnCloseSettings = CreateButton(pnlSettingsCard, "CloseSettings", "CLOSE", 15, True)
End Sub

Private Sub CreateLabel(Parent As B4XView, EventName As String, Text As String, TextSize As Float, Bold As Boolean, TextColor As Int, Alignment As String) As B4XView
	Dim NativeLabel As Label
	NativeLabel.Initialize(EventName)
	Dim View As B4XView = NativeLabel
	View.Text = Text
	View.TextSize = TextSize
	View.TextColor = TextColor
	If Bold Then
		View.Font = xui.CreateDefaultBoldFont(TextSize)
	Else
		View.Font = xui.CreateDefaultFont(TextSize)
	End If
	View.SetTextAlignment("CENTER", Alignment)
	Parent.AddView(View, 0, 0, 1dip, 1dip)
	Return View
End Sub

Private Sub CreateButton(Parent As B4XView, EventName As String, Text As String, TextSize As Float, Bold As Boolean) As B4XView
	Dim NativeButton As Button
	NativeButton.Initialize(EventName)
	Dim View As B4XView = NativeButton
	View.Text = Text
	View.TextSize = TextSize
	View.TextColor = xui.Color_White
	If Bold Then View.Font = xui.CreateDefaultBoldFont(TextSize)
	View.SetTextAlignment("CENTER", "CENTER")
	Parent.AddView(View, 0, 0, 1dip, 1dip)
	Return View
End Sub

Private Sub B4XPage_Resize (Width As Int, Height As Int)
	If pnlMain.IsInitialized = False Then Return
	pnlMain.SetLayoutAnimated(0, 0, 0, Width, Height)

	Dim Tablet As Boolean = Width >= 600dip
	Dim ShortScreen As Boolean = Height < 690dip
	Dim PagePadding As Int = 16dip
	If Tablet Then PagePadding = 28dip
	Dim ContentWidth As Int = Min(620dip, Width - PagePadding * 2)
	Dim ContentLeft As Int = (Width - ContentWidth) / 2
	Dim Top As Int = 18dip
	If Tablet Then Top = 28dip
	If Tablet Then
		Dim DesiredTitleHeight As Int = 54dip
		Dim DesiredSubtitleHeight As Int = IIf(ShortScreen, 8dip, 38dip)
		Dim DesiredStationHeight As Int = IIf(ShortScreen, 86dip, 126dip)
		Dim DesiredBlockHeight As Int = DesiredTitleHeight + DesiredSubtitleHeight + 32dip + DesiredStationHeight + 16dip + 372dip + 4dip + 34dip
		If Height > DesiredBlockHeight Then Top = Max(28dip, (Height - DesiredBlockHeight) / 2)
	End If

	Dim TitleHeight As Int = 44dip
	If Tablet Then TitleHeight = 54dip
	lblTitle.SetLayoutAnimated(0, ContentLeft, Top, ContentWidth, TitleHeight)
	lblTitle.TextSize = IIf(Tablet, 34, 29)
	Top = Top + TitleHeight
	lblSubtitle.SetLayoutAnimated(0, ContentLeft, Top, ContentWidth, 28dip)
	If ShortScreen Then lblSubtitle.Visible = False Else lblSubtitle.Visible = True
	If lblSubtitle.Visible Then Top = Top + 38dip Else Top = Top + 8dip

	lblStationPrompt.SetLayoutAnimated(0, ContentLeft, Top, ContentWidth, 24dip)
	Top = Top + 32dip
	Dim Gap As Int = 12dip
	If Tablet Then Gap = 18dip
	Dim StationWidth As Int = (ContentWidth - Gap) / 2
	Dim StationHeight As Int = 98dip
	If Tablet Then StationHeight = 126dip
	If ShortScreen Then StationHeight = 86dip
	btn2SM.SetLayoutAnimated(0, ContentLeft, Top, StationWidth, StationHeight)
	btnVision.SetLayoutAnimated(0, ContentLeft + StationWidth + Gap, Top, StationWidth, StationHeight)
	Top = Top + StationHeight + 16dip

	Dim FooterHeight As Int = 34dip
	Dim PlayerHeight As Int = Min(IIf(Tablet, 372dip, 326dip), Height - Top - FooterHeight - 14dip)
	PlayerHeight = Max(286dip, PlayerHeight)
	pnlPlayer.SetLayoutAnimated(0, ContentLeft, Top, ContentWidth, PlayerHeight)
	LayoutPlayer(PlayerHeight, Tablet)
	Top = Top + PlayerHeight + 4dip
	lblFooter.SetLayoutAnimated(0, ContentLeft, Top, ContentWidth, FooterHeight)

	LayoutSettings(Width, Height)
End Sub

Private Sub LayoutPlayer(PlayerHeight As Int, Tablet As Boolean)
	Dim InnerPadding As Int = 18dip
	If Tablet Then InnerPadding = 24dip
	Dim InnerWidth As Int = pnlPlayer.Width - InnerPadding * 2
	Dim Top As Int = 14dip
	lblNowPlaying.SetLayoutAnimated(0, InnerPadding, Top, InnerWidth, 44dip)
	Top = Top + 46dip
	Dim StatusWidth As Int = Min(250dip, InnerWidth)
	lblStatus.SetLayoutAnimated(0, (pnlPlayer.Width - StatusWidth) / 2, Top, StatusWidth, 34dip)
	Top = Top + 46dip
	Dim PlayHeight As Int = 88dip
	If Tablet Then PlayHeight = 106dip
	If PlayerHeight < 310dip Then PlayHeight = 76dip
	btnPlayPause.SetLayoutAnimated(0, InnerPadding, Top, InnerWidth, PlayHeight)
	Top = Top + PlayHeight + 10dip
	lblVolume.SetLayoutAnimated(0, InnerPadding, Top, InnerWidth, 30dip)
	Top = Top + 34dip
	Dim VolumeButtonSize As Int = 58dip
	If Tablet Then VolumeButtonSize = 66dip
	Dim SliderLeft As Int = InnerPadding + VolumeButtonSize + 8dip
	Dim SliderWidth As Int = pnlPlayer.Width - SliderLeft - InnerPadding - VolumeButtonSize - 8dip
	btnVolumeDown.SetLayoutAnimated(0, InnerPadding, Top, VolumeButtonSize, VolumeButtonSize)
	sbVolume.SetLayout(SliderLeft, Top + 8dip, SliderWidth, VolumeButtonSize - 16dip)
	btnVolumeUp.SetLayoutAnimated(0, pnlPlayer.Width - InnerPadding - VolumeButtonSize, Top, VolumeButtonSize, VolumeButtonSize)
End Sub

Private Sub LayoutSettings(Width As Int, Height As Int)
	pnlSettingsOverlay.SetLayoutAnimated(0, 0, 0, Width, Height)
	Dim CardWidth As Int = Min(560dip, Width - 24dip)
	Dim CardHeight As Int = Min(650dip, Height - 24dip)
	Dim Left As Int = (Width - CardWidth) / 2
	Dim Top As Int = (Height - CardHeight) / 2
	pnlSettingsCard.SetLayoutAnimated(0, Left, Top, CardWidth, CardHeight)

	Dim Pad As Int = 18dip
	Dim InnerWidth As Int = CardWidth - Pad * 2
	Dim Y As Int = 16dip
	lblSettingsTitle.SetLayoutAnimated(0, Pad, Y, InnerWidth, 38dip)
	Y = Y + 38dip
	lblSettingsHint.SetLayoutAnimated(0, Pad, Y, InnerWidth, 42dip)
	Y = Y + 48dip
	lbl2SMUrl.SetLayoutAnimated(0, Pad, Y, InnerWidth, 22dip)
	Y = Y + 24dip
	Dim x2SM As B4XView = txt2SMUrl
	x2SM.SetLayoutAnimated(0, Pad, Y, InnerWidth, 50dip)
	Y = Y + 58dip
	lblVisionUrl.SetLayoutAnimated(0, Pad, Y, InnerWidth, 22dip)
	Y = Y + 24dip
	Dim xVision As B4XView = txtVisionUrl
	xVision.SetLayoutAnimated(0, Pad, Y, InnerWidth, 50dip)
	Y = Y + 58dip
	Dim xAuto As B4XView = chkAutoPlay
	xAuto.SetLayoutAnimated(0, Pad, Y, InnerWidth, 46dip)
	Y = Y + 48dip
	Dim xAwake As B4XView = chkKeepAwake
	xAwake.SetLayoutAnimated(0, Pad, Y, InnerWidth, 46dip)
	Y = Y + 54dip
	btnSaveSettings.SetLayoutAnimated(0, Pad, Y, InnerWidth, 54dip)
	Y = Y + 62dip
	Dim HalfWidth As Int = (InnerWidth - 10dip) / 2
	btnTeamViewer.SetLayoutAnimated(0, Pad, Y, HalfWidth, 48dip)
	btnResetStreams.SetLayoutAnimated(0, Pad + HalfWidth + 10dip, Y, HalfWidth, 48dip)
	Y = Y + 56dip
	btnCloseSettings.SetLayoutAnimated(0, Pad, Y, InnerWidth, 46dip)

	btnSaveSettings.SetColorAndBorder(ColorVision, 0, ColorVision, 14dip)
	btnTeamViewer.SetColorAndBorder(ColorInk, 0, ColorInk, 12dip)
	btnResetStreams.SetColorAndBorder(0xFFF2F4F7, 1dip, ColorBorder, 12dip)
	btnResetStreams.TextColor = ColorInk
	btnCloseSettings.SetColorAndBorder(ColorCard, 1dip, ColorBorder, 12dip)
	btnCloseSettings.TextColor = ColorInk
End Sub

Private Sub Station_Click
	Dim SelectedButton As B4XView = Sender
	Dim NewStation As String = SelectedButton.Tag
	If NewStation = SelectedStation Then Return
	Dim WasActive As Boolean = PlaybackState = STATE_PLAYING Or PlaybackState = STATE_CONNECTING Or PlaybackState = STATE_RETRYING
	SelectedStation = NewStation
	Store.Put("selected_station", SelectedStation)
	RefreshInterface
	If WasActive Then StartSelectedStation
End Sub

Private Sub PlayPause_Click
	If PlaybackState = STATE_PLAYING Or PlaybackState = STATE_CONNECTING Or PlaybackState = STATE_RETRYING Then
		CallSubDelayed(AudioService, "PauseStream")
		PlaybackState = STATE_PAUSED
		StatusMessage = "Paused"
		RefreshInterface
	Else
		StartSelectedStation
	End If
End Sub

Private Sub StartSelectedStation
	Dim Station As Map
	Station.Initialize
	Station.Put("id", SelectedStation)
	Station.Put("name", GetStationName(SelectedStation))
	Station.Put("url", GetStationUrl(SelectedStation))
	Station.Put("volume", CurrentVolume / 100.0)
	PlaybackState = STATE_CONNECTING
	StatusMessage = "Connecting…"
	RefreshInterface
	StartService(AudioService)
	CallSubDelayed2(AudioService, "PlayStation", Station)
End Sub

Private Sub VolumeDown_Click
	SetVolumeValue(CurrentVolume - 10)
End Sub

Private Sub VolumeUp_Click
	SetVolumeValue(CurrentVolume + 10)
End Sub

Private Sub Volume_ValueChanged (Value As Int, UserChanged As Boolean)
	If UserChanged Then SetVolumeValue(Value)
End Sub

Private Sub SetVolumeValue(Value As Int)
	CurrentVolume = Max(0, Min(100, Value))
	sbVolume.Value = CurrentVolume
	lblVolume.Text = "VOLUME " & CurrentVolume & "%"
	Store.Put("volume", CurrentVolume)
	AudioService.CurrentVolume = CurrentVolume / 100.0
	If AudioService.ServiceCreated Then CallSubDelayed2(AudioService, "SetVolume", AudioService.CurrentVolume)
End Sub

Public Sub AudioStateChanged(State As Map)
	PlaybackState = State.GetDefault("state", STATE_STOPPED)
	StatusMessage = State.GetDefault("message", "Ready")
	Dim ServiceStation As String = State.GetDefault("station_id", SelectedStation)
	If ServiceStation = STATION_2SM Or ServiceStation = STATION_VISION Then
		SelectedStation = ServiceStation
		Store.Put("selected_station", SelectedStation)
	End If
	RefreshInterface
End Sub

Private Sub SyncFromAudioService
	If AudioService.CurrentStationId = STATION_2SM Or AudioService.CurrentStationId = STATION_VISION Then SelectedStation = AudioService.CurrentStationId
	If AudioService.PlaybackState.Length > 0 Then PlaybackState = AudioService.PlaybackState
	If AudioService.StatusMessage.Length > 0 Then StatusMessage = AudioService.StatusMessage
	If AudioService.CurrentVolume >= 0 Then CurrentVolume = Round(AudioService.CurrentVolume * 100)
	sbVolume.Value = CurrentVolume
	RefreshInterface
End Sub

Private Sub RefreshInterface
	If btn2SM.IsInitialized = False Then Return
	StyleStationButton(btn2SM, STATION_2SM, Color2SM)
	StyleStationButton(btnVision, STATION_VISION, ColorVision)

	Dim Accent As Int = GetStationColor(SelectedStation)
	lblNowPlaying.Text = GetStationName(SelectedStation)
	lblStatus.Text = StatusMessage
	lblVolume.Text = "VOLUME " & CurrentVolume & "%"

	Select PlaybackState
		Case STATE_PLAYING
			btnPlayPause.Text = "PAUSE"
			lblStatus.TextColor = ColorSuccess
		Case STATE_CONNECTING, STATE_RETRYING
			btnPlayPause.Text = "CANCEL"
			lblStatus.TextColor = ColorWarning
		Case STATE_ERROR
			btnPlayPause.Text = "RETRY"
			lblStatus.TextColor = ColorError
		Case Else
			btnPlayPause.Text = "PLAY"
			lblStatus.TextColor = ColorMuted
	End Select
	lblStatus.SetColorAndBorder(0xFFF2F4F7, 0, 0, 17dip)
	btnPlayPause.SetColorAndBorder(Accent, 0, Accent, 18dip)
	btnVolumeDown.SetColorAndBorder(0xFFF2F4F7, 1dip, ColorBorder, 18dip)
	btnVolumeDown.TextColor = ColorInk
	btnVolumeUp.SetColorAndBorder(0xFFF2F4F7, 1dip, ColorBorder, 18dip)
	btnVolumeUp.TextColor = ColorInk
	ApplyKeepAwake
End Sub

Private Sub StyleStationButton(Button As B4XView, StationId As String, Accent As Int)
	If SelectedStation = StationId Then
		Button.SetColorAndBorder(Accent, 0, Accent, 20dip)
		Button.TextColor = xui.Color_White
	Else
		Button.SetColorAndBorder(ColorCard, 2dip, ColorBorder, 20dip)
		Button.TextColor = ColorInk
	End If
End Sub

Private Sub GetStationName(StationId As String) As String
	If StationId = STATION_VISION Then Return "Vision Christian Radio"
	Return "2SM Super Network"
End Sub

Private Sub GetStationColor(StationId As String) As Int
	If StationId = STATION_VISION Then Return ColorVision
	Return Color2SM
End Sub

Private Sub GetStationUrl(StationId As String) As String
	If StationId = STATION_VISION Then Return UrlVision
	Return Url2SM
End Sub

Private Sub Title_LongClick
	ShowSettings
End Sub

Private Sub ShowSettings
	txt2SMUrl.Text = Url2SM
	txtVisionUrl.Text = UrlVision
	chkAutoPlay.Checked = AutoPlay
	chkKeepAwake.Checked = KeepAwake
	pnlSettingsOverlay.Visible = True
	pnlSettingsOverlay.BringToFront
End Sub

Private Sub CloseSettings_Click
	HideSettings
End Sub

Private Sub HideSettings
	pnlSettingsOverlay.Visible = False
End Sub

Private Sub SaveSettings_Click
	Dim New2SM As String = txt2SMUrl.Text.Trim
	Dim NewVision As String = txtVisionUrl.Text.Trim
	If IsValidStreamUrl(New2SM) = False Or IsValidStreamUrl(NewVision) = False Then
		xui.MsgboxAsync("Both stream addresses must begin with https://", "Check the addresses")
		Return
	End If
	Url2SM = New2SM
	UrlVision = NewVision
	AutoPlay = chkAutoPlay.Checked
	KeepAwake = chkKeepAwake.Checked
	Store.Put("url_2sm", Url2SM)
	Store.Put("url_vision", UrlVision)
	Store.Put("auto_play", AutoPlay)
	Store.Put("keep_awake", KeepAwake)
	AudioService.Url2SM = Url2SM
	AudioService.UrlVision = UrlVision
	ApplyKeepAwake
	HideSettings
	ToastMessageShow("Settings saved", False)
End Sub

Private Sub IsValidStreamUrl(Value As String) As Boolean
	Return Value.ToLowerCase.StartsWith("https://") And Value.Length > 12
End Sub

Private Sub ResetStreams_Click
	txt2SMUrl.Text = DEFAULT_2SM_URL
	txtVisionUrl.Text = DEFAULT_VISION_URL
End Sub

Private Sub TeamViewer_Click
	Dim TargetPackage As String = "com.teamviewer.host.market"
	Dim TargetActivity As String = "com.teamviewer.host.ui.HostActivity"
	Try
		Dim LaunchIntent As Intent
		LaunchIntent.Initialize(LaunchIntent.ACTION_MAIN, "")
		LaunchIntent.SetComponent(TargetPackage & "/" & TargetActivity)
		LaunchIntent.AddCategory("android.intent.category.LAUNCHER")
		StartActivity(LaunchIntent)
		Return
	Catch
	End Try

	Try
		Dim StoreIntent As Intent
		StoreIntent.Initialize(StoreIntent.ACTION_VIEW, "market://details?id=" & TargetPackage)
		StartActivity(StoreIntent)
	Catch
		Dim BrowserIntent As Intent
		BrowserIntent.Initialize(BrowserIntent.ACTION_VIEW, "https://play.google.com/store/apps/details?id=" & TargetPackage)
		StartActivity(BrowserIntent)
	End Try
End Sub

Private Sub RequestNotificationPermission
	Dim Device As Phone
	If Device.SdkVersion >= 33 Then RuntimePermission.CheckAndRequest(RuntimePermission.PERMISSION_POST_NOTIFICATIONS)
End Sub

Private Sub ApplyKeepAwake
	If KeepAwake And PlaybackState = STATE_PLAYING Then
		WakeState.KeepAlive(True)
	Else
		WakeState.ReleaseKeepAlive
	End If
End Sub

Private Sub B4XPage_Appear
	ResizeToNativeParent
	CallSubDelayed(Me, "ResizeAfterPageShown")
	SyncFromAudioService
End Sub

Private Sub B4XPage_Disappear
	WakeState.ReleaseKeepAlive
End Sub

Private Sub B4XPage_CloseRequest As ResumableSub
	If pnlSettingsOverlay.Visible Then
		HideSettings
		Return False
	End If
	Return True
End Sub