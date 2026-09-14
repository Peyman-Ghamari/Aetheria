import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import MusicPlayer.Core 1.0

Item {
    id: stageContainer
    anchors.fill: parent

    readonly property real baseCoverSize: Math.max(160, Math.min(320, Math.min(width * 0.42, height * 0.42)))

    Item {
        anchors.fill: parent
        visible: !root.hasActiveTrack
        opacity: !root.hasActiveTrack ? 1.0 : 0.0

        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }

        Image {
            anchors.centerIn: parent
            width: parent.width * 1.2
            height: parent.height * 1.2
            source: "qrc:/qt/qml/MusicPlayerApp/assets/idle_bg.png"
            fillMode: Image.PreserveAspectCrop
            opacity: 0.38
            smooth: true
            scale: 1.08

            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.90
                blurMax: 64
                saturation: 0.25
            }

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.24; duration: 3400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.45; duration: 3400; easing.type: Easing.InOutSine }
            }
        }

        Item {
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.88, 700)
            height: width * 0.5625

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.92
                height: parent.height * 0.92
                radius: 24
                color: "#ec4899"
                opacity: 0.14

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.8
                    blurMax: 48
                }
            }

            Image {
                id: mainHeroImg
                anchors.fill: parent
                source: "qrc:/qt/qml/MusicPlayerApp/assets/idle_bg.png"
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                antialiasing: true
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Math.max(10, Math.min(20, stageContainer.height * 0.025))
        visible: root.hasActiveTrack
        opacity: root.hasActiveTrack ? 1.0 : 0.0

        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }

        Item {
            id: coverArtWrapper
            Layout.preferredWidth: stageContainer.baseCoverSize * 1.22
            Layout.preferredHeight: stageContainer.baseCoverSize * 1.22
            Layout.alignment: Qt.AlignHCenter

            Image {
                id: ambientGlowImage
                anchors.centerIn: parent
                width: stageContainer.baseCoverSize * 1.12
                height: stageContainer.baseCoverSize * 1.12
                source: (root.activeCover !== "" && root.activeCover !== undefined)
                    ? root.activeCover
                    : "qrc:/qt/qml/MusicPlayerApp/assets/logo1.png"
                fillMode: Image.PreserveAspectCrop
                opacity: AudioEngine.isPlaying ? 0.45 : 0.18
                scale: AudioEngine.isPlaying ? 1.08 : 1.0
                sourceSize.width: 320
                sourceSize.height: 320

                Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                Behavior on opacity { NumberAnimation { duration: 400 } }
            }

            Rectangle {
                id: rgbHaloRing
                anchors.centerIn: parent
                width: stageContainer.baseCoverSize * 1.05
                height: stageContainer.baseCoverSize * 1.05
                radius: width * 0.14
                color: "transparent"
                border.width: 2.5
                border.color: "#ec4899"
                opacity: AudioEngine.isPlaying ? 0.9 : 0.3

                SequentialAnimation on border.color {
                    running: AudioEngine.isPlaying
                    loops: Animation.Infinite
                    ColorAnimation { to: "#8b5cf6"; duration: 2500 }
                    ColorAnimation { to: "#06b6d4"; duration: 2500 }
                    ColorAnimation { to: "#ec4899"; duration: 2500 }
                }

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 9000
                    loops: Animation.Infinite
                    running: AudioEngine.isPlaying
                }
            }

            Rectangle {
                id: coverArt
                anchors.centerIn: parent
                width: stageContainer.baseCoverSize
                height: stageContainer.baseCoverSize
                radius: stageCoverImg.visible ? 28 : (width * 0.22)
                clip: true
                color: "transparent"

                Image {
                    id: stageCoverImg
                    anchors.fill: parent
                    source: root.activeCover !== "" ? root.activeCover : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 520
                    sourceSize.height: 520
                    asynchronous: true
                    cache: true
                    visible: root.activeCover !== "" && status === Image.Ready
                }

                Image {
                    anchors.fill: parent
                    source: "qrc:/qt/qml/MusicPlayerApp/assets/logo1.png"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 512
                    sourceSize.height: 512
                    smooth: true
                    mipmap: true
                    visible: !stageCoverImg.visible
                    opacity: AudioEngine.isPlaying ? 1.0 : 0.88

                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }
        }

        ColumnLayout {
            spacing: 6
            Layout.alignment: Qt.AlignHCenter

            Text {
                text: root.activeTitle !== "No Active Stream" ? root.activeTitle : root.cleanTrackDisplay(AudioEngine.currentSource)
                color: "#ffffff"
                font.pixelSize: Math.max(15, Math.min(22, stageContainer.width * 0.028))
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                elide: Text.ElideMiddle
                Layout.maximumWidth: Math.min(500, stageContainer.width * 0.85)
            }

            Text {
                text: root.activeArtist !== "Idle" ? root.activeArtist : "Local Audio Master"
                color: "#c084fc"
                font.pixelSize: Math.max(11, Math.min(14, stageContainer.width * 0.018))
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Item {
                id: beatVisualizerBox
                Layout.preferredWidth: Math.min(360, stageContainer.width * 0.75)
                Layout.preferredHeight: 46
                Layout.topMargin: 8
                Layout.alignment: Qt.AlignHCenter
                visible: root.hasActiveTrack

                readonly property real t: AudioEngine.position * 0.006
                readonly property real wave1: AudioEngine.isPlaying ? Math.sin(t * 0.7) : 0.0
                readonly property real wave2: AudioEngine.isPlaying ? Math.cos(t * 1.3) : 0.0
                readonly property real wave3: AudioEngine.isPlaying ? Math.sin(t * 2.1) : 0.0
                readonly property real wave4: AudioEngine.isPlaying ? Math.cos(t * 0.4) : 0.0

                property color currentRgbColor: "#ec4899"

                SequentialAnimation on currentRgbColor {
                    running: AudioEngine.isPlaying
                    loops: Animation.Infinite
                    ColorAnimation { to: "#8b5cf6"; duration: 2500 }
                    ColorAnimation { to: "#06b6d4"; duration: 2500 }
                    ColorAnimation { to: "#ec4899"; duration: 2500 }
                }

                Shape {
                    anchors.fill: parent
                    opacity: AudioEngine.isPlaying ? (0.22 + Math.abs(beatVisualizerBox.wave1) * 0.25) : 0.06
                    smooth: true
                    antialiasing: true

                    ShapePath {
                        strokeWidth: 6
                        strokeColor: beatVisualizerBox.currentRgbColor
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        startX: 0; startY: 23
                        PathLine { x: beatVisualizerBox.width * 0.11; y: 23 }
                        PathLine { x: beatVisualizerBox.width * 0.16; y: 23 - (beatVisualizerBox.wave2 * 5) }
                        PathLine { x: beatVisualizerBox.width * 0.20; y: 23 + (beatVisualizerBox.wave3 * 6) }
                        PathLine { x: beatVisualizerBox.width * 0.25; y: 23 }
                        PathLine { x: beatVisualizerBox.width * 0.30; y: 23 - (beatVisualizerBox.wave1 * 8) }
                        PathLine { x: beatVisualizerBox.width * 0.34; y: 23 + (beatVisualizerBox.wave2 * 7) }
                        PathLine { x: beatVisualizerBox.width * 0.38; y: 23 }
                        PathLine { x: beatVisualizerBox.width * 0.44; y: 23 - (11 + Math.abs(beatVisualizerBox.wave1) * 10 + beatVisualizerBox.wave3 * 4) }
                        PathLine { x: beatVisualizerBox.width * 0.48; y: 23 + (9 + Math.abs(beatVisualizerBox.wave2) * 9) }
                        PathLine { x: beatVisualizerBox.width * 0.52; y: 23 - (beatVisualizerBox.wave3 * 10) }
                        PathLine { x: beatVisualizerBox.width * 0.56; y: 23 }
                        PathLine { x: beatVisualizerBox.width * 0.62; y: 23 + (beatVisualizerBox.wave4 * 12) }
                        PathLine { x: beatVisualizerBox.width * 0.66; y: 23 - (beatVisualizerBox.wave1 * 13) }
                        PathLine { x: beatVisualizerBox.width * 0.70; y: 23 + (beatVisualizerBox.wave2 * 8) }
                        PathLine { x: beatVisualizerBox.width * 0.75; y: 23 }
                        PathLine { x: beatVisualizerBox.width * 0.81; y: 23 - (beatVisualizerBox.wave3 * 6) }
                        PathLine { x: beatVisualizerBox.width * 0.87; y: 23 + (beatVisualizerBox.wave1 * 5) }
                        PathLine { x: beatVisualizerBox.width * 0.93; y: 23 }
                        PathLine { x: beatVisualizerBox.width; y: 23 }
                    }
                }

                Shape {
                    anchors.fill: parent
                    smooth: true
                    antialiasing: true

                    ShapePath {
                        strokeWidth: 2.2
                        strokeColor: beatVisualizerBox.currentRgbColor
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        startX: 0; startY: 23
                        PathLine { x: beatVisualizerBox.width * 0.11; y: 23 }
                        PathLine { x: beatVisualizerBox.width * 0.16; y: 23 - (beatVisualizerBox.wave2 * 5) }
                        PathLine { x: beatVisualizerBox.width * 0.20; y: 23 + (beatVisualizerBox.wave3 * 6) }
                        PathLine { x: beatVisualizerBox.width * 0.25; y: 23 }
                        PathLine { x: beatVisualizerBox.width * 0.30; y: 23 - (beatVisualizerBox.wave1 * 8) }
                        PathLine { x: beatVisualizerBox.width * 0.34; y: 23 + (beatVisualizerBox.wave2 * 7) }
                        PathLine { x: beatVisualizerBox.width * 0.38; y: 23 }
                        PathLine { x: beatVisualizerBox.width * 0.44; y: 23 - (11 + Math.abs(beatVisualizerBox.wave1) * 10 + beatVisualizerBox.wave3 * 4) }
                        PathLine { x: beatVisualizerBox.width * 0.48; y: 23 + (9 + Math.abs(beatVisualizerBox.wave2) * 9) }
                        PathLine { x: beatVisualizerBox.width * 0.52; y: 23 - (beatVisualizerBox.wave3 * 10) }
                        PathLine { x: beatVisualizerBox.width * 0.56; y: 23 }
                        PathLine { x: beatVisualizerBox.width * 0.62; y: 23 + (beatVisualizerBox.wave4 * 12) }
                        PathLine { x: beatVisualizerBox.width * 0.66; y: 23 - (beatVisualizerBox.wave1 * 13) }
                        PathLine { x: beatVisualizerBox.width * 0.70; y: 23 + (beatVisualizerBox.wave2 * 8) }
                        PathLine { x: beatVisualizerBox.width * 0.75; y: 23 }
                        PathLine { x: beatVisualizerBox.width * 0.81; y: 23 - (beatVisualizerBox.wave3 * 6) }
                        PathLine { x: beatVisualizerBox.width * 0.87; y: 23 + (beatVisualizerBox.wave1 * 5) }
                        PathLine { x: beatVisualizerBox.width * 0.93; y: 23 }
                        PathLine { x: beatVisualizerBox.width; y: 23 }
                    }
                }
            }
        }
    }
}