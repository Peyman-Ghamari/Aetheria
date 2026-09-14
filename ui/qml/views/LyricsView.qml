import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MusicPlayer.Core 1.0

ColumnLayout {
    id: lyricsRoot
    anchors.fill: parent
    anchors.margins: 24
    spacing: 14

    property bool userScrolling: false
    Timer {
        id: userScrollTimer
        interval: 3500
        repeat: false
        onTriggered: lyricsRoot.userScrolling = false
    }

    Text {
        text: LyricsService.isLoading ? "Fetching Lyrics..." : (LyricsService.hasSyncedLyrics ? "SYNCED LYRICS" : "PLAIN LYRICS")
        color: "#ec4899"
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 2
        Layout.alignment: Qt.AlignHCenter
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: LyricsService.isLoading

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            BusyIndicator {
                running: LyricsService.isLoading
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Searching synchronized lyrics..."
                color: "#a78bfa"
                font.pixelSize: 13
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    ListView {
        id: lyricsListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 20
        visible: !LyricsService.isLoading && LyricsService.hasSyncedLyrics
        model: LyricsService.linesCount
        boundsBehavior: Flickable.StopAtBounds

        topMargin: height / 2 - 40
        bottomMargin: height / 2 - 40

        onMovementStarted: {
            lyricsRoot.userScrolling = true
            userScrollTimer.stop()
        }
        onMovementEnded: {
            userScrollTimer.restart()
        }

        function smoothScrollToIndex(idx) {
            if (lyricsRoot.userScrolling || idx < 0 || idx >= count) return

            var itemY = 0
            var targetContentY = idx * 64 - (height / 2) + 32
            var minContentY = -topMargin
            var maxContentY = contentHeight - height + bottomMargin

            targetContentY = Math.max(minContentY, Math.min(targetContentY, maxContentY))

            scrollAnimation.stop()
            scrollAnimation.to = targetContentY
            scrollAnimation.start()
        }

        NumberAnimation {
            id: scrollAnimation
            target: lyricsListView
            property: "contentY"
            duration: 400
            easing.type: Easing.OutCubic
        }

        delegate: Rectangle {
            id: lyricItemDelegate
            required property int index
            width: lyricsListView.width
            height: lyricText.implicitHeight + 24
            radius: 12
            color: lyricMouseArea.containsMouse && !isCurrentLine ? "#180d2b" : "transparent"

            readonly property bool isCurrentLine: LyricsService.currentLineIndex === lyricItemDelegate.index

            Behavior on color { ColorAnimation { duration: 180 } }

            Text {
                id: lyricText
                anchors.centerIn: parent
                width: parent.width - 60
                text: LyricsService.getLineText(lyricItemDelegate.index)
                color: lyricItemDelegate.isCurrentLine
                    ? "#f472b6"
                    : (lyricMouseArea.containsMouse ? "#ffffff" : "#6b5b95")
                font.pixelSize: lyricItemDelegate.isCurrentLine ? 23 : 16
                font.bold: lyricItemDelegate.isCurrentLine
                font.weight: lyricItemDelegate.isCurrentLine ? Font.Black : Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: lyricItemDelegate.isCurrentLine
                    ? 1.0
                    : (lyricMouseArea.containsMouse ? 0.85 : 0.30)
                scale: lyricItemDelegate.isCurrentLine
                    ? 1.08
                    : (lyricMouseArea.pressed ? 0.98 : (lyricMouseArea.containsMouse ? 1.02 : 0.96))

                Behavior on color { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                Behavior on font.pixelSize { NumberAnimation { duration: 200 } }
            }

            MouseArea {
                id: lyricMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    lyricsRoot.userScrolling = false
                    var targetTimeMs = LyricsService.getLineTime(lyricItemDelegate.index)

                    console.log("[Lyrics Seek] Target:", targetTimeMs, "Duration:", AudioEngine.duration)

                    if (targetTimeMs >= 0) {
                        if (AudioEngine.duration > 0 && targetTimeMs >= AudioEngine.duration) {
                            targetTimeMs = Math.max(0, AudioEngine.duration - 500)
                        }

                        AudioEngine.setPosition(targetTimeMs)
                        AudioEngine.play()
                    }
                }
            }
        }

        Connections {
            target: LyricsService
            function onHasSyncedLyricsChanged(synced) {
                if (synced) {
                    lyricsListView.model = 0
                    lyricsListView.model = LyricsService.linesCount
                }
            }
            function onCurrentLineIndexChanged(idx) {
                if (idx >= 0 && root.activeCenterTab === "lyrics" && LyricsService.hasSyncedLyrics) {
                    lyricsListView.smoothScrollToIndex(idx)
                }
            }
        }
    }

    ScrollView {
        id: plainLyricsScroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        visible: !LyricsService.isLoading && !LyricsService.hasSyncedLyrics
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Text {
            width: plainLyricsScroll.availableWidth > 0 ? plainLyricsScroll.availableWidth : plainLyricsScroll.width
            text: LyricsService.rawLyrics !== "" ? LyricsService.rawLyrics : "No lyrics available for this track."
            color: "#e2e8f0"
            font.pixelSize: 16
            lineHeight: 1.7
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            topPadding: 10
            bottomPadding: 30
        }
    }
}