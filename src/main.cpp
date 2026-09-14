#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QIcon>
#include <QDir>
#include <QStandardPaths>
#include <QFileInfo>
#include <QTimer>
#include <QLocalServer>
#include <QLocalSocket>
#include <QQuickWindow>

#ifdef Q_OS_WIN
#include <windows.h>
#include <cstdio>
#endif

#include "core/AudioEngine.h"
#include "core/TrackModel.h"
#include "core/SleepTimer.h"
#include "core/GlobalMediaKeyFilter.h"
#include "core/EqualizerModel.h"
#include "network/LyricsService.h"
#include "network/DownloadManager.h"
#include "network/OnlineSearchEngine.h"

int main(int argc, char *argv[]) {
#ifdef Q_OS_WIN

    if (AttachConsole(ATTACH_PARENT_PROCESS)) {
        freopen("CONOUT$", "w", stdout);
        freopen("CONOUT$", "w", stderr);
    }
#endif


    QQuickWindow::setGraphicsApi(QSGRendererInterface::Direct3D11);
    qputenv("QSG_RHI_BACKEND", "d3d11");
    qputenv("QT_D3D11_MULTITHREADED", "1");

    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
        Qt::HighDpiScaleFactorRoundingPolicy::PassThrough
    );

    QGuiApplication app(argc, argv);


    const QString serverName = "Aetheria_SingleInstance_Server";
    QLocalSocket socket;
    socket.connectToServer(serverName);

    if (socket.waitForConnected(500)) {
        QStringList args = app.arguments();
        if (args.size() > 1) {
            socket.write(args.at(1).toUtf8());
            socket.waitForBytesWritten(500);
        } else {
            socket.write("__ACTIVATE__");
            socket.waitForBytesWritten(500);
        }
        return 0;
    }

    auto *localServer = new QLocalServer(&app);
    QLocalServer::removeServer(serverName);
    localServer->listen(serverName);

#ifdef Q_OS_WIN
    HANDLE hMutex = CreateMutexW(NULL, TRUE, L"AetheriaSingleInstanceMutex");
#endif

    app.setOrganizationName("Aetheria");
    app.setOrganizationDomain("Aetheria.local");
    app.setApplicationName("Aetheria");
    app.setApplicationVersion("1.0.0");

    app.setQuitOnLastWindowClosed(true);
    app.setWindowIcon(QIcon(":/qt/qml/MusicPlayerApp/assets/app_icon.ico"));
    QQuickStyle::setStyle("Basic");

    auto *audioEngine = new AudioEngine(&app);
    auto *trackModel = new TrackModel(&app);
    auto *lyricsService = new LyricsService(&app);
    auto *sleepTimer = new SleepTimer(audioEngine, &app);
    auto *equalizerModel = new EqualizerModel(&app);
    auto *downloadManager = new DownloadManager(&app);
    auto *onlineSearchEngine = new OnlineSearchEngine(&app);

    audioEngine->setEqualizerModel(equalizerModel);

    auto *mediaKeyFilter = new GlobalMediaKeyFilter(&app);
    app.installNativeEventFilter(mediaKeyFilter);

    QObject::connect(mediaKeyFilter, &GlobalMediaKeyFilter::playPauseTriggered,
                     audioEngine, &AudioEngine::togglePlayPause);

    QObject::connect(mediaKeyFilter, &GlobalMediaKeyFilter::nextTriggered,
                     trackModel, [trackModel, audioEngine]() {
        trackModel->playNextTrack(audioEngine->isShuffle());
    });

    QObject::connect(mediaKeyFilter, &GlobalMediaKeyFilter::previousTriggered,
                     trackModel, &TrackModel::playPrevious);

    QObject::connect(audioEngine, &AudioEngine::positionChanged,
                     lyricsService, &LyricsService::updatePosition);

    QObject::connect(onlineSearchEngine, &OnlineSearchEngine::fullTrackResolved,
                     &app, [downloadManager, lyricsService](const QString &url, const QString &title, const QString &artist, const QString &, bool isDownload) {
        if (isDownload) {
            QString cleanArtist = artist.trimmed().isEmpty() ? "Unknown Artist" : artist.trimmed();
            QString cleanTitle = title.trimmed().isEmpty() ? "Track" : title.trimmed();
            QString fileName = QString("%1 - %2.mp3").arg(cleanArtist, cleanTitle);
            downloadManager->startDownload(url, fileName);
        } else {
            lyricsService->fetchLyrics(title, artist, url);
        }
    });

    qmlRegisterSingletonInstance<AudioEngine>("MusicPlayer.Core", 1, 0, "AudioEngine", audioEngine);
    qmlRegisterSingletonInstance<TrackModel>("MusicPlayer.Core", 1, 0, "TrackModel", trackModel);
    qmlRegisterSingletonInstance<LyricsService>("MusicPlayer.Core", 1, 0, "LyricsService", lyricsService);
    qmlRegisterSingletonInstance<SleepTimer>("MusicPlayer.Core", 1, 0, "SleepTimer", sleepTimer);
    qmlRegisterSingletonInstance<EqualizerModel>("MusicPlayer.Core", 1, 0, "EqualizerModel", equalizerModel);
    qmlRegisterSingletonInstance<DownloadManager>("MusicPlayer.Core", 1, 0, "DownloadManager", downloadManager);
    qmlRegisterSingletonInstance<OnlineSearchEngine>("MusicPlayer.Core", 1, 0, "OnlineSearchEngine", onlineSearchEngine);
    qmlRegisterSingletonInstance<GlobalMediaKeyFilter>("MusicPlayer.Core", 1, 0, "MediaKeys", mediaKeyFilter);

    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("equalizerModel", equalizerModel);
    engine.rootContext()->setContextProperty("audioEngine", audioEngine);
    engine.rootContext()->setContextProperty("trackModel", trackModel);
    engine.rootContext()->setContextProperty("lyricsService", lyricsService);
    engine.rootContext()->setContextProperty("sleepTimer", sleepTimer);
    engine.rootContext()->setContextProperty("downloadManager", downloadManager);
    engine.rootContext()->setContextProperty("onlineSearchEngine", onlineSearchEngine);
    engine.rootContext()->setContextProperty("mediaKeys", mediaKeyFilter);

    const QUrl url(QStringLiteral("qrc:/qt/qml/MusicPlayerApp/ui/qml/Main.qml"));

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) {
            QCoreApplication::exit(-1);
        }
    }, Qt::QueuedConnection);


    QObject::connect(localServer, &QLocalServer::newConnection, &app, [localServer, &engine, trackModel]() {
        QLocalSocket *clientSocket = localServer->nextPendingConnection();
        QObject::connect(clientSocket, &QLocalSocket::readyRead, [clientSocket, &engine, trackModel]() {
            QByteArray data = clientSocket->readAll();
            QString message = QString::fromUtf8(data).trimmed();

            if (!engine.rootObjects().isEmpty()) {
                if (auto *window = qobject_cast<QQuickWindow*>(engine.rootObjects().first())) {
                    window->show();
                    window->raise();
                    window->requestActivate();
                }
            }

            if (message != "__ACTIVATE__" && !message.isEmpty()) {
                QFileInfo fi(message);
                if (fi.exists() && fi.isFile()) {
                    trackModel->playExternalFile(message);
                }
            }
        });
    });

    engine.load(url);

#ifdef Q_OS_WIN

    if (!engine.rootObjects().isEmpty()) {
        if (auto *window = qobject_cast<QQuickWindow*>(engine.rootObjects().first())) {
            HWND hwnd = reinterpret_cast<HWND>(window->winId());
            LONG style = GetWindowLong(hwnd, GWL_STYLE);
            SetWindowLong(hwnd, GWL_STYLE, style | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_CAPTION);
            SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
        }
    }
#endif


    const QStringList args = app.arguments();
    if (args.size() > 1) {
        const QString initialFilePath = args.at(1);
        QFileInfo checkFile(initialFilePath);
        if (checkFile.exists() && checkFile.isFile()) {
            QTimer::singleShot(250, trackModel, [trackModel, initialFilePath]() {
                trackModel->playExternalFile(initialFilePath);
            });
        }
    }

    int execResult = app.exec();

#ifdef Q_OS_WIN
    if (hMutex) {
        CloseHandle(hMutex);
    }
#endif

    return execResult;
}