import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import MusicPlayer.Core 1.0

FocusScope {
    id: discoverFocusScope
    anchors.fill: parent
    focus: true

    ColumnLayout {
        id: discoverRoot
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16


        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                id: searchBoxContainer
                Layout.fillWidth: true
                height: 44
                radius: 12
                color: "#120a21"
                border.color: searchInput.activeFocus ? "#ec4899" : "#251642"
                border.width: 1.2

                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 14
                    spacing: 12

                    Shape {
                        width: 16
                        height: 16
                        smooth: true
                        antialiasing: true

                        ShapePath {
                            strokeWidth: 1.8
                            strokeColor: searchInput.activeFocus ? "#ec4899" : "#8b5cf6"
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 11; startY: 6
                            PathArc { x: 1; y: 6; radiusX: 5; radiusY: 5; useLargeArc: false }
                            PathArc { x: 11; y: 6; radiusX: 5; radiusY: 5; useLargeArc: false }
                        }
                        ShapePath {
                            strokeWidth: 2.2
                            strokeColor: searchInput.activeFocus ? "#ec4899" : "#8b5cf6"
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 9.8; startY: 9.8
                            PathLine { x: 15; y: 15 }
                        }
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        placeholderText: "Search verified artists, official tracks or albums..."
                        placeholderTextColor: "#52525b"
                        color: "#f4f4f5"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        background: Item {}
                        selectByMouse: true

                        onAccepted: {
                            if (text.trim().length > 0) {
                                OnlineSearchEngine.searchOnline(text.trim())
                            }
                        }

                        Keys.onEscapePressed: function(event) {
                            searchInput.focus = false
                            discoverFocusScope.forceActiveFocus()
                            event.accepted = true
                        }
                    }

                    Text {
                        text: "✕"
                        color: clearMouse.hovered ? "#f472b6" : "#71717a"
                        font.pixelSize: 11
                        font.bold: true
                        visible: searchInput.text.length > 0
                        scale: clearMouse.hovered ? 1.1 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = ""
                                searchInput.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            Button {
                id: qualityBtn
                text: "HQ " + OnlineSearchEngine.audioQuality.toUpperCase()
                onClicked: qualityPopup.open()

                background: Rectangle {
                    implicitWidth: 100
                    implicitHeight: 44
                    radius: 12
                    color: qualityMa.hovered ? "#241347" : "#180d2e"
                    border.color: qualityPopup.opened ? "#ec4899" : "#7c3aed"
                    border.width: 1.2

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }

                contentItem: Text {
                    text: qualityBtn.text
                    color: "#d8b4fe"
                    font.bold: true
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                HoverHandler { id: qualityMa }

                Popup {
                    id: qualityPopup
                    y: qualityBtn.height + 8
                    x: -width + qualityBtn.width
                    width: 190
                    padding: 6
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                    background: Rectangle {
                        radius: 14
                        color: "#0f081d"
                        border.color: "#7c3aed"
                        border.width: 1.2
                    }

                    contentItem: ColumnLayout {
                        spacing: 4

                        component QualityOption: Rectangle {
                            id: qRoot
                            property string title: ""
                            property string qVal: ""
                            property bool isSelected: OnlineSearchEngine.audioQuality === qVal

                            Layout.fillWidth: true
                            height: 34
                            radius: 8
                            color: isSelected ? "#3b1130" : (qMouse.hovered ? "#1f1038" : "transparent")
                            border.color: isSelected ? "#ec4899" : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Text {
                                    Layout.fillWidth: true
                                    text: qRoot.title
                                    color: qRoot.isSelected ? "#f472b6" : (qMouse.hovered ? "#ffffff" : "#c084fc")
                                    font.pixelSize: 11
                                    font.bold: qRoot.isSelected
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: "✓"
                                    color: "#ec4899"
                                    font.pixelSize: 12
                                    font.bold: true
                                    visible: qRoot.isSelected
                                }
                            }

                            HoverHandler { id: qMouse }
                            TapHandler {
                                onTapped: {
                                    OnlineSearchEngine.audioQuality = qRoot.qVal
                                    qualityPopup.close()
                                }
                            }
                        }

                        QualityOption { title: "320 kbps (Studio HD)"; qVal: "320k" }
                        QualityOption { title: "256 kbps (High Quality)"; qVal: "256k" }
                        QualityOption { title: "128 kbps (Data Saver)"; qVal: "128k" }
                    }
                }
            }

            Button {
                id: searchActionBtn
                text: OnlineSearchEngine.isSearching ? "Searching..." : "Search"
                enabled: !OnlineSearchEngine.isSearching && searchInput.text.trim().length > 0
                opacity: enabled ? 1.0 : 0.55
                onClicked: OnlineSearchEngine.searchOnline(searchInput.text.trim())

                background: Rectangle {
                    implicitWidth: 105
                    implicitHeight: 44
                    radius: 12
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#7c3aed" }
                        GradientStop { position: 1.0; color: "#db2777" }
                    }
                }
                contentItem: Text {
                    text: searchActionBtn.text
                    color: "white"
                    font.bold: true
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }


        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: OnlineSearchEngine.chartTracks.length > 0 || OnlineSearchEngine.isLoadingCharts

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "🔥 Weekly Global Top Charts"
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 0.3
                }

                Rectangle {
                    width: 44
                    height: 18
                    radius: 9
                    color: "#3b1130"
                    border.color: "#ec4899"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "LIVE"
                        color: "#f472b6"
                        font.pixelSize: 9
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: OnlineSearchEngine.isLoadingCharts ? "Updating..." : "↻ Refresh"
                    color: refreshChartMa.containsMouse ? "#ffffff" : "#a78bfa"
                    font.pixelSize: 11
                    font.bold: true
                    enabled: !OnlineSearchEngine.isLoadingCharts

                    MouseArea {
                        id: refreshChartMa
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: OnlineSearchEngine.fetchTopCharts()
                    }
                }
            }

            Flickable {
                id: chartsFlickable
                Layout.fillWidth: true
                Layout.preferredHeight: 142
                contentWidth: chartsRow.implicitWidth + 10
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: chartsRow
                    spacing: 12
                    height: parent.height

                    Repeater {
                        model: OnlineSearchEngine.chartTracks
                        delegate: Rectangle {
                            id: chartCard
                            width: 235
                            height: 138
                            radius: 14
                            color: cardMa.containsMouse ? "#1c1033" : "#130b22"
                            border.color: cardMa.containsMouse ? "#ec4899" : "#241540"
                            border.width: 1.2

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 64
                                    Layout.preferredHeight: 64
                                    radius: 10
                                    color: "#1c1130"
                                    clip: true

                                    Image {
                                        id: chartImg
                                        anchors.fill: parent
                                        source: modelData.coverUrl ? modelData.coverUrl : ""
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: 128
                                        sourceSize.height: 128
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
                                        visible: !chartImg.visible
                                    }

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        width: 24
                                        height: 18
                                        radius: 5
                                        color: modelData.rank === 1 ? "#e11d48" : (modelData.rank <= 3 ? "#7c3aed" : "#0f081c")
                                        Text {
                                            anchors.centerIn: parent
                                            text: "#" + modelData.rank
                                            color: "#ffffff"
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 3

                                    Text {
                                        text: root.cleanTrackDisplay(modelData.title)
                                        color: "#ffffff"
                                        font.pixelSize: 12
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.artist
                                        color: "#c084fc"
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.playCount + " • " + modelData.duration
                                        color: "#71717a"
                                        font.pixelSize: 9
                                    }

                                    RowLayout {
                                        spacing: 8
                                        Layout.topMargin: 4

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: chartPlayMa.containsMouse ? "#db2777" : "#2a144f"
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Text {
                                                anchors.centerIn: parent
                                                anchors.horizontalCenterOffset: 1
                                                text: "▶"
                                                color: "white"
                                                font.pixelSize: 9
                                            }
                                            MouseArea {
                                                id: chartPlayMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.activeCover = modelData.coverUrl
                                                    OnlineSearchEngine.resolveAndPlay(modelData.title, modelData.artist, modelData.coverUrl)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: chartDlMa.containsMouse ? "#7c3aed" : "#1f1038"
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "↓"
                                                color: "white"
                                                font.pixelSize: 11
                                                font.bold: true
                                            }
                                            MouseArea {
                                                id: chartDlMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    OnlineSearchEngine.resolveAndDownload(modelData.title, modelData.artist, modelData.coverUrl)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            HoverHandler { id: cardMa }
                        }
                    }
                }
            }
        }


        Text {
            text: OnlineSearchEngine.statusText !== "" ? OnlineSearchEngine.statusText : "Search catalog results"
            color: "#a78bfa"
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 0.8
        }


        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: OnlineSearchEngine.isSearching

                BusyIndicator {
                    running: OnlineSearchEngine.isSearching
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Resolving high quality audio streams..."
                    color: "#a78bfa"
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: !OnlineSearchEngine.isSearching && onlineListView.count === 0 && searchInput.text.trim().length > 0 && OnlineSearchEngine.statusText === "No tracks found."

                Text {
                    text: "🔍"
                    font.pixelSize: 32
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "No tracks found for your search query"
                    color: "#94a3b8"
                    font.pixelSize: 13
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Try searching by artist name or track title without extra tags"
                    color: "#52525b"
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            ListView {
                id: onlineListView
                anchors.fill: parent
                clip: true
                model: OnlineSearchEngine
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds
                visible: !OnlineSearchEngine.isSearching

                ScrollBar.vertical: ScrollBar {
                    parent: onlineListView
                    anchors.right: onlineListView.right
                    anchors.top: onlineListView.top
                    anchors.bottom: onlineListView.bottom
                    anchors.rightMargin: 2
                    width: 5
                    policy: ScrollBar.AsNeeded
                }

                TapHandler {
                    onTapped: {
                        if (searchInput.activeFocus) {
                            searchInput.focus = false
                            discoverFocusScope.forceActiveFocus()
                        }
                    }
                }

                delegate: Rectangle {
                    id: onlineItem
                    width: onlineListView.width - 6
                    height: 64
                    radius: 14
                    color: onlineMouse.hovered ? "#1b0f30" : "#11081f"
                    border.color: onlineMouse.hovered ? "#ec4899" : "#1d1233"
                    border.width: 1.2

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            radius: 10
                            color: "#1c1130"
                            clip: true

                            Image {
                                id: searchResultCover
                                anchors.fill: parent
                                source: (model.coverUrl !== undefined && model.coverUrl !== "") ? model.coverUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 88
                                sourceSize.height: 88
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
                                visible: !searchResultCover.visible
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: root.cleanTrackDisplay(model.title)
                                color: "#ffffff"
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            RowLayout {
                                spacing: 6
                                Text {
                                    text: (model.artist && model.artist !== "Official Track") ? model.artist : ""
                                    color: "#c084fc"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    visible: (model.artist && model.artist !== "Official Track")
                                }
                                Text {
                                    text: "• " + (model.duration ? model.duration : "03:30")
                                    color: "#71717a"
                                    font.pixelSize: 10
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: playBadgeText.implicitWidth + 14
                            radius: 12
                            color: "#241047"
                            border.color: "#7c3aed"
                            border.width: 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: "▶"
                                    color: "#c084fc"
                                    font.pixelSize: 9
                                }

                                Text {
                                    id: playBadgeText
                                    text: model.playCount ? model.playCount : "Popular"
                                    color: "#f5d0fe"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }

                        Rectangle {
                            id: streamBtn
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 18
                            color: streamMa.containsMouse ? "#3b1130" : "#170c2b"
                            border.color: streamMa.containsMouse ? "#ec4899" : "#7c3aed"
                            border.width: 1.2

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Shape {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: 1.5
                                width: 14
                                height: 16
                                smooth: true
                                antialiasing: true

                                ShapePath {
                                    strokeWidth: 0
                                    fillColor: streamMa.containsMouse ? "#f472b6" : "#ec4899"
                                    startX: 1; startY: 1
                                    PathLine { x: 13; y: 8 }
                                    PathLine { x: 1; y: 15 }
                                    PathLine { x: 1; y: 1 }
                                }
                            }

                            MouseArea {
                                id: streamMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var cover = (model.coverUrl !== undefined && model.coverUrl !== "") ? model.coverUrl : ""
                                    root.activeCover = cover
                                    OnlineSearchEngine.resolveAndPlay(model.title, model.artist, cover)
                                }
                            }
                        }

                        Rectangle {
                            id: dlBtn
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 18
                            color: dlMa.containsMouse ? "#2e1065" : "#170c2b"
                            border.color: dlMa.containsMouse ? "#ec4899" : "#7c3aed"
                            border.width: 1.2

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Shape {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                smooth: true
                                antialiasing: true

                                ShapePath {
                                    strokeWidth: 1.8
                                    strokeColor: dlMa.containsMouse ? "#ffffff" : "#c084fc"
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    startX: 8; startY: 2
                                    PathLine { x: 8; y: 10.5 }
                                }

                                ShapePath {
                                    strokeWidth: 1.8
                                    strokeColor: dlMa.containsMouse ? "#ffffff" : "#c084fc"
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin
                                    startX: 4; startY: 7
                                    PathLine { x: 8; y: 11 }
                                    PathLine { x: 12; y: 7 }
                                }

                                ShapePath {
                                    strokeWidth: 1.8
                                    strokeColor: dlMa.containsMouse ? "#f472b6" : "#a78bfa"
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    startX: 3; startY: 14
                                    PathLine { x: 13; y: 14 }
                                }
                            }

                            MouseArea {
                                id: dlMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var cover = (model.coverUrl !== undefined && model.coverUrl !== "") ? model.coverUrl : ""
                                    OnlineSearchEngine.resolveAndDownload(model.title, model.artist, cover)
                                }
                            }
                        }
                    }

                    HoverHandler { id: onlineMouse }
                }
            }
        }
    }
}