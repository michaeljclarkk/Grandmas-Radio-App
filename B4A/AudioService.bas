B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Service
Version=13.4
@EndOfDesignText@
#Region Service Attributes
    #StartAtBoot: False
    #ExcludeFromLibrary: True
#End Region

Sub Process_Globals
	Private ExoPlayer As SimpleExoPlayer
	Private Notification1 As Notification
	Private Store As KeyValueStore

	Public Const STATION_2SM As String = "2sm"
	Public Const STATION_VISION As String = "vision"
	Private Const DEFAULT_2SM_URL As String = "https://cast4.asurahosting.com/proxy/2sm1269/stream"
	Private Const DEFAULT_VISION_URL As String = "https://streams2.vision.org.au/vision128.mp3"
	Private Const ACTION_2SM As String = "radio.action.2sm"
	Private Const ACTION_TOGGLE As String = "radio.action.toggle"
	Private Const ACTION_VISION As String = "radio.action.vision"
	Private Const ACTION_STOP As String = "radio.action.stop"

	Public ServiceCreated As Boolean
	Public PlaybackState As String = "stopped"
	Public StatusMessage As String = "Ready"
	Public CurrentStationId As String = STATION_2SM
	Public CurrentStationName As String = "2SM Super Network"
	Public CurrentVolume As Double = 0.6
	Public Url2SM As String = DEFAULT_2SM_URL
	Public UrlVision As String = DEFAULT_VISION_URL

	Private CurrentStreamUrl As String
	Private RetryCount As Int
	Private RetryToken As Int
End Sub

Sub Service_Create
	ExoPlayer.Initialize("ExoPlayer")
	Store.Initialize(File.DirInternal, "radio_settings.dat")
	LoadStoredConfiguration
	ServiceCreated = True
	CurrentStreamUrl = GetStationUrl(CurrentStationId)
	BuildNotification
End Sub

Private Sub LoadStoredConfiguration
	Url2SM = Store.GetDefault("url_2sm", DEFAULT_2SM_URL)
	UrlVision = Store.GetDefault("url_vision", DEFAULT_VISION_URL)
	CurrentStationId = Store.GetDefault("selected_station", STATION_2SM)
	If CurrentStationId <> STATION_2SM And CurrentStationId <> STATION_VISION Then CurrentStationId = STATION_2SM
	CurrentStationName = GetStationName(CurrentStationId)
	Dim StoredVolume As Int = Store.GetDefault("volume", 60)
	CurrentVolume = Max(0, Min(100, StoredVolume)) / 100.0
End Sub

Sub Service_Start (StartingIntent As Intent)
	If StartingIntent.IsInitialized = False Then Return
	Select StartingIntent.Action
		Case ACTION_2SM
			PlayPreset(STATION_2SM)
		Case ACTION_TOGGLE
			If PlaybackState = "playing" Or PlaybackState = "connecting" Or PlaybackState = "retrying" Then
				PauseStream
			Else
				PlayCurrentStation
			End If
		Case ACTION_VISION
			PlayPreset(STATION_VISION)
		Case ACTION_STOP
			StopPlayback
	End Select
End Sub

Public Sub PlayStation(Station As Map)
	RetryToken = RetryToken + 1
	RetryCount = 0
	CurrentStationId = Station.GetDefault("id", STATION_2SM)
	CurrentStationName = Station.GetDefault("name", GetStationName(CurrentStationId))
	CurrentStreamUrl = Station.GetDefault("url", GetStationUrl(CurrentStationId))
	CurrentVolume = Station.GetDefault("volume", CurrentVolume)
	CurrentVolume = Max(0, Min(1, CurrentVolume))
	If CurrentStationId = STATION_2SM Then Url2SM = CurrentStreamUrl Else UrlVision = CurrentStreamUrl
	Store.Put("selected_station", CurrentStationId)
	PrepareAndPlay
End Sub

Private Sub PlayPreset(StationId As String)
	RetryToken = RetryToken + 1
	RetryCount = 0
	CurrentStationId = StationId
	CurrentStationName = GetStationName(StationId)
	CurrentStreamUrl = GetStationUrl(StationId)
	Store.Put("selected_station", CurrentStationId)
	PrepareAndPlay
End Sub

Private Sub PlayCurrentStation
	RetryToken = RetryToken + 1
	RetryCount = 0
	CurrentStreamUrl = GetStationUrl(CurrentStationId)
	PrepareAndPlay
End Sub

Private Sub PrepareAndPlay
	Try
		PlaybackState = "connecting"
		StatusMessage = "Connecting…"
		NotifyState
		BuildNotification
		ExoPlayer.Prepare(ExoPlayer.CreateUriSource(CurrentStreamUrl))
		ExoPlayer.Volume = CurrentVolume
		ExoPlayer.Play
	Catch
		HandlePlaybackError(LastException.Message)
	End Try
End Sub

Public Sub PauseStream
	RetryToken = RetryToken + 1
	Try
		ExoPlayer.Pause
	Catch
		Log("Pause failed: " & LastException.Message)
	End Try
	PlaybackState = "paused"
	StatusMessage = "Paused"
	NotifyState
	BuildNotification
End Sub

Public Sub StopPlayback
	RetryToken = RetryToken + 1
	Try
		ExoPlayer.Pause
	Catch
		Log("Stop failed: " & LastException.Message)
	End Try
	PlaybackState = "stopped"
	StatusMessage = "Stopped"
	NotifyState
	Notification1.Cancel(1)
	StopService(Me)
End Sub

Public Sub SetVolume(Volume As Double)
	CurrentVolume = Max(0, Min(1, Volume))
	ExoPlayer.Volume = CurrentVolume
	Store.Put("volume", Round(CurrentVolume * 100))
End Sub

Private Sub ExoPlayer_Ready
	RetryCount = 0
	PlaybackState = "playing"
	StatusMessage = "Playing"
	NotifyState
	BuildNotification
End Sub

Private Sub ExoPlayer_Complete
	PlaybackState = "stopped"
	StatusMessage = "Stream ended"
	NotifyState
	BuildNotification
End Sub

Private Sub ExoPlayer_Error (Error As String)
	HandlePlaybackError(Error)
End Sub

Private Sub HandlePlaybackError(Error As String)
	Log("ExoPlayer Error: " & Error)
	RetryCount = RetryCount + 1
	If RetryCount <= 3 Then
		PlaybackState = "retrying"
		StatusMessage = "Connection problem — retrying " & RetryCount & " of 3"
		NotifyState
		BuildNotification
		Dim ThisToken As Int = RetryToken
		Sleep(RetryCount * 2000)
		If ThisToken <> RetryToken Or PlaybackState <> "retrying" Then Return
		PrepareAndPlay
	Else
		PlaybackState = "error"
		StatusMessage = "Could not connect — tap Retry"
		NotifyState
		BuildNotification
	End If
End Sub

Private Sub NotifyState
	Dim State As Map
	State.Initialize
	State.Put("state", PlaybackState)
	State.Put("message", StatusMessage)
	State.Put("station_id", CurrentStationId)
	State.Put("station_name", CurrentStationName)
	Try
		CallSubDelayed2(B4XPages.MainPage, "AudioStateChanged", State)
	Catch
		Log("Main page is not currently available.")
	End Try
End Sub

Private Sub BuildNotification
	Dim Builder As NB6
	Builder.Initialize("grandmas_radio", "Radio playback", "LOW")
	Builder.SmallIcon(LoadBitmapResize(File.DirAssets, "2sm.png", 24dip, 24dip, True))
	Builder.Color(GetStationColor(CurrentStationId))
	Builder.OnlyAlertOnce(True)
	Builder.OnGoing(True)
	Builder.Visibility("PUBLIC")
	Builder.SetCategory("CATEGORY_TRANSPORT")

	Dim EmptyIcon As Bitmap
	Builder.AddButtonAction(EmptyIcon, "2SM", Me, ACTION_2SM)
	If PlaybackState = "playing" Or PlaybackState = "connecting" Or PlaybackState = "retrying" Then
		Builder.AddButtonAction(EmptyIcon, "Pause", Me, ACTION_TOGGLE)
	Else
		Builder.AddButtonAction(EmptyIcon, "Play", Me, ACTION_TOGGLE)
	End If
	Builder.AddButtonAction(EmptyIcon, "Vision", Me, ACTION_VISION)
	Builder.AddButtonAction(EmptyIcon, "Stop", Me, ACTION_STOP)
	Builder.MediaStyle

	Dim NotificationText As String = StatusMessage & " • " & CurrentStationName
	Notification1 = Builder.Build("Grandma's Radio", NotificationText, "radio", Main)
	Service.StartForeground(1, Notification1)
End Sub

Private Sub GetStationName(StationId As String) As String
	If StationId = STATION_VISION Then Return "Vision Christian Radio"
	Return "2SM Super Network"
End Sub

Private Sub GetStationUrl(StationId As String) As String
	If StationId = STATION_VISION Then Return UrlVision
	Return Url2SM
End Sub

Private Sub GetStationColor(StationId As String) As Int
	If StationId = STATION_VISION Then Return 0xFF6246EA
	Return 0xFFD62839
End Sub

Sub Service_Destroy
	RetryToken = RetryToken + 1
	Try
		ExoPlayer.Pause
		ExoPlayer.Release
	Catch
		Log("Player release failed: " & LastException.Message)
	End Try
	Notification1.Cancel(1)
	ServiceCreated = False
	PlaybackState = "stopped"
	StatusMessage = "Stopped"
End Sub
