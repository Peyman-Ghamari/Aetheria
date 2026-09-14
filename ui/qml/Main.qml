import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Shapes
import QtQuick.Effects
import MusicPlayer.Core 1.0
import Qt.labs.platform as Platform
import "components"

ApplicationWindow {
    id: root
    width: 1240
    height: 800
    minimumWidth: 1020
    minimumHeight: 680
    visible: true
    title: "Aetheria Music Suite"
    color: "#07050d"

    flags: Qt.Window | Qt.FramelessWindowHint

    onClosing: (close) => {
        Qt.quit()
    }


    NumberAnimation {
        id: snapBackAnim
        target: root
        property: "y"
        duration: 250
        easing.type: Easing.OutCubic
    }

    function smoothSnapAboveTaskbar() {
        if (root.visibility === Window.Maximized || root.visibility === Window.Minimized) return

        var screenObj = root.screen ? root.screen : Screen
        var availHeight = screenObj.desktopAvailableHeight
        var virtY = screenObj.virtualY ? screenObj.virtualY : 0

        var safeMargin = 50
        var maxAllowedY = virtY + availHeight - safeMargin

        if (root.y > maxAllowedY) {
            snapBackAnim.stop()
            snapBackAnim.from = root.y
            snapBackAnim.to = maxAllowedY
            snapBackAnim.start()
        }
    }


    property string activeCenterTab: "stage"
    property string activeTitle: "No Active Stream"
    property string activeArtist: "Idle"
    property string activeCover: ""
    property string activeFilePath: ""
    property bool isCurrentTrackLiked: false

    readonly property bool hasActiveTrack: root.activeFilePath !== "" && root.activeTitle !== "No Active Stream"



    Shortcut {
        sequence: "Meta+Up"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (root.visibility === Window.Maximized) return
            root.showMaximized()
        }
    }

    Shortcut {
        sequence: "Meta+Down"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (root.visibility === Window.Maximized) {
                root.showNormal()
            } else {
                root.showMinimized()
            }
        }
    }

    Shortcut {
        sequence: "Meta+Left"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (root.visibility === Window.Maximized) root.showNormal()

            var scr = root.screen ? root.screen : Screen
            var vX = scr.virtualX ? scr.virtualX : 0
            var vY = scr.virtualY ? scr.virtualY : 0

            root.x = vX
            root.y = vY
            root.width = scr.desktopAvailableWidth / 2
            root.height = scr.desktopAvailableHeight
        }
    }

    Shortcut {
        sequence: "Meta+Right"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (root.visibility === Window.Maximized) root.showNormal()

            var scr = root.screen ? root.screen : Screen
            var vX = scr.virtualX ? scr.virtualX : 0
            var vY = scr.virtualY ? scr.virtualY : 0

            root.x = vX + (scr.desktopAvailableWidth / 2)
            root.y = vY
            root.width = scr.desktopAvailableWidth / 2
            root.height = scr.desktopAvailableHeight
        }
    }


    Shortcut {
        sequence: "Space"
        context: Qt.ApplicationShortcut
        onActivated: {
            var focusObj = root.activeFocusItem
            if (focusObj && (focusObj.toString().indexOf("TextField") !== -1 || focusObj.toString().indexOf("TextInput") !== -1)) return
            if (root.hasActiveTrack) {
                AudioEngine.togglePlayPause()
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+Right"
        context: Qt.ApplicationShortcut
        onActivated: TrackModel.playNextTrack(AudioEngine.isShuffle)
    }

    Shortcut {
        sequence: "Ctrl+Left"
        context: Qt.ApplicationShortcut
        onActivated: TrackModel.playPrevious()
    }

    Shortcut {
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: {
            var focusObj = root.activeFocusItem
            if (focusObj && (focusObj.toString().indexOf("TextField") !== -1 || focusObj.toString().indexOf("TextInput") !== -1)) return
            if (root.hasActiveTrack) {
                AudioEngine.setPosition(Math.min(AudioEngine.duration, AudioEngine.position + 5000))
            }
        }
    }

    Shortcut {
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: {
            var focusObj = root.activeFocusItem
            if (focusObj && (focusObj.toString().indexOf("TextField") !== -1 || focusObj.toString().indexOf("TextInput") !== -1)) return
            if (root.hasActiveTrack) {
                AudioEngine.setPosition(Math.max(0, AudioEngine.position - 5000))
            }
        }
    }

    Shortcut {
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: {
            var focusObj = root.activeFocusItem
            if (focusObj && (focusObj.toString().indexOf("TextField") !== -1 || focusObj.toString().indexOf("TextInput") !== -1)) return
            AudioEngine.setVolume(Math.min(1.0, AudioEngine.volume + 0.05))
        }
    }

    Shortcut {
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: {
            var focusObj = root.activeFocusItem
            if (focusObj && (focusObj.toString().indexOf("TextField") !== -1 || focusObj.toString().indexOf("TextInput") !== -1)) return
            AudioEngine.setVolume(Math.max(0.0, AudioEngine.volume - 0.05))
        }
    }

    Shortcut {
        sequence: "M"
        context: Qt.ApplicationShortcut
        onActivated: {
            var focusObj = root.activeFocusItem
            if (focusObj && (focusObj.toString().indexOf("TextField") !== -1 || focusObj.toString().indexOf("TextInput") !== -1)) return
            if (AudioEngine.volume > 0) {
                AudioEngine.setVolume(0.0)
            } else {
                AudioEngine.setVolume(0.85)
            }
        }
    }

    Shortcut {
        sequence: "L"
        context: Qt.ApplicationShortcut
        onActivated: {
            var focusObj = root.activeFocusItem
            if (focusObj && (focusObj.toString().indexOf("TextField") !== -1 || focusObj.toString().indexOf("TextInput") !== -1)) return
            if (root.activeFilePath !== "") {
                TrackModel.toggleLikeByPath(root.activeFilePath)
            }
        }
    }

    FolderDialog {
        id: folderDialog
        title: "Select Local Music Library"
        currentFolder: TrackModel.lastSelectedFolder

        onAccepted: {
            var path = folderDialog.selectedFolder
            TrackModel.lastSelectedFolder = path
            TrackModel.scanDirectory(path)
        }
    }

    function formatTime(ms) {
        if (!ms || isNaN(ms)) return "00:00"
        var totalSec = Math.floor(ms / 1000)
        var min = Math.floor(totalSec / 60)
        var sec = totalSec % 60
        return (min < 10 ? "0" : "") + min + ":" + (sec < 10 ? "0" : "") + sec
    }

    function cleanTrackDisplay(str) {
        if (!str || str === "") return "No Active Stream"
        try {
            var decoded = decodeURIComponent(str.split("/").pop())
            return decoded.replace(/\.(mp3|flac|wav|m4a|aac|ogg|wma)$/i, "")
        } catch(e) {
            return str
        }
    }

    Connections {
        target: AudioEngine
        function onPositionChanged(pos) {
            if (LyricsService.hasSyncedLyrics) {
                LyricsService.updatePosition(pos)
            }
            if (AudioEngine.duration > 1000 && pos >= (AudioEngine.duration - 350) && AudioEngine.isPlaying) {
                if (AudioEngine.repeatMode === 2) {
                    AudioEngine.setPosition(0)
                    AudioEngine.play()
                } else if (AudioEngine.repeatMode === 1) {
                    TrackModel.playNextTrack(AudioEngine.isShuffle)
                } else if (AudioEngine.repeatMode === 0) {
                    if (TrackModel.currentIndex < TrackModel.count - 1) {
                        TrackModel.playNextTrack(AudioEngine.isShuffle)
                    } else {
                        AudioEngine.stop()
                    }
                }
            }
        }
    }

    Connections {
        target: TrackModel
        function onTrackSelected(title, artist, filePath, coverPath) {
            var trackData = TrackModel.getTrackAt(TrackModel.currentIndex)
            var actualTitle = (trackData.title && trackData.title !== "") ? trackData.title : title
            var actualArtist = (trackData.artist && trackData.artist !== "") ? trackData.artist : artist
            var actualPath = (trackData.filePath && trackData.filePath !== "") ? trackData.filePath : filePath
            var actualCover = (trackData.coverPath && trackData.coverPath !== "") ? trackData.coverPath : coverPath

            root.activeTitle = actualTitle ? actualTitle : "Unknown Title"
            root.activeArtist = actualArtist ? actualArtist : "Local Artist"
            root.activeCover = actualCover ? actualCover : ""
            root.activeFilePath = actualPath ? actualPath : ""
            root.isCurrentTrackLiked = TrackModel.isTrackLiked(root.activeFilePath)

            AudioEngine.loadSource(root.activeFilePath)
            AudioEngine.play()
            LyricsService.fetchLyrics(root.activeTitle, root.activeArtist, root.activeFilePath)
        }

        function onCoverUpdated(filePath, newCoverPath) {
            if (root.activeFilePath === filePath) {
                root.activeCover = newCoverPath
            }
        }

        function onLikeStatusChanged(filePath, isLiked) {
            if (root.activeFilePath === filePath) {
                root.isCurrentTrackLiked = isLiked
            }
        }
    }

    Connections {
        target: OnlineSearchEngine
        function onFullTrackResolved(streamUrl, title, artist, coverUrl, isDownload) {
            if (isDownload) {
                var safeFileName = (artist ? artist : "Artist") + " - " + (title ? title : "Track") + ".mp3"
                DownloadManager.startDownload(streamUrl, safeFileName)
            } else {
                root.activeTitle = (title && title !== "") ? title : "Online Track"
                root.activeArtist = (artist && artist !== "") ? artist : "Online Artist"
                root.activeCover = (coverUrl && coverUrl !== "") ? coverUrl : ""
                root.activeFilePath = streamUrl
                root.isCurrentTrackLiked = TrackModel.isTrackLiked(streamUrl)

                if (typeof AudioEngine.loadSource === "function") {
                    AudioEngine.loadSource(streamUrl)
                    AudioEngine.play()
                } else if (typeof AudioEngine.playUrl === "function") {
                    AudioEngine.playUrl(streamUrl)
                } else if (typeof AudioEngine.playFile === "function") {
                    AudioEngine.playFile(streamUrl)
                } else if (typeof AudioEngine.playSource === "function") {
                    AudioEngine.playSource(streamUrl)
                } else if (typeof AudioEngine.openFile === "function") {
                    AudioEngine.openFile(streamUrl)
                } else {
                    AudioEngine.source = streamUrl
                    AudioEngine.play()
                }

                LyricsService.fetchLyrics(root.activeTitle, root.activeArtist, streamUrl)
            }
        }
    }

    Dialog {
        id: editTrackDialog
        property string targetFilePath: ""
        property int targetIndex: -1

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 380
        height: 360
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 18
            color: "#160f26"
            border.color: "#8b5cf6"
            border.width: 1.5
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Edit Track Metadata"
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    text: "✕"
                    color: "#71717a"
                    font.pixelSize: 14
                    font.bold: true
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editTrackDialog.close()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text { text: "Title"; color: "#a78bfa"; font.pixelSize: 11; font.bold: true }
                TextField {
                    id: editTitleField
                    Layout.fillWidth: true
                    placeholderText: "Enter track title..."
                    placeholderTextColor: "#71717a"
                    color: "#ffffff"
                    font.pixelSize: 12
                    background: Rectangle {
                        implicitHeight: 34
                        radius: 8
                        color: "#0e081a"
                        border.color: editTitleField.activeFocus ? "#ec4899" : "#2a1b47"
                        border.width: 1
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text { text: "Artist"; color: "#a78bfa"; font.pixelSize: 11; font.bold: true }
                TextField {
                    id: editArtistField
                    Layout.fillWidth: true
                    placeholderText: "Enter artist name..."
                    placeholderTextColor: "#71717a"
                    color: "#ffffff"
                    font.pixelSize: 12
                    background: Rectangle {
                        implicitHeight: 34
                        radius: 8
                        color: "#0e081a"
                        border.color: editArtistField.activeFocus ? "#ec4899" : "#2a1b47"
                        border.width: 1
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text { text: "Album"; color: "#a78bfa"; font.pixelSize: 11; font.bold: true }
                TextField {
                    id: editAlbumField
                    Layout.fillWidth: true
                    placeholderText: "Enter album title..."
                    placeholderTextColor: "#71717a"
                    color: "#ffffff"
                    font.pixelSize: 12
                    background: Rectangle {
                        implicitHeight: 34
                        radius: 8
                        color: "#0e081a"
                        border.color: editAlbumField.activeFocus ? "#ec4899" : "#2a1b47"
                        border.width: 1
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 10

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    text: "Cancel"
                    onClicked: editTrackDialog.close()
                    background: Rectangle { radius: 8; color: "#21153b" }
                    contentItem: Text { text: "Cancel"; color: "#a78bfa"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    text: "Save"
                    onClicked: {
                        if (editTrackDialog.targetFilePath !== "") {
                            TrackModel.updateTrackMetadata(
                                editTrackDialog.targetFilePath,
                                editTitleField.text,
                                editArtistField.text,
                                editAlbumField.text
                            )

                            if (root.activeFilePath === editTrackDialog.targetFilePath) {
                                root.activeTitle = editTitleField.text.trim()
                                root.activeArtist = editArtistField.text.trim()
                            }
                            editTrackDialog.close()
                        }
                    }
                    background: Rectangle {
                        radius: 8
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#7c3aed" }
                            GradientStop { position: 1.0; color: "#ec4899" }
                        }
                    }
                    contentItem: Text { text: "Save"; color: "white"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
        }
    }

    Dialog {
        id: createPlaylistStandaloneDialog
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 320
        height: 190
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 16
            color: "#160f26"
            border.color: "#8b5cf6"
            border.width: 1.5
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            Text {
                text: "Create New Playlist"
                color: "#ffffff"
                font.bold: true
                font.pixelSize: 14
                Layout.alignment: Qt.AlignHCenter
            }

            TextField {
                id: standalonePlaylistInput
                Layout.fillWidth: true
                placeholderText: "Enter playlist title..."
                placeholderTextColor: "#71717a"
                color: "#ffffff"
                font.pixelSize: 12
                background: Rectangle {
                    implicitHeight: 36
                    radius: 8
                    color: "#0e081a"
                    border.color: standalonePlaylistInput.activeFocus ? "#ec4899" : "#2a1b47"
                    border.width: 1
                }
                onAccepted: confirmCreatePlBtn.clicked()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    text: "Cancel"
                    onClicked: createPlaylistStandaloneDialog.close()
                    background: Rectangle { radius: 8; color: "#21153b" }
                    contentItem: Text { text: "Cancel"; color: "#a78bfa"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }

                Button {
                    id: confirmCreatePlBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    text: "Create"
                    onClicked: {
                        var name = standalonePlaylistInput.text.trim()
                        if (name.length > 0) {
                            TrackModel.createNewPlaylist(name)
                            TrackModel.currentPlaylist = name
                            standalonePlaylistInput.text = ""
                            createPlaylistStandaloneDialog.close()
                        }
                    }
                    background: Rectangle {
                        radius: 8
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#7c3aed" }
                            GradientStop { position: 1.0; color: "#ec4899" }
                        }
                    }
                    contentItem: Text { text: "Create"; color: "white"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
        }
    }



    Dialog {
        id: developerDialog
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 500
        height: 520
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string activeTab: "about"

        background: Rectangle {
            radius: 20
            color: "#120b22"
            border.color: "#8b5cf6"
            border.width: 1.5

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.96
                height: parent.height * 0.96
                radius: 18
                color: "#180f2d"
                opacity: 0.7
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: developerDialog.activeTab === "about" ? "About Developer" : "Keyboard Shortcuts & Tips"
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    text: "✕"
                    color: "#71717a"
                    font.pixelSize: 13
                    font.bold: true

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: developerDialog.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 10
                color: "#0d0718"
                border.color: "#281845"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: developerDialog.activeTab === "about" ? "#2a154a" : "transparent"
                        border.color: developerDialog.activeTab === "about" ? "#8b5cf6" : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "About Suite"
                            color: developerDialog.activeTab === "about" ? "#ffffff" : "#71717a"
                            font.pixelSize: 11
                            font.bold: developerDialog.activeTab === "about"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: developerDialog.activeTab = "about"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: developerDialog.activeTab === "tips" ? "#2a154a" : "transparent"
                        border.color: developerDialog.activeTab === "tips" ? "#ec4899" : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Shortcuts & Tips"
                            color: developerDialog.activeTab === "tips" ? "#ffffff" : "#71717a"
                            font.pixelSize: 11
                            font.bold: developerDialog.activeTab === "tips"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: developerDialog.activeTab = "tips"
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                visible: developerDialog.activeTab === "about"

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 60
                    height: 60
                    radius: 16
                    color: "#1f123b"
                    border.color: "#ec4899"
                    border.width: 1.5

                    Image {
                        anchors.fill: parent
                        anchors.margins: 6
                        source: "qrc:/qt/qml/MusicPlayerApp/assets/logo1.png"
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 128
                        sourceSize.height: 128
                        smooth: true
                        mipmap: true
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 3

                    Text {
                        text: "Aetheria Music Suite"
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.bold: true
                        font.letterSpacing: 1.2
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Engineered by Peyman Ghamari (PM)"
                        color: "#ec4899"
                        font.pixelSize: 12
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Version 1.0.0 • High-Fidelity Audio Architecture"
                        color: "#a78bfa"
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 74
                    radius: 10
                    color: "#0c0617"
                    border.color: "#281745"
                    border.width: 1

                    Text {
                        anchors.fill: parent
                        anchors.margins: 10
                        text: "Engineered with Modern C++20 and Qt 6 Quick/QML for High-Performance Audio Playback. Featuring Intelligent Multi-Source Lyrics Synchronization, Seamless Online Streaming, and an Elegant Low-Latency Dark Interface."
                        color: "#cbd5e1"
                        font.pixelSize: 11
                        lineHeight: 1.4
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    text: "Connect & Follow:"
                    color: "#f472b6"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: githubBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        onClicked: Qt.openUrlExternally("https://github.com/Peyman-Ghamari")

                        background: Rectangle {
                            radius: 8
                            color: githubBtn.hovered ? "#2e1065" : "#1b0f33"
                            border.color: githubBtn.hovered ? "#ec4899" : "#381c60"
                            border.width: 1
                        }

                        contentItem: RowLayout {
                            spacing: 8
                            Item { Layout.fillWidth: true }
                            Text { text: "🧑‍💻"; font.pixelSize: 13 }
                            Text { text: "GitHub Profile"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                            Item { Layout.fillWidth: true }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }

                    Button {
                        id: telegramBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        onClicked: Qt.openUrlExternally("https://t.me/P_Ghamari")

                        background: Rectangle {
                            radius: 8
                            color: telegramBtn.hovered ? "#0284c7" : "#0c4a6e"
                            border.color: telegramBtn.hovered ? "#38bdf8" : "#0369a1"
                            border.width: 1
                        }

                        contentItem: RowLayout {
                            spacing: 8
                            Item { Layout.fillWidth: true }
                            Text { text: "✈️"; font.pixelSize: 13 }
                            Text { text: "Telegram Contact"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                            Item { Layout.fillWidth: true }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: developerDialog.activeTab === "tips"
                clip: true

                ListView {
                    anchors.fill: parent
                    spacing: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    model: [
                        { key: "Ctrl + Shift + M", desc: "Toggle Floating Mini-Player (Global Hotkey)", isGlobal: true },
                        { key: "Media Play / Pause", desc: "Global Media Play/Pause (Fn + Media Keys)", isGlobal: true },
                        { key: "Media Next / Prev", desc: "Global Next/Previous Track (Fn + Media Keys)", isGlobal: true },
                        { key: "Space", desc: "Play / Pause playback", isGlobal: false },
                        { key: "Ctrl + Right / Left", desc: "Skip to Next / Previous track", isGlobal: false },
                        { key: "Right / Left", desc: "Seek Forward / Backward (5s)", isGlobal: false },
                        { key: "Up / Down", desc: "Increase / Decrease Volume (5%)", isGlobal: false },
                        { key: "M", desc: "Toggle Instant Mute", isGlobal: false },
                        { key: "L", desc: "Like / Unlike current track", isGlobal: false },
                        { key: "Right Click on Track", desc: "Edit Info, Add to Playlist or Delete", isGlobal: false }
                    ]

                    delegate: Rectangle {
                        id: tipItem
                        required property var modelData
                        width: ListView.view.width
                        height: 38
                        radius: 8
                        color: "#0e081c"
                        border.color: tipItem.modelData.isGlobal ? "#ec4899" : "#241640"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Rectangle {
                                Layout.preferredHeight: 22
                                implicitWidth: keyText.implicitWidth + 12
                                radius: 5
                                color: tipItem.modelData.isGlobal ? "#3b0718" : "#1f1438"
                                border.color: tipItem.modelData.isGlobal ? "#ec4899" : "#6d28d9"
                                border.width: 1

                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: tipItem.modelData.key
                                    color: "#ffffff"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }

                            Text {
                                text: tipItem.modelData.desc
                                color: "#cbd5e1"
                                font.pixelSize: 11
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                visible: tipItem.modelData.isGlobal
                                Layout.preferredHeight: 18
                                Layout.preferredWidth: 54
                                radius: 4
                                color: "#ec4899"

                                Text {
                                    anchors.centerIn: parent
                                    text: "GLOBAL"
                                    color: "#ffffff"
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: playlistChooserDialog
        property string targetFilePath: ""
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 330
        height: 390
        modal: true
        background: Rectangle {
            radius: 16
            color: "#160f26"
            border.color: "#8b5cf6"
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: "Add to Playlist"
                color: "#ffffff"
                font.bold: true
                font.pixelSize: 14
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextField {
                    id: newPlaylistInput
                    Layout.fillWidth: true
                    placeholderText: "New playlist name..."
                    placeholderTextColor: "#71717a"
                    color: "#ffffff"
                    font.pixelSize: 12
                    background: Rectangle {
                        radius: 8
                        color: "#0e081a"
                        border.color: newPlaylistInput.activeFocus ? "#ec4899" : "#2a1b47"
                        border.width: 1
                    }
                    onAccepted: createPlBtn.clicked()
                }

                Button {
                    id: createPlBtn
                    implicitWidth: 36
                    implicitHeight: 36
                    onClicked: {
                        var name = newPlaylistInput.text.trim()
                        if (name.length > 0) {
                            TrackModel.createNewPlaylist(name)
                            if (playlistChooserDialog.targetFilePath !== "") {
                                TrackModel.addToPlaylist(name, playlistChooserDialog.targetFilePath)
                            }
                            newPlaylistInput.text = ""
                            playlistChooserDialog.close()
                        }
                    }
                    background: Rectangle {
                        radius: 8
                        color: "#ec4899"
                    }
                    contentItem: Text {
                        text: "+"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: TrackModel.playlistNames
                spacing: 6

                delegate: Rectangle {
                    id: plItemRect
                    required property string modelData
                    width: ListView.view.width
                    height: 38
                    radius: 8
                    color: plItemMa.containsMouse ? "#2e1065" : "#1e1333"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        Text {
                            text: "📁 " + plItemRect.modelData
                            color: "#f5d0fe"
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: plItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (playlistChooserDialog.targetFilePath !== "") {
                                TrackModel.addToPlaylist(plItemRect.modelData, playlistChooserDialog.targetFilePath)
                            }
                            playlistChooserDialog.close()
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: multiSelectDialog
        property var rawMasterTracks: []
        property var selectedPaths: []
        property string searchFilter: ""

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 480
        height: 560
        modal: true

        onOpened: {
            multiSelectDialog.rawMasterTracks = TrackModel.getAllTracks()
            multiSelectDialog.selectedPaths = []
            msSearchInput.text = ""
            multiSelectDialog.searchFilter = ""
        }

        background: Rectangle {
            radius: 18
            color: "#140e24"
            border.color: "#8b5cf6"
            border.width: 1.5
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Add to " + TrackModel.currentPlaylist
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: 15
                    Layout.fillWidth: true
                }
                Text {
                    text: multiSelectDialog.selectedPaths.length + " selected"
                    color: "#ec4899"
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 8
                color: "#0e081a"
                border.color: msSearchInput.activeFocus ? "#ec4899" : "#2a1b47"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Shape {
                        width: 14
                        height: 14
                        smooth: true
                        antialiasing: true

                        ShapePath {
                            strokeWidth: 1.6
                            strokeColor: msSearchInput.activeFocus ? "#ec4899" : "#a78bfa"
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 10; startY: 5.5
                            PathArc { x: 1; y: 5.5; radiusX: 4.5; radiusY: 4.5; useLargeArc: false }
                            PathArc { x: 10; y: 5.5; radiusX: 4.5; radiusY: 4.5; useLargeArc: false }
                        }
                        ShapePath {
                            strokeWidth: 2
                            strokeColor: msSearchInput.activeFocus ? "#ec4899" : "#a78bfa"
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 8.8; startY: 8.8
                            PathLine { x: 13; y: 13 }
                        }
                    }

                    TextField {
                        id: msSearchInput
                        Layout.fillWidth: true
                        placeholderText: "Search in library..."
                        placeholderTextColor: "#71717a"
                        color: "#ffffff"
                        font.pixelSize: 11
                        background: Item {}
                        onTextChanged: multiSelectDialog.searchFilter = text.trim().toLowerCase()
                    }

                    Text {
                        text: "✕"
                        color: "#71717a"
                        font.pixelSize: 11
                        visible: msSearchInput.text.length > 0
                        MouseArea {
                            anchors.fill: parent
                            onClicked: msSearchInput.text = ""
                        }
                    }
                }
            }

            ListView {
                id: multiSelectView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6

                model: {
                    var all = multiSelectDialog.rawMasterTracks
                    if (!all) return []
                    if (!multiSelectDialog.searchFilter || multiSelectDialog.searchFilter === "") {
                        return all
                    }
                    var q = multiSelectDialog.searchFilter
                    return all.filter(function(item) {
                        return (item.title && item.title.toLowerCase().indexOf(q) !== -1) ||
                            (item.artist && item.artist.toLowerCase().indexOf(q) !== -1)
                    })
                }

                delegate: Rectangle {
                    id: msItem
                    required property var modelData
                    width: multiSelectView.width
                    height: 48
                    radius: 10

                    readonly property bool isChecked: multiSelectDialog.selectedPaths.indexOf(modelData.filePath) !== -1
                    color: isChecked ? "#2c133f" : (msItemMa.containsMouse ? "#211438" : "#170f28")
                    border.color: isChecked ? "#ec4899" : (msItemMa.containsMouse ? "#8b5cf6" : "#241640")
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 6
                            color: msItem.isChecked ? "#ec4899" : "#0e081a"
                            border.color: msItem.isChecked ? "#ec4899" : "#64748b"
                            border.width: 1.5

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.bold: true
                                visible: msItem.isChecked
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: msItem.modelData.title ? msItem.modelData.title : ""
                                color: msItem.isChecked ? "#ffffff" : "#f1f5f9"
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: (msItem.modelData.artist ? msItem.modelData.artist : "Local Artist") + " • " + (msItem.modelData.duration ? msItem.modelData.duration : "--:--")
                                color: "#a78bfa"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: msItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var arr = multiSelectDialog.selectedPaths.slice()
                            var idx = arr.indexOf(msItem.modelData.filePath)
                            if (idx === -1) {
                                arr.push(msItem.modelData.filePath)
                            } else {
                                arr.splice(idx, 1)
                            }
                            multiSelectDialog.selectedPaths = arr
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Button {
                    Layout.fillWidth: true
                    text: "Cancel"
                    onClicked: multiSelectDialog.close()
                    background: Rectangle { implicitHeight: 36; radius: 8; color: "#21153b" }
                    contentItem: Text { text: "Cancel"; color: "#a78bfa"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button {
                    Layout.fillWidth: true
                    text: "Add Selected (" + multiSelectDialog.selectedPaths.length + ")"
                    enabled: multiSelectDialog.selectedPaths.length > 0
                    opacity: enabled ? 1.0 : 0.5
                    onClicked: {
                        TrackModel.addMultipleToPlaylist(TrackModel.currentPlaylist, multiSelectDialog.selectedPaths)
                        multiSelectDialog.selectedPaths = []
                        multiSelectDialog.close()
                    }
                    background: Rectangle {
                        implicitHeight: 36
                        radius: 8
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#7c3aed" }
                            GradientStop { position: 1.0; color: "#ec4899" }
                        }
                    }
                    contentItem: Text { text: parent.text; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
        }
    }

    Dialog {
        id: customSleepDialog
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        modal: true
        title: ""
        width: 320
        height: 200

        background: Rectangle {
            radius: 16
            color: "#160f26"
            border.color: "#ec4899"
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Text {
                text: "Set Custom Sleep Timer"
                color: "#ffffff"
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            TextField {
                id: customMinutesInput
                Layout.fillWidth: true
                placeholderText: "Enter minutes (e.g. 25)"
                placeholderTextColor: "#71717a"
                color: "#ffffff"
                font.pixelSize: 13
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 1; top: 720 }

                background: Rectangle {
                    implicitHeight: 38
                    radius: 8
                    color: "#0e081a"
                    border.color: customMinutesInput.activeFocus ? "#ec4899" : "#2a1b47"
                    border.width: 1
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Button {
                    Layout.fillWidth: true
                    text: "Cancel"
                    onClicked: customSleepDialog.close()
                    background: Rectangle { implicitHeight: 34; radius: 8; color: "#21153b" }
                    contentItem: Text { text: "Cancel"; color: "#a78bfa"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }

                Button {
                    Layout.fillWidth: true
                    text: "Set Timer"
                    onClicked: {
                        var mins = parseInt(customMinutesInput.text)
                        if (mins > 0) {
                            SleepTimer.startTimer(mins)
                            customMinutesInput.text = ""
                            customSleepDialog.close()
                        }
                    }
                    background: Rectangle {
                        implicitHeight: 34
                        radius: 8
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#7c3aed" }
                            GradientStop { position: 1.0; color: "#ec4899" }
                        }
                    }
                    contentItem: Text { text: "Set Timer"; color: "white"; font.pixelSize: 12; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
        }
    }

    Dialog {
        id: exitConfirmDialog
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 340
        height: 180
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 18
            color: "#150d27"
            border.color: "#8b5cf6"
            border.width: 1.5

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.95
                height: parent.height * 0.95
                radius: 16
                color: "#1c1033"
                opacity: 0.5
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            RowLayout {
                spacing: 10
                Layout.alignment: Qt.AlignHCenter

                Text { text: "⚠️"; font.pixelSize: 18 }

                Text {
                    text: "Exit Aetheria ?"
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                }
            }

            Text {
                text: "Are You Sure You Want To Exit Aetheria ?"
                color: "#cbd5e1"
                font.pixelSize: 11
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Button {
                    id: cancelExitBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    text: "Cancel"
                    onClicked: exitConfirmDialog.close()

                    scale: cancelExitBtn.hovered ? (cancelExitBtn.pressed ? 0.96 : 1.03) : 1.0
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    background: Rectangle {
                        radius: 10
                        color: cancelExitBtn.hovered ? "#351c5e" : "#201238"
                        border.color: cancelExitBtn.hovered ? "#a855f7" : "#3b2366"
                        border.width: cancelExitBtn.hovered ? 1.5 : 1

                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }
                    }

                    contentItem: Text {
                        text: "Cancel"
                        color: cancelExitBtn.hovered ? "#ffffff" : "#c4b5fd"
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }

                Button {
                    id: confirmExitBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    text: "Exit"
                    onClicked: Qt.quit()

                    scale: confirmExitBtn.hovered ? (confirmExitBtn.pressed ? 0.96 : 1.03) : 1.0
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    background: Rectangle {
                        radius: 10
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: confirmExitBtn.hovered
                                    ? (confirmExitBtn.pressed ? "#be123c" : "#f43f5e")
                                    : "#e11d48"
                            }
                            GradientStop {
                                position: 1.0
                                color: confirmExitBtn.hovered
                                    ? (confirmExitBtn.pressed ? "#9f1239" : "#e11d48")
                                    : "#be123c"
                            }
                        }
                        border.color: confirmExitBtn.hovered ? "#fda4af" : "transparent"
                        border.width: confirmExitBtn.hovered ? 1 : 0

                        Behavior on border.color { ColorAnimation { duration: 140 } }
                    }

                    contentItem: Text {
                        text: "Exit"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }
    
    Rectangle {
        id: customTitleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36
        color: "#0a0614"
        z: 999

        MouseArea {
            anchors.left: parent.left
            anchors.right: windowControlsRow.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            acceptedButtons: Qt.LeftButton

            property point pressPos: Qt.point(0, 0)
            property bool moveStarted: false

            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    pressPos = Qt.point(mouse.x, mouse.y)
                    moveStarted = false
                }
            }

            onPositionChanged: (mouse) => {
                if (pressed && !moveStarted) {
                    var dx = mouse.x - pressPos.x
                    var dy = mouse.y - pressPos.y
                    if ((dx * dx + dy * dy) > 16) {
                        moveStarted = true
                        root.startSystemMove()
                    }
                }
            }

            onReleased: {
                moveStarted = false
                root.smoothSnapAboveTaskbar()
            }

            onDoubleClicked: {
                if (root.visibility === Window.Maximized) {
                    root.showNormal()
                } else {
                    root.showMaximized()
                }
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14
            spacing: 6

            Image {
                source: "qrc:/qt/qml/MusicPlayerApp/assets/logo1.png"
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                fillMode: Image.PreserveAspectFit
            }
            Text {
                text: "Aetheria"
                color: "#a78bfa"
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1
            }
        }

        RowLayout {
            id: windowControlsRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 8
            spacing: 2

            Rectangle {
                width: 32
                height: 26
                radius: 4
                color: pipBtnMa.containsMouse ? "#211438" : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "🗗"
                    color: pipBtnMa.containsMouse ? "#ec4899" : "#94a3b8"
                    font.pixelSize: 12
                }
                MouseArea {
                    id: pipBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        floatingMiniPlayer.openMiniPlayer()
                        root.hide()
                    }
                }
            }

            Rectangle {
                width: 32
                height: 26
                radius: 4
                color: minBtnMa.containsMouse ? "#211438" : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "—"
                    color: minBtnMa.containsMouse ? "#ffffff" : "#94a3b8"
                    font.pixelSize: 10
                }
                MouseArea {
                    id: minBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showMinimized()
                }
            }

            Rectangle {
                width: 32
                height: 26
                radius: 4
                color: maxBtnMa.containsMouse ? "#211438" : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: root.visibility === Window.Maximized ? "❐" : "□"
                    color: maxBtnMa.containsMouse ? "#ffffff" : "#94a3b8"
                    font.pixelSize: 12
                }
                MouseArea {
                    id: maxBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.visibility === Window.Maximized) {
                            root.showNormal()
                        } else {
                            root.showMaximized()
                        }
                    }
                }
            }

            Rectangle {
                width: 34
                height: 26
                radius: 4
                color: closeBtnMa.containsMouse ? "#e11d48" : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeBtnMa.containsMouse ? "#ffffff" : "#94a3b8"
                    font.pixelSize: 11
                    font.bold: true
                }
                MouseArea {
                    id: closeBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: exitConfirmDialog.open()
                }
            }
        }
    }

    ColumnLayout {
        anchors.top: customTitleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.topMargin: 16
            Layout.bottomMargin: 106

            Rectangle {
                Layout.preferredWidth: 350
                Layout.minimumWidth: 350
                Layout.maximumWidth: 350
                Layout.fillHeight: true
                radius: 20
                color: "#130d22"
                border.color: "#2d1a4d"
                border.width: 1.5

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Rectangle {
                        id: headerClickArea
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 12
                        color: headerHoverArea.containsMouse ? "#211438" : "transparent"
                        border.color: headerHoverArea.containsMouse ? "#8b5cf6" : "transparent"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                radius: 10
                                color: "#180f2b"
                                border.color: "#381d60"
                                border.width: 1
                                clip: true

                                Image {
                                    id: appLogoImg
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: "qrc:/qt/qml/MusicPlayerApp/assets/logo1.png"
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize.width: 128
                                    sourceSize.height: 128
                                    mipmap: true
                                    smooth: true
                                    antialiasing: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                RowLayout {
                                    spacing: 4
                                    Text { text: "AETHERIA"; color: "#ffffff"; font.pixelSize: 14; font.bold: true; font.letterSpacing: 2 }
                                    Text { text: "✦"; color: "#ec4899"; font.pixelSize: 10; visible: headerHoverArea.containsMouse }
                                }
                                Text { text: "Studio Audio Suite"; color: "#a78bfa"; font.pixelSize: 10 }
                            }
                        }

                        MouseArea {
                            id: headerHoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: developerDialog.open()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        Layout.fillHeight: false
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            Layout.fillHeight: false
                            radius: 8
                            color: root.activeCenterTab === "stage" ? "#2a154a" : "#19102c"
                            border.color: root.activeCenterTab === "stage" ? "#8b5cf6" : "transparent"
                            border.width: 1
                            Text { anchors.centerIn: parent; text: "Stage"; color: root.activeCenterTab === "stage" ? "#ffffff" : "#71717a"; font.pixelSize: 11; font.bold: root.activeCenterTab === "stage" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activeCenterTab = "stage" }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            Layout.fillHeight: false
                            radius: 8
                            color: root.activeCenterTab === "lyrics" ? "#2a154a" : "#19102c"
                            border.color: root.activeCenterTab === "lyrics" ? "#ec4899" : "transparent"
                            border.width: 1
                            Text { anchors.centerIn: parent; text: "Lyrics"; color: root.activeCenterTab === "lyrics" ? "#ffffff" : "#71717a"; font.pixelSize: 11; font.bold: root.activeCenterTab === "lyrics" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activeCenterTab = "lyrics" }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            Layout.fillHeight: false
                            radius: 8
                            color: root.activeCenterTab === "discover" ? "#2a154a" : "#19102c"
                            border.color: root.activeCenterTab === "discover" ? "#ec4899" : "transparent"
                            border.width: 1
                            Text { anchors.centerIn: parent; text: "Discover"; color: root.activeCenterTab === "discover" ? "#ffffff" : "#71717a"; font.pixelSize: 11; font.bold: root.activeCenterTab === "discover" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activeCenterTab = "discover" }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        Layout.fillHeight: false
                        radius: 10
                        color: "#1a1030"
                        border.color: localSearchField.activeFocus ? "#a855f7" : "#2e1a50"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Shape {
                                width: 14
                                height: 14
                                smooth: true
                                antialiasing: true

                                ShapePath {
                                    strokeWidth: 1.6
                                    strokeColor: localSearchField.activeFocus ? "#a855f7" : "#a78bfa"
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    startX: 10; startY: 5.5
                                    PathArc { x: 1; y: 5.5; radiusX: 4.5; radiusY: 4.5; useLargeArc: false }
                                    PathArc { x: 10; y: 5.5; radiusX: 4.5; radiusY: 4.5; useLargeArc: false }
                                }
                                ShapePath {
                                    strokeWidth: 2
                                    strokeColor: localSearchField.activeFocus ? "#a855f7" : "#a78bfa"
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    startX: 8.8; startY: 8.8
                                    PathLine { x: 13; y: 13 }
                                }
                            }

                            TextField {
                                id: localSearchField
                                Layout.fillWidth: true
                                placeholderText: "Filter local tracks, artists..."
                                placeholderTextColor: "#64748b"
                                color: "#ffffff"
                                font.pixelSize: 11
                                background: Item {}
                                onTextChanged: TrackModel.filterText = text

                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Escape) {
                                        localSearchField.focus = false
                                        root.forceActiveFocus()
                                        event.accepted = true
                                    }
                                }
                            }

                            Text {
                                text: "✕"
                                color: "#71717a"
                                font.pixelSize: 11
                                visible: localSearchField.text.length > 0
                                MouseArea { anchors.fill: parent; onClicked: localSearchField.text = "" }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        Layout.fillHeight: false
                        spacing: 6

                        Item {
                            id: tabsScrollContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            Flickable {
                                id: playlistTabsFlickable
                                anchors.fill: parent
                                contentWidth: categoriesRow.implicitWidth + 12
                                contentHeight: height
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.HorizontalFlick

                                Row {
                                    id: categoriesRow
                                    spacing: 6
                                    height: parent.height

                                    Rectangle {
                                        width: allTxt.implicitWidth + 18
                                        height: 26
                                        radius: 6
                                        color: (TrackModel.currentPlaylist === "" && !TrackModel.showOnlyLiked) ? "#2e1065" : "#1a1030"
                                        border.color: (TrackModel.currentPlaylist === "" && !TrackModel.showOnlyLiked) ? "#8b5cf6" : "#2e1a50"
                                        Text {
                                            id: allTxt
                                            anchors.centerIn: parent
                                            text: "All (" + TrackModel.count + ")"
                                            color: (TrackModel.currentPlaylist === "" && !TrackModel.showOnlyLiked) ? "#f5d0fe" : "#71717a"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { TrackModel.currentPlaylist = ""; TrackModel.showOnlyLiked = false; }
                                        }
                                    }

                                    Rectangle {
                                        width: likedTxt.implicitWidth + 18
                                        height: 26
                                        radius: 6
                                        color: TrackModel.showOnlyLiked ? "#3b1130" : "#1a1030"
                                        border.color: TrackModel.showOnlyLiked ? "#ec4899" : "#2e1a50"
                                        Text {
                                            id: likedTxt
                                            anchors.centerIn: parent
                                            text: "♥ Liked"
                                            color: TrackModel.showOnlyLiked ? "#f472b6" : "#71717a"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: TrackModel.showOnlyLiked = true
                                        }
                                    }

                                    Repeater {
                                        model: TrackModel.playlistNames
                                        delegate: Rectangle {
                                            id: plTab
                                            required property string modelData
                                            width: plRow.implicitWidth + 24
                                            height: 26
                                            radius: 6
                                            color: TrackModel.currentPlaylist === plTab.modelData ? "#1e1b4b" : "#1a1030"
                                            border.color: TrackModel.currentPlaylist === plTab.modelData ? "#6366f1" : "#2e1a50"

                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.rightMargin: 20
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    TrackModel.showOnlyLiked = false
                                                    TrackModel.currentPlaylist = plTab.modelData
                                                }
                                            }

                                            RowLayout {
                                                id: plRow
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Text {
                                                    text: plTab.modelData
                                                    color: TrackModel.currentPlaylist === plTab.modelData ? "#a5b4fc" : "#71717a"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }

                                                Item {
                                                    width: 16
                                                    height: 16
                                                    z: 2

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "✕"
                                                        color: delPlMa.containsMouse ? "#ef4444" : "#71717a"
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                    }

                                                    MouseArea {
                                                        id: delPlMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: TrackModel.removePlaylist(plTab.modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                propagateComposedEvents: true
                                onWheel: (wheel) => {
                                    var step = 45
                                    if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0) {
                                        playlistTabsFlickable.contentX = Math.min(playlistTabsFlickable.contentWidth - playlistTabsFlickable.width, playlistTabsFlickable.contentX + step)
                                    } else {
                                        playlistTabsFlickable.contentX = Math.max(0, playlistTabsFlickable.contentX - step)
                                    }
                                }
                                onPressed: (mouse) => mouse.accepted = false
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 18
                                visible: playlistTabsFlickable.contentWidth > playlistTabsFlickable.width && playlistTabsFlickable.contentX < (playlistTabsFlickable.contentWidth - playlistTabsFlickable.width - 2)
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: "#130d22" }
                                }
                            }
                        }

                        Button {
                            id: plusActionBtn
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 26
                            onClicked: addActionMenu.open()

                            background: Rectangle {
                                radius: 6
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: plusActionBtn.hovered ? "#9333ea" : "#7c3aed" }
                                    GradientStop { position: 1.0; color: plusActionBtn.hovered ? "#f43f5e" : "#ec4899" }
                                }
                            }

                            contentItem: Text {
                                text: "＋"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            HoverHandler { cursorShape: Qt.PointingHandCursor }

                            Popup {
                                id: addActionMenu
                                y: plusActionBtn.height + 4
                                x: -width + plusActionBtn.width
                                width: 170
                                padding: 6
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                                background: Rectangle {
                                    radius: 10
                                    color: "#160f26"
                                    border.color: "#8b5cf6"
                                    border.width: 1
                                }

                                contentItem: ColumnLayout {
                                    spacing: 4

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32
                                        radius: 6
                                        color: item1Ma.containsMouse ? "#2e1065" : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8
                                            Text { text: "📁"; font.pixelSize: 12 }
                                            Text { text: "New Playlist"; color: "#f5d0fe"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                                        }

                                        MouseArea {
                                            id: item1Ma
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                addActionMenu.close()
                                                createPlaylistStandaloneDialog.open()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32
                                        radius: 6
                                        color: item2Ma.containsMouse ? "#2e1065" : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8
                                            Text { text: "🎵"; font.pixelSize: 12 }
                                            Text { text: "Add Music Folder"; color: "#f5d0fe"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                                        }

                                        MouseArea {
                                            id: item2Ma
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                addActionMenu.close()
                                                folderDialog.open()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        Layout.fillHeight: false
                        radius: 6
                        color: "#1e1b4b"
                        border.color: "#6366f1"
                        visible: TrackModel.currentPlaylist !== ""

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "＋ Add Multiple Tracks to " + TrackModel.currentPlaylist; color: "#c7d2fe"; font.pixelSize: 10; font.bold: true }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: multiSelectDialog.open() }
                    }

                    ListView {
                        id: playlistView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: TrackModel
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        reuseItems: true

                        ScrollBar.vertical: ScrollBar {
                            id: customVScrollBar
                            parent: playlistView
                            anchors.right: playlistView.right
                            anchors.top: playlistView.top
                            anchors.bottom: playlistView.bottom
                            anchors.rightMargin: 2
                            width: 7
                            policy: ScrollBar.AsNeeded

                            property bool shouldShow: playlistMouseHoverArea.containsMouse || customVScrollBar.hovered || customVScrollBar.pressed

                            onShouldShowChanged: {
                                if (shouldShow) {
                                    scrollHideTimer.stop()
                                    customVScrollBar.opacity = 1.0
                                } else {
                                    scrollHideTimer.restart()
                                }
                            }

                            Timer {
                                id: scrollHideTimer
                                interval: 1500
                                repeat: false
                                onTriggered: customVScrollBar.opacity = 0.0
                            }

                            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }

                            background: Rectangle {
                                implicitWidth: 7
                                radius: 3.5
                                color: "#160f26"
                                opacity: 0.55
                            }

                            contentItem: Rectangle {
                                implicitWidth: 7
                                radius: 3.5
                                border.width: 0.5
                                border.color: customVScrollBar.pressed ? "#f472b6" : "#ec4899"
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop {
                                        position: 0.0
                                        color: customVScrollBar.pressed ? "#ff2a85" : "#c084fc"
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: customVScrollBar.pressed ? "#be185d" : "#8b5cf6"
                                    }
                                }

                                Behavior on border.color { ColorAnimation { duration: 150 } }
                            }
                        }

                        MouseArea {
                            id: playlistMouseHoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            propagateComposedEvents: true
                            z: -1
                        }

                        delegate: Rectangle {
                            id: trackItem
                            width: playlistView.width - (customVScrollBar.visible ? 10 : 0)
                            height: 56
                            radius: 10

                            readonly property bool isCurrentPlaying: (model.filePath !== undefined && model.filePath !== "" && model.filePath === root.activeFilePath)

                            color: itemMouse.containsMouse ? "#261545" : (isCurrentPlaying ? "#211038" : "#1a1030")
                            border.color: isCurrentPlaying ? "#ec4899" : (itemMouse.containsMouse ? "#a855f7" : "#261642")
                            border.width: isCurrentPlaying ? 1.5 : 1

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                anchors.rightMargin: 90
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor

                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        TrackModel.setCurrentIndex(index)
                                    } else if (mouse.button === Qt.RightButton) {
                                        trackContextMenu.x = mouse.x
                                        trackContextMenu.y = mouse.y
                                        trackContextMenu.open()
                                    }
                                }

                                Popup {
                                    id: trackContextMenu
                                    width: 170
                                    padding: 6
                                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                                    background: Rectangle {
                                        radius: 10
                                        color: "#160f26"
                                        border.color: "#8b5cf6"
                                        border.width: 1
                                    }

                                    contentItem: ColumnLayout {
                                        spacing: 4

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 6
                                            color: ctxEditMa.containsMouse ? "#2e1065" : "transparent"

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 8
                                                Text { text: "✎"; font.pixelSize: 13; color: "#ec4899" }
                                                Text { text: "Edit Track Info"; color: "#ffffff"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                                            }

                                            MouseArea {
                                                id: ctxEditMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    trackContextMenu.close()
                                                    editTrackDialog.targetFilePath = model.filePath
                                                    editTrackDialog.targetIndex = index
                                                    editTitleField.text = model.title ? model.title : ""
                                                    editArtistField.text = (model.artist && model.artist !== "Local Artist") ? model.artist : ""
                                                    editAlbumField.text = (model.album && model.album !== "Single Track") ? model.album : ""
                                                    editTrackDialog.open()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 6
                                            color: ctxAddPlMa.containsMouse ? "#2e1065" : "transparent"

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 8
                                                Text { text: "＋"; font.pixelSize: 13; color: "#a78bfa" }
                                                Text { text: "Add to Playlist"; color: "#ffffff"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                                            }

                                            MouseArea {
                                                id: ctxAddPlMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    trackContextMenu.close()
                                                    playlistChooserDialog.targetFilePath = model.filePath
                                                    playlistChooserDialog.open()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 1
                                            color: "#2a1b47"
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 6
                                            color: ctxDelMa.containsMouse ? "#4c0519" : "transparent"

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 8
                                                Text { text: "✕"; font.pixelSize: 11; color: "#ef4444" }
                                                Text { text: "Delete Track"; color: "#f87171"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                                            }

                                            MouseArea {
                                                id: ctxDelMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    trackContextMenu.close()
                                                    if (TrackModel.currentPlaylist !== "") {
                                                        TrackModel.removeFromPlaylist(TrackModel.currentPlaylist, model.filePath)
                                                    } else {
                                                        TrackModel.deleteTrackFromLibrary(index)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    radius: 8
                                    color: "#1e1333"
                                    clip: true

                                    Image {
                                        id: trackCoverImg
                                        anchors.fill: parent
                                        source: {
                                            var p = (model.coverPath !== undefined && model.coverPath !== null) ? model.coverPath : ""
                                            if (p === "") return ""
                                            if (p.indexOf("http") === 0 || p.indexOf("file:///") === 0 || p.indexOf("qrc:/") === 0) return p
                                            return "file:///" + p.replace(/\\/g, "/")
                                        }
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: 80
                                        sourceSize.height: 80
                                        asynchronous: true
                                        cache: true
                                        visible: status === Image.Ready
                                    }

                                    Image {
                                        anchors.centerIn: parent
                                        width: 22
                                        height: 22
                                        source: "qrc:/qt/qml/MusicPlayerApp/assets/logo1.png"
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize.width: 48
                                        sourceSize.height: 48
                                        smooth: true
                                        mipmap: true
                                        visible: !trackCoverImg.visible
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2
                                    clip: true

                                    Item {
                                        id: leftTitleBox
                                        Layout.fillWidth: true
                                        height: 18
                                        clip: true

                                        readonly property string itemTitle: model.title ? model.title : "Unknown Title"
                                        readonly property bool isLong: width > 10 && leftTitleTxt.implicitWidth > (width + 6)

                                        Text {
                                            id: leftTitleTxt
                                            text: leftTitleBox.itemTitle
                                            color: trackItem.isCurrentPlaying ? "#f472b6" : "#f8fafc"
                                            font.pixelSize: 12
                                            font.bold: true
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: 0

                                            SequentialAnimation {
                                                id: leftTitleAnim
                                                running: leftTitleBox.isLong
                                                loops: Animation.Infinite

                                                onRunningChanged: {
                                                    if (!running) leftTitleTxt.x = 0
                                                }

                                                PauseAnimation { duration: 2000 }
                                                NumberAnimation {
                                                    target: leftTitleTxt
                                                    property: "x"
                                                    from: 0
                                                    to: -(leftTitleTxt.implicitWidth - leftTitleBox.width + 10)
                                                    duration: Math.max(2500, (leftTitleTxt.implicitWidth - leftTitleBox.width) * 30)
                                                    easing.type: Easing.InOutQuad
                                                }
                                                PauseAnimation { duration: 1500 }
                                                NumberAnimation {
                                                    target: leftTitleTxt
                                                    property: "x"
                                                    from: -(leftTitleTxt.implicitWidth - leftTitleBox.width + 10)
                                                    to: 0
                                                    duration: Math.max(2500, (leftTitleTxt.implicitWidth - leftTitleBox.width) * 30)
                                                    easing.type: Easing.InOutQuad
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Item {
                                            id: leftArtistBox
                                            Layout.fillWidth: true
                                            height: 16
                                            clip: true

                                            readonly property string itemArtist: (model.artist && model.artist !== "") ? model.artist : "Local Artist"
                                            readonly property bool isLong: width > 10 && leftArtistTxt.implicitWidth > (width + 6)

                                            Text {
                                                id: leftArtistTxt
                                                text: leftArtistBox.itemArtist
                                                color: "#a78bfa"
                                                font.pixelSize: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: 0

                                                SequentialAnimation {
                                                    id: leftArtistAnim
                                                    running: leftArtistBox.isLong
                                                    loops: Animation.Infinite

                                                    onRunningChanged: {
                                                        if (!running) leftArtistTxt.x = 0
                                                    }

                                                    PauseAnimation { duration: 2000 }
                                                    NumberAnimation {
                                                        target: leftArtistTxt
                                                        property: "x"
                                                        from: 0
                                                        to: -(leftArtistTxt.implicitWidth - leftArtistBox.width + 10)
                                                        duration: Math.max(2500, (leftArtistTxt.implicitWidth - leftArtistBox.width) * 35)
                                                        easing.type: Easing.InOutQuad
                                                    }
                                                    PauseAnimation { duration: 1500 }
                                                    NumberAnimation {
                                                        target: leftArtistTxt
                                                        property: "x"
                                                        from: -(leftArtistTxt.implicitWidth - leftArtistBox.width + 10)
                                                        to: 0
                                                        duration: Math.max(2500, (leftArtistTxt.implicitWidth - leftArtistBox.width) * 35)
                                                        easing.type: Easing.InOutQuad
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: "• " + (model.duration ? model.duration : "--:--")
                                            color: "#71717a"
                                            font.pixelSize: 9
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 4
                                    Layout.alignment: Qt.AlignVCenter

                                    Item {
                                        width: 24
                                        height: 24

                                        Text {
                                            anchors.centerIn: parent
                                            text: "＋"
                                            color: addPlMa.containsMouse ? "#ffffff" : "#a78bfa"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: addPlMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                playlistChooserDialog.targetFilePath = model.filePath
                                                playlistChooserDialog.open()
                                            }
                                        }
                                    }

                                    Item {
                                        width: 24
                                        height: 24

                                        Text {
                                            anchors.centerIn: parent
                                            text: model.isLiked ? "♥" : "♡"
                                            color: model.isLiked ? "#ec4899" : (likeMouse.containsMouse ? "#f472b6" : "#64748b")
                                            font.pixelSize: 16
                                        }

                                        MouseArea {
                                            id: likeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (model.filePath !== undefined && model.filePath !== "") {
                                                    TrackModel.toggleLikeByPath(model.filePath)
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        width: 24
                                        height: 24

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: delMa.containsMouse ? "#ef4444" : "#71717a"
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: delMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (TrackModel.currentPlaylist !== "") {
                                                    TrackModel.removeFromPlaylist(TrackModel.currentPlaylist, model.filePath)
                                                } else {
                                                    TrackModel.deleteTrackFromLibrary(index)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 20
                color: "#130d22"
                border.color: "#2d1a4d"
                border.width: 1.5
                clip: true

                StageView {
                    visible: root.activeCenterTab === "stage"
                }

                LyricsView {
                    visible: root.activeCenterTab === "lyrics"
                }

                DiscoverView {
                    visible: root.activeCenterTab === "discover"
                }
            }
        }
    }

    Rectangle {
        id: bottomPlayerBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 96
        color: "#0e081a"
        border.color: "#25173d"
        border.width: 1
        z: 10

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: progressSlider.pressed
                        ? root.formatTime(progressSlider.value)
                        : root.formatTime(AudioEngine.position)
                    color: "#a78bfa"
                    font.pixelSize: 11
                }

                Slider {
                    id: progressSlider
                    Layout.fillWidth: true
                    from: 0
                    to: Math.max(1000, AudioEngine.duration)
                    property bool wasPlayingBeforeDrag: false

                    property real safePosition: 0

                    Connections {
                        target: AudioEngine
                        function onPositionChanged(pos) {
                            if (progressSlider.pressed) return;
                            if (AudioEngine.isPlaying && pos < progressSlider.safePosition && (progressSlider.safePosition - pos) < 3000) {
                                return;
                            }
                            progressSlider.safePosition = pos;
                        }
                    }

                    value: pressed ? value : safePosition

                    onMoved: {
                        if (root.hasActiveTrack) {
                            safePosition = value
                            AudioEngine.setPosition(Math.round(value))
                        }
                    }

                    onPressedChanged: {
                        if (pressed) {
                            wasPlayingBeforeDrag = AudioEngine.isPlaying
                            if (wasPlayingBeforeDrag) {
                                AudioEngine.pause()
                            }
                        } else {
                            if (root.hasActiveTrack) {
                                safePosition = value
                                AudioEngine.setPosition(Math.round(value))
                                if (wasPlayingBeforeDrag) {
                                    AudioEngine.play()
                                }
                            }
                        }
                    }

                    background: Rectangle {
                        x: progressSlider.leftPadding
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 5
                        width: progressSlider.availableWidth
                        height: implicitHeight
                        radius: 3
                        color: "#1e1333"

                        Rectangle {
                            width: Math.min(parent.width, Math.max(0, (progressSlider.safePosition / progressSlider.to) * parent.width))
                            height: parent.height
                            radius: 3
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#8b5cf6" }
                                GradientStop { position: 1.0; color: "#ec4899" }
                            }
                        }
                    }

                    handle: Rectangle {
                        x: progressSlider.leftPadding + Math.min(progressSlider.availableWidth - width, Math.max(0, (progressSlider.safePosition / progressSlider.to) * (progressSlider.availableWidth - width)))
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        implicitWidth: 14
                        implicitHeight: 14
                        radius: 7
                        color: "#ffffff"
                        border.color: "#ec4899"
                        border.width: 2
                    }
                }

                Text { text: root.formatTime(AudioEngine.duration); color: "#a78bfa"; font.pixelSize: 11 }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 52

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 10
                        color: "#1e1333"
                        border.color: "#381e66"
                        clip: true

                        Image {
                            id: miniPlayerCoverImg
                            anchors.fill: parent

                            source: {
                                var p = (root.activeCover !== "" && root.activeCover !== undefined) ? root.activeCover : ""
                                if (p === "") return ""
                                if (p.indexOf("http") === 0 || p.indexOf("file:///") === 0 || p.indexOf("qrc:/") === 0) return p
                                return "file:///" + p.replace(/\\/g, "/")
                            }

                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 80
                            sourceSize.height: 80
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            source: "qrc:/qt/qml/MusicPlayerApp/assets/logo1.png"
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: 48
                            sourceSize.height: 48
                            smooth: true
                            mipmap: true
                            visible: !miniPlayerCoverImg.visible
                        }
                    }

                    Column {
                        id: trackTextColumn
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        width: Math.min(200, Math.max(bottomTitleText.implicitWidth, bottomArtistText.implicitWidth))

                        Item {
                            id: bottomTitleBox
                            width: parent.width
                            height: 18
                            clip: true

                            readonly property string currentTitle: {
                                if (root.activeTitle && root.activeTitle !== "" && root.activeTitle !== "No Active Stream" && root.activeTitle !== "Unknown Title") {
                                    return root.activeTitle
                                }
                                return root.cleanTrackDisplay(root.activeFilePath !== "" ? root.activeFilePath : AudioEngine.currentSource)
                            }

                            readonly property bool isLong: width > 0 && bottomTitleText.implicitWidth > (width + 4)

                            onCurrentTitleChanged: {
                                bottomTitleAnim.stop()
                                bottomTitleText.x = 0
                                if (isLong) {
                                    bottomTitleAnim.restart()
                                }
                            }

                            Text {
                                id: bottomTitleText
                                text: bottomTitleBox.currentTitle
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                x: 0

                                SequentialAnimation {
                                    id: bottomTitleAnim
                                    running: bottomTitleBox.isLong
                                    loops: Animation.Infinite

                                    onRunningChanged: {
                                        if (!running) bottomTitleText.x = 0
                                    }

                                    PauseAnimation { duration: 2000 }
                                    NumberAnimation {
                                        target: bottomTitleText
                                        property: "x"
                                        from: 0
                                        to: -(bottomTitleText.implicitWidth - bottomTitleBox.width + 12)
                                        duration: Math.max(2500, (bottomTitleText.implicitWidth - bottomTitleBox.width) * 30)
                                        easing.type: Easing.InOutQuad
                                    }
                                    PauseAnimation { duration: 1500 }
                                    NumberAnimation {
                                        target: bottomTitleText
                                        property: "x"
                                        from: -(bottomTitleText.implicitWidth - bottomTitleBox.width + 12)
                                        to: 0
                                        duration: Math.max(2500, (bottomTitleText.implicitWidth - bottomTitleBox.width) * 30)
                                        easing.type: Easing.InOutQuad
                                    }
                                }
                            }
                        }

                        Item {
                            id: bottomArtistBox
                            width: parent.width
                            height: 16
                            clip: true

                            readonly property string currentArtist: (root.activeArtist && root.activeArtist !== "" && root.activeArtist !== "Idle") ? root.activeArtist : "Local Artist"
                            readonly property bool isLong: width > 0 && bottomArtistText.implicitWidth > (width + 4)

                            onCurrentArtistChanged: {
                                bottomArtistAnim.stop()
                                bottomArtistText.x = 0
                                if (isLong) {
                                    bottomArtistAnim.restart()
                                }
                            }

                            Text {
                                id: bottomArtistText
                                text: bottomArtistBox.currentArtist
                                color: "#a78bfa"
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                                x: 0

                                SequentialAnimation {
                                    id: bottomArtistAnim
                                    running: bottomArtistBox.isLong
                                    loops: Animation.Infinite

                                    onRunningChanged: {
                                        if (!running) bottomArtistText.x = 0
                                    }

                                    PauseAnimation { duration: 2000 }
                                    NumberAnimation {
                                        target: bottomArtistText
                                        property: "x"
                                        from: 0
                                        to: -(bottomArtistText.implicitWidth - bottomArtistBox.width + 10)
                                        duration: Math.max(2500, (bottomArtistText.implicitWidth - bottomArtistBox.width) * 35)
                                        easing.type: Easing.InOutQuad
                                    }
                                    PauseAnimation { duration: 1500 }
                                    NumberAnimation {
                                        target: bottomArtistText
                                        property: "x"
                                        from: -(bottomArtistText.implicitWidth - bottomArtistBox.width + 10)
                                        to: 0
                                        duration: Math.max(2500, (bottomArtistText.implicitWidth - bottomArtistBox.width) * 35)
                                        easing.type: Easing.InOutQuad
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        visible: root.activeFilePath !== ""

                        Text {
                            anchors.centerIn: parent
                            text: root.isCurrentTrackLiked ? "♥" : "♡"
                            color: root.isCurrentTrackLiked ? "#ec4899" : (bottomLikeMa.containsMouse ? "#f472b6" : "#64748b")
                            font.pixelSize: 17
                        }

                        MouseArea {
                            id: bottomLikeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activeFilePath !== "") {
                                    TrackModel.toggleLikeByPath(root.activeFilePath)
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 16

                    Rectangle {
                        id: shuffleBtnBox
                        width: 36
                        height: 36
                        radius: 18
                        color: AudioEngine.isShuffle ? "#331238" : (shufMa.containsMouse ? "#261545" : "transparent")
                        border.color: AudioEngine.isShuffle ? "#ec4899" : (shufMa.containsMouse ? "#a855f7" : "transparent")
                        border.width: 1

                        readonly property color iconColor: AudioEngine.isShuffle ? "#f472b6" : (shufMa.containsMouse ? "#ffffff" : "#c084fc")

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Shape {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            smooth: true
                            antialiasing: true

                            ShapePath {
                                strokeWidth: 0
                                fillColor: shuffleBtnBox.iconColor
                                fillRule: ShapePath.WindingFill

                                startX: 1; startY: 12
                                PathLine { x: 4; y: 12 }
                                PathLine { x: 10; y: 4 }
                                PathLine { x: 12; y: 4 }
                                PathLine { x: 12; y: 6.5 }
                                PathLine { x: 16; y: 3 }
                                PathLine { x: 12; y: -0.5 }
                                PathLine { x: 12; y: 2 }
                                PathLine { x: 9; y: 2 }
                                PathLine { x: 3; y: 10 }
                                PathLine { x: 1; y: 10 }
                                PathLine { x: 1; y: 12 }
                            }

                            ShapePath {
                                strokeWidth: 0
                                fillColor: shuffleBtnBox.iconColor
                                fillRule: ShapePath.WindingFill

                                startX: 1; startY: 4
                                PathLine { x: 4; y: 4 }
                                PathLine { x: 6; y: 6.5 }
                                PathLine { x: 4.5; y: 8.5 }
                                PathLine { x: 3; y: 6 }
                                PathLine { x: 1; y: 6 }
                                PathLine { x: 1; y: 4 }
                            }

                            ShapePath {
                                strokeWidth: 0
                                fillColor: shuffleBtnBox.iconColor
                                fillRule: ShapePath.WindingFill

                                startX: 8.5; startY: 7.5
                                PathLine { x: 10; y: 9.5 }
                                PathLine { x: 12; y: 9.5 }
                                PathLine { x: 12; y: 7.5 }
                                PathLine { x: 16; y: 11 }
                                PathLine { x: 12; y: 14.5 }
                                PathLine { x: 12; y: 12 }
                                PathLine { x: 9; y: 12 }
                                PathLine { x: 7; y: 9.5 }
                                PathLine { x: 8.5; y: 7.5 }
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            width: 4
                            height: 4
                            radius: 2
                            color: "#ec4899"
                            visible: AudioEngine.isShuffle
                        }

                        MouseArea {
                            id: shufMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AudioEngine.toggleShuffle()
                        }

                        ToolTip.visible: shufMa.containsMouse
                        ToolTip.text: AudioEngine.isShuffle ? "Shuffle: ON" : "Shuffle: OFF"
                        ToolTip.delay: 300
                    }

                    Rectangle {
                        id: prevBtnBox
                        width: 36
                        height: 36
                        radius: 18
                        color: prevMouse.containsMouse ? "#261545" : "transparent"
                        border.color: prevMouse.containsMouse ? "#a855f7" : "transparent"
                        border.width: 1

                        Shape {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            ShapePath {
                                strokeWidth: 0
                                fillColor: prevMouse.containsMouse ? "#ffffff" : "#c084fc"
                                startX: 0; startY: 1
                                PathLine { x: 2.5; y: 1 }
                                PathLine { x: 2.5; y: 13 }
                                PathLine { x: 0; y: 13 }
                                PathLine { x: 0; y: 1 }
                            }
                            ShapePath {
                                strokeWidth: 0
                                fillColor: prevMouse.containsMouse ? "#ffffff" : "#c084fc"
                                startX: 14; startY: 1
                                PathLine { x: 3; y: 7 }
                                PathLine { x: 14; y: 13 }
                                PathLine { x: 14; y: 1 }
                            }
                        }

                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: TrackModel.playPrevious()
                        }
                    }

                    Rectangle {
                        id: mainPlayBtn
                        width: 50
                        height: 50
                        radius: 25
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: playMouse.pressed ? "#6d28d9" : "#7c3aed" }
                            GradientStop { position: 1.0; color: playMouse.pressed ? "#db2777" : "#ec4899" }
                        }
                        scale: playMouse.containsMouse ? 1.06 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        Shape {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 1.5
                            width: 16
                            height: 18
                            visible: !AudioEngine.isPlaying
                            ShapePath {
                                strokeWidth: 0
                                fillColor: "#ffffff"
                                startX: 1; startY: 1
                                PathLine { x: 15; y: 9 }
                                PathLine { x: 1; y: 17 }
                                PathLine { x: 1; y: 1 }
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            visible: AudioEngine.isPlaying

                            Rectangle { width: 4; height: 16; radius: 2; color: "#ffffff" }
                            Rectangle { width: 4; height: 16; radius: 2; color: "#ffffff" }
                        }

                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AudioEngine.togglePlayPause()
                        }
                    }

                    Rectangle {
                        id: nextBtnBox
                        width: 36
                        height: 36
                        radius: 18
                        color: nextMouse.containsMouse ? "#261545" : "transparent"
                        border.color: nextMouse.containsMouse ? "#a855f7" : "transparent"
                        border.width: 1

                        Shape {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            ShapePath {
                                strokeWidth: 0
                                fillColor: nextMouse.containsMouse ? "#ffffff" : "#c084fc"
                                startX: 0; startY: 1
                                PathLine { x: 11; y: 7 }
                                PathLine { x: 0; y: 13 }
                                PathLine { x: 0; y: 1 }
                            }
                            ShapePath {
                                strokeWidth: 0
                                fillColor: nextMouse.containsMouse ? "#ffffff" : "#c084fc"
                                startX: 11.5; startY: 1
                                PathLine { x: 14; y: 1 }
                                PathLine { x: 14; y: 13 }
                                PathLine { x: 11.5; y: 13 }
                                PathLine { x: 11.5; y: 1 }
                            }
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: TrackModel.playNextTrack(AudioEngine.isShuffle)
                        }
                    }

                    Rectangle {
                        id: repeatBtnBox
                        width: 36
                        height: 36
                        radius: 18
                        color: AudioEngine.repeatMode > 0 ? "#331238" : (repMa.containsMouse ? "#261545" : "transparent")
                        border.color: AudioEngine.repeatMode > 0 ? "#ec4899" : (repMa.containsMouse ? "#a855f7" : "transparent")
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Shape {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            smooth: true
                            antialiasing: true

                            ShapePath {
                                strokeWidth: 0
                                fillColor: AudioEngine.repeatMode > 0 ? "#f472b6" : (repMa.containsMouse ? "#ffffff" : "#c084fc")
                                startX: 4; startY: 2
                                PathLine { x: 12; y: 2 }
                                PathLine { x: 14.5; y: 4.5 }
                                PathLine { x: 14.5; y: 8 }
                                PathLine { x: 12.5; y: 8 }
                                PathLine { x: 12.5; y: 5 }
                                PathLine { x: 11; y: 4 }
                                PathLine { x: 4; y: 4 }
                                PathLine { x: 4; y: 2 }
                            }

                            ShapePath {
                                strokeWidth: 0
                                fillColor: AudioEngine.repeatMode > 0 ? "#f472b6" : (repMa.containsMouse ? "#ffffff" : "#c084fc")
                                startX: 5; startY: 0
                                PathLine { x: 0.5; y: 3 }
                                PathLine { x: 5; y: 6 }
                                PathLine { x: 4; y: 3 }
                                PathLine { x: 5; y: 0 }
                            }

                            ShapePath {
                                strokeWidth: 0
                                fillColor: AudioEngine.repeatMode > 0 ? "#f472b6" : (repMa.containsMouse ? "#ffffff" : "#c084fc")
                                startX: 12; startY: 14
                                PathLine { x: 4; y: 14 }
                                PathLine { x: 1.5; y: 11.5 }
                                PathLine { x: 1.5; y: 8 }
                                PathLine { x: 3.5; y: 8 }
                                PathLine { x: 3.5; y: 11 }
                                PathLine { x: 5; y: 12 }
                                PathLine { x: 12; y: 12 }
                                PathLine { x: 12; y: 14 }
                            }

                            ShapePath {
                                strokeWidth: 0
                                fillColor: AudioEngine.repeatMode > 0 ? "#f472b6" : (repMa.containsMouse ? "#ffffff" : "#c084fc")
                                startX: 11; startY: 10
                                PathLine { x: 15.5; y: 13 }
                                PathLine { x: 11; y: 16 }
                                PathLine { x: 12; y: 13 }
                                PathLine { x: 11; y: 10 }
                            }
                        }

                        Shape {
                            anchors.centerIn: parent
                            width: 6
                            height: 8
                            visible: AudioEngine.repeatMode === 2
                            smooth: true
                            antialiasing: true

                            ShapePath {
                                strokeWidth: 0
                                fillColor: "#f472b6"
                                startX: 1; startY: 2.5
                                PathLine { x: 3.5; y: 0.5 }
                                PathLine { x: 3.5; y: 7.5 }
                                PathLine { x: 2; y: 7.5 }
                                PathLine { x: 2; y: 2 }
                                PathLine { x: 0.5; y: 3 }
                                PathLine { x: 1; y: 2.5 }
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            width: 4
                            height: 4
                            radius: 2
                            color: "#ec4899"
                            visible: AudioEngine.repeatMode > 0
                        }

                        MouseArea {
                            id: repMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AudioEngine.cycleRepeatMode()
                        }

                        ToolTip.visible: repMa.containsMouse
                        ToolTip.text: AudioEngine.repeatMode === 2 ? "Repeat: Single Track" : (AudioEngine.repeatMode === 1 ? "Repeat: All Tracks" : "Repeat: OFF")
                        ToolTip.delay: 300
                    }
                }

                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

                    Rectangle {
                        id: sleepBtnItem
                        width: 36
                        height: 36
                        radius: 18
                        color: SleepTimer.isActive ? "#3b1130" : (sleepMouse.containsMouse ? "#261545" : "transparent")
                        border.color: SleepTimer.isActive ? "#ec4899" : (sleepMouse.containsMouse ? "#a855f7" : "transparent")
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Shape {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            visible: !SleepTimer.isActive
                            smooth: true
                            antialiasing: true

                            ShapePath {
                                strokeWidth: 0
                                fillColor: sleepMouse.containsMouse ? "#ffffff" : "#c084fc"

                                startX: 8; startY: 1
                                PathLine { x: 10.2; y: 5.8 }
                                PathLine { x: 15.5; y: 6.2 }
                                PathLine { x: 11.4; y: 9.8 }
                                PathLine { x: 12.7; y: 15 }
                                PathLine { x: 8; y: 12.2 }
                                PathLine { x: 3.3; y: 15 }
                                PathLine { x: 4.6; y: 9.8 }
                                PathLine { x: 0.5; y: 6.2 }
                                PathLine { x: 5.8; y: 5.8 }
                                PathLine { x: 8; y: 1 }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Math.ceil(SleepTimer.remainingSeconds / 60) + "m"
                            color: "#f472b6"
                            font.pixelSize: 10
                            font.bold: true
                            visible: SleepTimer.isActive
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            width: 4
                            height: 4
                            radius: 2
                            color: "#ec4899"
                            visible: SleepTimer.isActive
                        }

                        MouseArea {
                            id: sleepMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sleepPopup.open()
                        }

                        ToolTip.visible: sleepMouse.containsMouse
                        ToolTip.text: SleepTimer.isActive ? "Sleep Timer: Active" : "Set Sleep Timer"
                        ToolTip.delay: 300

                        Popup {
                            id: sleepPopup
                            y: -height - 10
                            x: -width / 2 + sleepBtnItem.width / 2
                            width: 160
                            padding: 8
                            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                            background: Rectangle {
                                radius: 12
                                color: "#160f26"
                                border.color: "#8b5cf6"
                                border.width: 1
                            }

                            contentItem: ColumnLayout {
                                spacing: 4

                                component MenuOption: Rectangle {
                                    id: optRoot
                                    property string title: ""
                                    property bool isDestructive: false
                                    signal selected()

                                    Layout.fillWidth: true
                                    height: 30
                                    radius: 6
                                    color: optMouse.hovered ? (isDestructive ? "#4c0519" : "#2e1065") : "transparent"

                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        text: optRoot.title
                                        color: optRoot.isDestructive ? "#fb7185" : (optMouse.hovered ? "#ffffff" : "#c084fc")
                                        font.pixelSize: 11
                                        font.bold: optMouse.hovered
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    HoverHandler { id: optMouse }
                                    TapHandler {
                                        onTapped: {
                                            optRoot.selected()
                                            sleepPopup.close()
                                        }
                                    }
                                }

                                MenuOption { title: "15 Minutes"; onSelected: SleepTimer.startTimer(15) }
                                MenuOption { title: "30 Minutes"; onSelected: SleepTimer.startTimer(30) }
                                MenuOption { title: "45 Minutes"; onSelected: SleepTimer.startTimer(45) }
                                MenuOption { title: "60 Minutes"; onSelected: SleepTimer.startTimer(60) }
                                MenuOption { title: "Custom Time..."; onSelected: customSleepDialog.open() }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: "#2a1b47"
                                    visible: SleepTimer.isActive
                                }

                                MenuOption {
                                    title: "Turn Off"
                                    isDestructive: true
                                    visible: SleepTimer.isActive
                                    onSelected: SleepTimer.cancelTimer()
                                }
                            }
                        }
                    }

                    RowLayout {
                        spacing: 8

                        Shape {
                            width: 16
                            height: 14
                            smooth: true
                            antialiasing: true

                            ShapePath {
                                strokeWidth: 0
                                fillColor: AudioEngine.volume > 0 ? (volHover.containsMouse ? "#ffffff" : "#c084fc") : "#64748b"
                                startX: 0.5; startY: 4.5
                                PathLine { x: 3.5; y: 4.5 }
                                PathLine { x: 7.5; y: 1 }
                                PathLine { x: 7.5; y: 13 }
                                PathLine { x: 3.5; y: 9.5 }
                                PathLine { x: 0.5; y: 9.5 }
                                PathLine { x: 0.5; y: 4.5 }
                            }

                            ShapePath {
                                strokeWidth: 1.5
                                strokeColor: AudioEngine.volume > 0.05 ? (volHover.containsMouse ? "#ffffff" : "#c084fc") : "transparent"
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                startX: 10; startY: 4
                                PathArc { x: 10; y: 10; radiusX: 3.5; radiusY: 3.5; useLargeArc: false }
                            }

                            ShapePath {
                                strokeWidth: 1.5
                                strokeColor: AudioEngine.volume > 0.5 ? (volHover.containsMouse ? "#ffffff" : "#c084fc") : "transparent"
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                startX: 13; startY: 2
                                PathArc { x: 13; y: 12; radiusX: 6; radiusY: 6; useLargeArc: false }
                            }

                            ShapePath {
                                strokeWidth: 1.5
                                strokeColor: AudioEngine.volume <= 0.01 ? "#ef4444" : "transparent"
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                startX: 9.5; startY: 4.5
                                PathLine { x: 14.5; y: 9.5 }
                            }
                            ShapePath {
                                strokeWidth: 1.5
                                strokeColor: AudioEngine.volume <= 0.01 ? "#ef4444" : "transparent"
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                startX: 14.5; startY: 4.5
                                PathLine { x: 9.5; y: 9.5 }
                            }

                            MouseArea {
                                id: volHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (AudioEngine.volume > 0) {
                                        AudioEngine.setVolume(0.0)
                                    } else {
                                        AudioEngine.setVolume(0.85)
                                    }
                                }
                            }
                        }

                        Slider {
                            id: volumeSlider
                            implicitWidth: 84
                            from: 0.0
                            to: 1.0
                            value: AudioEngine.volume
                            onMoved: AudioEngine.setVolume(volumeSlider.value)

                            background: Rectangle {
                                x: volumeSlider.leftPadding
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                implicitWidth: 84
                                implicitHeight: 4
                                width: volumeSlider.availableWidth
                                height: implicitHeight
                                radius: 2
                                color: "#1e1333"

                                Rectangle {
                                    width: volumeSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 2
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "#8b5cf6" }
                                        GradientStop { position: 1.0; color: "#ec4899" }
                                    }
                                }
                            }

                            handle: Rectangle {
                                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: 5
                                color: "#ffffff"
                                border.color: "#ec4899"
                                border.width: 1
                            }
                        }

                        Rectangle {
                            id: devBtnBox
                            width: 28
                            height: 28
                            radius: 6
                            color: devPopup.visible ? "#3b1130" : (devMa.containsMouse ? "#261545" : "#1a1030")
                            border.color: devPopup.visible ? "#ec4899" : (devMa.containsMouse ? "#a855f7" : "#2d1b4e")
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "🎧"
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: devMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (devPopup.visible) devPopup.close()
                                    else devPopup.open()
                                }
                            }

                            ToolTip.visible: devMa.containsMouse
                            ToolTip.text: "Output: " + AudioEngine.currentDeviceName
                            ToolTip.delay: 300

                            Popup {
                                id: devPopup
                                y: -height - 8
                                x: -width + devBtnBox.width
                                width: 250
                                padding: 8
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                                background: Rectangle {
                                    radius: 12
                                    color: "#120a1f"
                                    border.color: "#8b5cf6"
                                    border.width: 1.2

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        radius: 11
                                        color: "#180d29"
                                        opacity: 0.95
                                    }
                                }

                                contentItem: ColumnLayout {
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 4
                                        Layout.rightMargin: 4
                                        Layout.topMargin: 2

                                        Text {
                                            text: "AUDIO OUTPUT"
                                            color: "#a78bfa"
                                            font.pixelSize: 9
                                            font.bold: true
                                            font.letterSpacing: 1
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: AudioEngine.outputDevices.length + " Available"
                                            color: "#64748b"
                                            font.pixelSize: 9
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: "#271744"
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Repeater {
                                            model: AudioEngine.outputDevices

                                            delegate: Rectangle {
                                                id: devItem
                                                required property string modelData
                                                width: parent.width
                                                height: 32
                                                radius: 6

                                                readonly property bool isSelected: AudioEngine.currentDeviceName === modelData

                                                color: isSelected ? "#2d0b30" : (itemMa.containsMouse ? "#23133d" : "transparent")
                                                border.color: isSelected ? "#ec4899" : "transparent"
                                                border.width: 1

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 8
                                                    anchors.rightMargin: 8
                                                    spacing: 8

                                                    Text {
                                                        text: (devItem.modelData.toLowerCase().indexOf("headphone") !== -1 ||
                                                            devItem.modelData.toLowerCase().indexOf("airpod") !== -1 ||
                                                            devItem.modelData.toLowerCase().indexOf("buds") !== -1) ? "🎧" : "🔊"
                                                        font.pixelSize: 11
                                                    }

                                                    Text {
                                                        text: devItem.modelData
                                                        color: devItem.isSelected ? "#ffffff" : (itemMa.containsMouse ? "#f5d0fe" : "#c4b5fd")
                                                        font.pixelSize: 10
                                                        font.bold: devItem.isSelected
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        text: "●"
                                                        color: "#ec4899"
                                                        font.pixelSize: 8
                                                        visible: devItem.isSelected
                                                    }
                                                }

                                                MouseArea {
                                                    id: itemMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        AudioEngine.setAudioOutputDevice(devItem.modelData)
                                                        devPopup.close()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: eqBtnBox
                            width: 28
                            height: 28
                            radius: 6
                            color: eqPopup.visible ? "#3b1130" : (eqBtnMa.containsMouse ? "#261545" : "#1a1030")
                            border.color: eqPopup.visible ? "#ec4899" : (eqBtnMa.containsMouse ? "#a855f7" : "#2d1b4e")
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "EQ"
                                color: eqPopup.visible ? "#f472b6" : (eqBtnMa.containsMouse ? "#ffffff" : "#a78bfa")
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                id: eqBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (eqPopup.visible) eqPopup.close()
                                    else eqPopup.open()
                                }
                            }

                            ToolTip.visible: eqBtnMa.containsMouse
                            ToolTip.text: "10-Band Graphic Equalizer"
                            ToolTip.delay: 300
                        }





                    }
                }
            }
        }
    }

    Rectangle {
        id: floatingDownloadToast
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.bottom: bottomPlayerBar.top
        anchors.bottomMargin: 14
        width: 380
        height: 52
        radius: 12
        color: "#160b29"
        border.color: DownloadManager.isDownloading
            ? "#8b5cf6"
            : (DownloadManager.progressPercent === 100 ? "#4ade80" : "#ef4444")
        border.width: 1.2
        z: 100

        opacity: DownloadManager.showDownloadBar ? 1.0 : 0.0
        scale: DownloadManager.showDownloadBar ? 1.0 : 0.95
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        Behavior on border.color { ColorAnimation { duration: 250 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: DownloadManager.isDownloading
                    ? "#2e1065"
                    : (DownloadManager.progressPercent === 100 ? "#052e16" : "#450a0a")
                border.color: parent.parent.border.color
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: DownloadManager.isDownloading
                        ? "↓"
                        : (DownloadManager.progressPercent === 100 ? "✓" : "✕")
                    color: DownloadManager.isDownloading
                        ? "#c084fc"
                        : (DownloadManager.progressPercent === 100 ? "#4ade80" : "#f87171")
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: DownloadManager.isDownloading
                        ? (DownloadManager.statusMessage + " (" + DownloadManager.progressPercent + "%)")
                        : (DownloadManager.progressPercent === 100 ? "Download complete!" : DownloadManager.statusMessage)
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: 2
                    color: "#24133d"
                    visible: DownloadManager.isDownloading

                    Rectangle {
                        width: (DownloadManager.progressPercent / 100.0) * parent.width
                        height: parent.height
                        radius: 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#8b5cf6" }
                            GradientStop { position: 1.0; color: "#ec4899" }
                        }
                    }
                }

                Text {
                    text: DownloadManager.progressPercent === 100 ? "Saved to Music folder" : ""
                    color: "#94a3b8"
                    font.pixelSize: 9
                    visible: !DownloadManager.isDownloading && DownloadManager.progressPercent === 100
                }
            }

            Button {
                id: toastOpenFolderBtn
                text: "📂 Open"
                visible: !DownloadManager.isDownloading && DownloadManager.progressPercent === 100
                onClicked: DownloadManager.openDownloadFolder()
                background: Rectangle {
                    implicitWidth: 70
                    implicitHeight: 26
                    radius: 6
                    color: toastOpenFolderBtn.hovered ? "#3b114d" : "#2e1065"
                    border.color: "#8b5cf6"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 10
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }

            Button {
                id: toastCloseBtn
                text: "✕"
                onClicked: {
                    if (DownloadManager.isDownloading) {
                        DownloadManager.cancelDownload()
                    } else {
                        DownloadManager.dismissDownloadBar()
                    }
                }
                background: Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 12
                    color: toastCloseBtn.hovered ? "#3b1130" : "transparent"
                }
                contentItem: Text {
                    text: parent.text
                    color: toastCloseBtn.hovered ? "#ec4899" : "#a78bfa"
                    font.pixelSize: 11
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }
    }



    Item {
        anchors.fill: parent
        visible: root.visibility !== Window.Maximized
        z: 1001

        MouseArea {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 5
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.SizeVerCursor
            onPressed: (mouse) => { if (mouse.button === Qt.LeftButton) root.startSystemResize(Qt.TopEdge) }
        }
        MouseArea {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 6
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.SizeVerCursor
            onPressed: (mouse) => { if (mouse.button === Qt.LeftButton) root.startSystemResize(Qt.BottomEdge) }
        }
        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            width: 6
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.SizeHorCursor
            onPressed: (mouse) => { if (mouse.button === Qt.LeftButton) root.startSystemResize(Qt.LeftEdge) }
        }
        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            width: 6
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.SizeHorCursor
            onPressed: (mouse) => { if (mouse.button === Qt.LeftButton) root.startSystemResize(Qt.RightEdge) }
        }
        MouseArea {
            anchors.top: parent.top
            anchors.left: parent.left
            width: 12
            height: 12
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.SizeFDiagCursor
            onPressed: (mouse) => { if (mouse.button === Qt.LeftButton) root.startSystemResize(Qt.TopEdge | Qt.LeftEdge) }
        }
        MouseArea {
            anchors.top: parent.top
            anchors.right: parent.right
            width: 12
            height: 12
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.SizeBDiagCursor
            onPressed: (mouse) => { if (mouse.button === Qt.LeftButton) root.startSystemResize(Qt.TopEdge | Qt.RightEdge) }
        }
        MouseArea {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 12
            height: 12
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.SizeBDiagCursor
            onPressed: (mouse) => { if (mouse.button === Qt.LeftButton) root.startSystemResize(Qt.BottomEdge | Qt.LeftEdge) }
        }
        MouseArea {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 12
            height: 12
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.SizeFDiagCursor
            onPressed: (mouse) => { if (mouse.button === Qt.LeftButton) root.startSystemResize(Qt.BottomEdge | Qt.RightEdge) }
        }
    }


    Connections {
        target: MediaKeys

        function onToggleMiniPlayerTriggered() {
            if (floatingMiniPlayer.visible) {
                floatingMiniPlayer.hide()
                root.show()
                root.raise()
                root.requestActivate()
            } else {
                floatingMiniPlayer.openMiniPlayer()
                root.hide()
            }
        }
    }


    MiniPlayerWindow {
        id: floatingMiniPlayer
        trackTitle: root.activeTitle
        trackArtist: root.activeArtist
        trackCover: root.activeCover

        onRestoreRequested: {
            floatingMiniPlayer.hide()
            root.show()
            root.raise()
            root.requestActivate()
        }
    }


    Popup {
        id: eqPopup
        parent: Overlay.overlay

        width: 520
        height: 330

        x: Math.max(16, root.width - width - 24)
        y: Math.max(40, root.height - bottomPlayerBar.height - height - 12)

        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0
        background: Rectangle { color: "transparent" }

        EqualizerPanel {
            anchors.fill: parent
        }
    }


    Platform.SystemTrayIcon {
        id: appTrayIcon
        visible: !root.visible
        icon.source: "qrc:/qt/qml/MusicPlayerApp/assets/app_icon.ico"
        tooltip: root.hasActiveTrack ? (root.activeTitle + " - " + root.activeArtist) : "Aetheria Music Suite"

        onActivated: (reason) => {
            if (reason === Platform.SystemTrayIcon.DoubleClick || reason === Platform.SystemTrayIcon.Trigger) {
                floatingMiniPlayer.hide()
                root.show()
                root.raise()
                root.requestActivate()
            }
        }

        menu: Platform.Menu {
            Platform.MenuItem {
                text: "Open Aetheria"
                onTriggered: {
                    floatingMiniPlayer.hide()
                    root.show()
                    root.raise()
                    root.requestActivate()
                }
            }

            Platform.MenuItem {
                text: AudioEngine.isPlaying ? "Pause" : "Play"
                enabled: root.hasActiveTrack
                onTriggered: AudioEngine.togglePlayPause()
            }

            Platform.MenuItem {
                text: "Next Track"
                enabled: root.hasActiveTrack
                onTriggered: TrackModel.playNextTrack(AudioEngine.isShuffle)
            }

            Platform.MenuSeparator {}

            Platform.MenuItem {
                text: "Exit"
                onTriggered: Qt.quit()
            }
        }
    }



}

