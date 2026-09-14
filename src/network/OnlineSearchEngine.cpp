#include "OnlineSearchEngine.h"
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QProcess>
#include <QCoreApplication>
#include <QDir>
#include <QSslConfiguration>
#include <QSslSocket>
#include <QRegularExpression>
#include <QDebug>
#include <QFileInfo>
#include <QThread>

static const QString BROWSER_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";
static const QString QOBUZ_APP_ID = "712108740";

static QString formatRankToPlays(qint64 rank, qint64 trackId) {
    quint32 seed = static_cast<quint32>(trackId ^ (rank * 2654435761ULL));
    double variance = 0.88 + ((seed % 250) / 1000.0);

    double plays = 0.0;

    if (rank >= 800000) {
        plays = (120000000.0 + (rank - 800000) * 4500.0) * variance;
    } else if (rank >= 500000) {
        plays = (12000000.0 + (rank - 500000) * 360.0) * variance;
    } else if (rank >= 200000) {
        plays = (1500000.0 + (rank - 200000) * 35.0) * variance;
    } else if (rank > 0) {
        plays = (220000.0 + (rank * 6.5)) * variance;
    } else {
        plays = (180000.0 + (seed % 650000)) * variance;
    }

    if (plays >= 1000000000.0) {
        return QString::number(plays / 1000000000.0, 'f', 1) + "B Plays";
    } else if (plays >= 1000000.0) {
        return QString::number(plays / 1000000.0, 'f', 1) + "M Plays";
    } else if (plays >= 1000.0) {
        return QString::number(plays / 1000.0, 'f', 0) + "K Plays";
    }
    return QString::number(static_cast<qint64>(plays)) + " Plays";
}

void OnlineSearchEngine::abortActiveResolution() {
    if (m_activeResolveReply) {
        m_activeResolveReply->disconnect();
        m_activeResolveReply->abort();
        m_activeResolveReply->deleteLater();
        m_activeResolveReply = nullptr;
    }

    if (m_activeYtProcess) {
        m_activeYtProcess->disconnect();
        if (m_activeYtProcess->state() != QProcess::NotRunning) {
            m_activeYtProcess->kill();
            m_activeYtProcess->waitForFinished(30);
        }
        m_activeYtProcess->deleteLater();
        m_activeYtProcess = nullptr;
    }
}

void OnlineSearchEngine::registerActiveProcess(QProcess *proc) {
    if (m_activeYtProcess && m_activeYtProcess != proc) {
        m_activeYtProcess->disconnect();
        if (m_activeYtProcess->state() != QProcess::NotRunning) {
            m_activeYtProcess->kill();
        }
        m_activeYtProcess->deleteLater();
    }
    m_activeYtProcess = proc;
}

void OnlineSearchEngine::registerActiveReply(QNetworkReply *reply) {
    if (m_activeResolveReply && m_activeResolveReply != reply) {
        m_activeResolveReply->disconnect();
        m_activeResolveReply->abort();
        m_activeResolveReply->deleteLater();
    }
    m_activeResolveReply = reply;
}

static void runFallbackYtDlp(OnlineSearchEngine *engine, quint64 token, const QString &title, const QString &artist, const QString &coverUrl, bool isDownload) {
    if (!engine || token != engine->activePlaybackToken()) return;

    QString appDir = QCoreApplication::applicationDirPath();
    QString ytDlpPath = QDir(appDir).filePath("yt-dlp.exe");
    if (!QFile::exists(ytDlpPath)) {
        ytDlpPath = "yt-dlp";
    }

    auto *process = new QProcess(engine);
    engine->registerActiveProcess(process);

    QString scQuery = QString("scsearch1:%1 %2").arg(title, artist);
    QStringList scArgs;
    scArgs << "-g"
           << "-f" << "bestaudio/best"
           << "--match-filter" << "duration > 60 & !is_live"
           << "--no-warnings"
           << scQuery;

    QObject::connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), engine, [engine, token, process, title, artist, coverUrl, isDownload, ytDlpPath](int exitCode, QProcess::ExitStatus) {
        if (!engine || token != engine->activePlaybackToken()) {
            if (process) process->deleteLater();
            return;
        }

        if (exitCode == 0) {
            QString directStreamUrl = QString::fromUtf8(process->readAllStandardOutput()).trimmed().split('\n').first();
            if (!directStreamUrl.isEmpty() && directStreamUrl.startsWith("http") && !directStreamUrl.contains("preview") && !directStreamUrl.contains("snippet")) {
                qDebug() << "[OnlineEngine] Full Track Acquired via SoundCloud CDN:" << directStreamUrl;
                emit engine->fullTrackResolved(directStreamUrl, title, artist, coverUrl, isDownload);
                process->deleteLater();
                return;
            }
        }

        process->deleteLater();

        if (!engine || token != engine->activePlaybackToken()) return;

        auto *ytProcess = new QProcess(engine);
        engine->registerActiveProcess(ytProcess);

        QString ytQuery = QString("ytsearch1:%1 %2 full audio").arg(title, artist);
        QStringList ytArgs;
        ytArgs << "-g"
               << "-f" << "bestaudio[ext=m4a]/bestaudio/best"
               << "--match-filter" << "duration > 60 & !is_live"
               << "--extractor-args" << "youtube:player_client=mweb,android;player_skip=configs"
               << "--no-check-certificates"
               << "--force-ipv4"
               << "--no-warnings"
               << ytQuery;

        QObject::connect(ytProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), engine, [engine, token, ytProcess, title, artist, coverUrl, isDownload](int ytExit, QProcess::ExitStatus) {
            if (engine && token == engine->activePlaybackToken()) {
                if (ytExit == 0) {
                    QString ytUrl = QString::fromUtf8(ytProcess->readAllStandardOutput()).trimmed().split('\n').first();
                    if (!ytUrl.isEmpty() && ytUrl.startsWith("http")) {
                        qDebug() << "[OnlineEngine] Full Track Acquired via YouTube Engine:" << ytUrl;
                        emit engine->fullTrackResolved(ytUrl, title, artist, coverUrl, isDownload);
                    }
                } else {
                    qWarning() << "[OnlineEngine] Final Fallback resolution error:" << ytProcess->readAllStandardError();
                }
            }
            if (ytProcess) ytProcess->deleteLater();
        });

        ytProcess->start(ytDlpPath, ytArgs);
        ytProcess->closeWriteChannel();

    });

    process->start(ytDlpPath, scArgs);
    process->closeWriteChannel();
}

static void fetchPersianDirectWeb(OnlineSearchEngine *engine, quint64 token, QNetworkAccessManager *netManager, const QString &title, const QString &artist, const QString &coverUrl, bool isDownload) {
    if (token != engine->activePlaybackToken()) return;

    QUrl ddgUrl("https://html.duckduckgo.com/html/");
    QUrlQuery q;
    q.addQueryItem("q", QString("دانلود آهنگ %1 %2 320").arg(title, artist));
    ddgUrl.setQuery(q);

    QNetworkRequest req(ddgUrl);
    req.setHeader(QNetworkRequest::UserAgentHeader, BROWSER_USER_AGENT);

    QNetworkReply *ddgReply = netManager->get(req);
    engine->registerActiveReply(ddgReply);

    QObject::connect(ddgReply, &QNetworkReply::finished, engine, [engine, token, netManager, ddgReply, title, artist, coverUrl, isDownload]() {
        if (token != engine->activePlaybackToken()) {
            ddgReply->deleteLater();
            return;
        }

        QString targetPage = "";

        if (ddgReply->error() == QNetworkReply::NoError) {
            QString html = QString::fromUtf8(ddgReply->readAll());
            static const QRegularExpression linkRx("class=\"result__url\"[^>]*href=\"([^\"]+)\"", QRegularExpression::CaseInsensitiveOption);
            QRegularExpressionMatchIterator it = linkRx.globalMatch(html);

            while (it.hasNext()) {
                QString link = it.next().captured(1);
                if (link.contains("uddg=")) {
                    link = QUrl::fromPercentEncoding(link.section("uddg=", 1, 1).section("&", 0, 0).toUtf8());
                }

                if (link.contains("musicfa") || link.contains("golsarmusic") ||
                    link.contains("upmusics") || link.contains("taktaraneh") ||
                    link.contains("nex1music") || link.contains("music-del")) {
                    targetPage = link;
                    break;
                }
            }
        }
        ddgReply->deleteLater();

        if (!targetPage.isEmpty()) {
            QNetworkRequest pageReq((QUrl(targetPage)));
            pageReq.setHeader(QNetworkRequest::UserAgentHeader, BROWSER_USER_AGENT);

            QNetworkReply *pageReply = netManager->get(pageReq);
            engine->registerActiveReply(pageReply);

            QObject::connect(pageReply, &QNetworkReply::finished, engine, [engine, token, pageReply, title, artist, coverUrl, isDownload]() {
                if (token != engine->activePlaybackToken()) {
                    pageReply->deleteLater();
                    return;
                }

                QString directMp3 = "";

                if (pageReply->error() == QNetworkReply::NoError) {
                    QString html = QString::fromUtf8(pageReply->readAll());
                    static const QRegularExpression mp3Rx("href=\"(https?://[^\"]+\\.mp3)\"", QRegularExpression::CaseInsensitiveOption);
                    QRegularExpressionMatchIterator it = mp3Rx.globalMatch(html);

                    QString best320 = "";
                    QString firstMp3 = "";

                    while (it.hasNext()) {
                        QString url = it.next().captured(1);
                        if (firstMp3.isEmpty()) firstMp3 = url;
                        if (url.contains("320")) {
                            best320 = url;
                            break;
                        }
                    }

                    directMp3 = !best320.isEmpty() ? best320 : firstMp3;
                }
                pageReply->deleteLater();

                if (!directMp3.isEmpty()) {
                    qDebug() << "[OnlineEngine] Direct MP3 Acquired from Web CDN:" << directMp3;
                    emit engine->fullTrackResolved(directMp3, title, artist, coverUrl, isDownload);
                    return;
                }

                runFallbackYtDlp(engine, token, title, artist, coverUrl, isDownload);
            });
            return;
        }

        runFallbackYtDlp(engine, token, title, artist, coverUrl, isDownload);
    });
}

OnlineSearchEngine::OnlineSearchEngine(QObject *parent)
    : QAbstractListModel(parent)
    , m_networkManager(new QNetworkAccessManager(this)) {
    checkForYtDlpUpdate();
    fetchTopCharts();
}

OnlineSearchEngine::~OnlineSearchEngine() {
    abortActiveResolution();
}

QVariantList OnlineSearchEngine::chartTracks() const {
    return m_chartTracks;
}

bool OnlineSearchEngine::isLoadingCharts() const {
    return m_isLoadingCharts;
}

void OnlineSearchEngine::fetchTopCharts() {
    m_isLoadingCharts = true;
    emit loadingChartsChanged(true);

    QUrl url("https://itunes.apple.com/us/rss/topsongs/limit=15/json");
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, BROWSER_USER_AGENT);

    QSslConfiguration sslConf = req.sslConfiguration();
    sslConf.setPeerVerifyMode(QSslSocket::VerifyNone);
    req.setSslConfiguration(sslConf);

    QNetworkReply *reply = m_networkManager->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            QJsonObject root = QJsonDocument::fromJson(data).object();
            QJsonObject feed = root.value("feed").toObject();
            QJsonArray entries = feed.value("entry").toArray();

            if (!entries.isEmpty()) {
                m_chartTracks.clear();
                int rankIdx = 1;
                for (const auto &item : entries) {
                    QJsonObject tObj = item.toObject();
                    QVariantMap map;
                    map["rank"] = rankIdx++;

                    QString title = tObj.value("im:name").toObject().value("label").toString();
                    QString artist = tObj.value("im:artist").toObject().value("label").toString();
                    map["title"] = title;
                    map["artist"] = artist;

                    QString cover = "";
                    QJsonArray images = tObj.value("im:image").toArray();
                    if (!images.isEmpty()) {
                        cover = images.last().toObject().value("label").toString();
                        cover.replace("170x170bb", "600x600bb");
                        cover.replace("100x100bb", "600x600bb");
                    }

                    map["coverUrl"] = cover;
                    map["cover"] = cover;
                    map["coverPath"] = cover;
                    map["duration"] = "03:30";

                    qint64 dummyId = rankIdx * 1024;
                    qint64 rank = 950000 - (rankIdx * 12000);
                    map["playCount"] = formatRankToPlays(rank, dummyId);

                    m_chartTracks.append(map);
                }
                emit chartTracksChanged();
            }
        } else {
            qWarning() << "[OnlineEngine] Top chart fetch error:" << reply->errorString();
        }
        reply->deleteLater();
        m_isLoadingCharts = false;
        emit loadingChartsChanged(false);
    });
}

void OnlineSearchEngine::checkForYtDlpUpdate() {
    auto *thread = QThread::create([this]() {
        this->performYtDlpUpdate();
    });
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}

void OnlineSearchEngine::performYtDlpUpdate() {
    if (m_isUpdatingYtDlp.exchange(true)) return;

    qDebug() << "[OnlineEngine] Checking and updating yt-dlp binary...";

    QString appDir = QCoreApplication::applicationDirPath();
    QString ytDlpPath = QDir(appDir).filePath("yt-dlp.exe");
    if (!QFile::exists(ytDlpPath)) {
        ytDlpPath = "yt-dlp";
    }

    QProcess process;
    process.setProgram(ytDlpPath);
    process.setArguments(QStringList() << "-U");
    process.start();

    if (process.waitForFinished(30000)) {
        QString output = QString::fromUtf8(process.readAllStandardOutput());
        QString err = QString::fromUtf8(process.readAllStandardError());
        qDebug() << "[OnlineEngine] yt-dlp update status:" << output.trimmed();
        if (!err.trimmed().isEmpty()) {
            qDebug() << "[OnlineEngine] yt-dlp update notice:" << err.trimmed();
        }
    } else {
        qDebug() << "[OnlineEngine] yt-dlp update check timed out or finished.";
        process.kill();
    }

    m_isUpdatingYtDlp = false;
}

int OnlineSearchEngine::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(m_results.size());
}

QVariant OnlineSearchEngine::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_results.size())
        return QVariant();

    const OnlineTrack &track = m_results.at(index.row());
    switch (role) {
    case TitleRole: return track.title;
    case ArtistRole: return track.artist;
    case StreamUrlRole: return track.streamUrl;
    case CoverUrlRole: return track.coverUrl;
    case DurationRole: return track.duration;
    case PlayCountRole: return track.playCount;
    default: return QVariant();
    }
}

QHash<int, QByteArray> OnlineSearchEngine::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[TitleRole] = "title";
    roles[ArtistRole] = "artist";
    roles[StreamUrlRole] = "streamUrl";
    roles[CoverUrlRole] = "coverUrl";
    roles[CoverUrlRole + 100] = "cover";
    roles[DurationRole] = "duration";
    roles[PlayCountRole] = "playCount";
    return roles;
}

bool OnlineSearchEngine::isSearching() const { return m_isSearching; }
QString OnlineSearchEngine::statusText() const { return m_statusText; }
QString OnlineSearchEngine::audioQuality() const { return m_audioQuality; }

void OnlineSearchEngine::setAudioQuality(const QString &quality) {
    if (m_audioQuality != quality) {
        m_audioQuality = quality;
        emit audioQualityChanged(m_audioQuality);
    }
}

void OnlineSearchEngine::clear() {
    beginResetModel();
    m_results.clear();
    m_results.squeeze();
    endResetModel();
}

void OnlineSearchEngine::searchOnline(const QString &query) {
    QString trimmed = query.trimmed();
    if (trimmed.isEmpty()) return;

    if (m_currentReply) {
        m_currentReply->abort();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }

    clear();
    m_isSearching = true;
    m_statusText = "Searching master catalog...";
    emit searchingChanged(true);
    emit statusTextChanged(m_statusText);

    QUrl url("https://itunes.apple.com/search");
    QUrlQuery q;
    q.addQueryItem("term", trimmed);
    q.addQueryItem("media", "music");
    q.addQueryItem("entity", "song");
    q.addQueryItem("limit", "40");
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, BROWSER_USER_AGENT);
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);

    QSslConfiguration sslConf = req.sslConfiguration();
    sslConf.setPeerVerifyMode(QSslSocket::VerifyNone);
    req.setSslConfiguration(sslConf);

    m_currentReply = m_networkManager->get(req);
    connect(m_currentReply, &QNetworkReply::finished, this, [this, trimmed]() {
        if (!m_currentReply) return;

        bool itunesFound = false;

        if (m_currentReply->error() == QNetworkReply::NoError) {
            QByteArray data = m_currentReply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            QJsonArray resultsArr = doc.object().value("results").toArray();

            if (!resultsArr.isEmpty()) {
                beginResetModel();
                for (const auto &item : resultsArr) {
                    QJsonObject track = item.toObject();

                    OnlineTrack t;
                    t.title = track.value("trackName").toString().trimmed();
                    t.artist = track.value("artistName").toString().trimmed();

                    QString cover = track.value("artworkUrl100").toString();
                    cover.replace("100x100bb", "600x600bb");
                    t.coverUrl = cover;

                    int durMs = track.value("trackTimeMillis").toInt();
                    int durSec = durMs / 1000;
                    if (durSec > 0) {
                        t.duration = QString("%1:%2").arg(durSec / 60, 2, 10, QChar('0')).arg(durSec % 60, 2, 10, QChar('0'));
                    } else {
                        t.duration = "03:30";
                    }

                    qint64 trackId = track.value("trackId").toVariant().toLongLong();
                    qint64 rank = 500000 + (trackId % 400000);
                    t.playCount = formatRankToPlays(rank, trackId);
                    t.streamUrl = "";

                    if (!t.title.isEmpty() && !t.artist.isEmpty()) {
                        m_results.append(t);
                    }
                }
                endResetModel();
                itunesFound = !m_results.isEmpty();
            }
        }

        m_currentReply->deleteLater();
        m_currentReply = nullptr;

        if (itunesFound) {
            m_isSearching = false;
            m_statusText = QString("Discovered %1 studio tracks.").arg(m_results.size());
            emit searchingChanged(false);
            emit statusTextChanged(m_statusText);
        } else {
            QUrl qobuzUrl("https://www.qobuz.com/api.json/0.2/catalog/search");
            QUrlQuery qq;
            qq.addQueryItem("query", trimmed);
            qq.addQueryItem("type", "tracks");
            qq.addQueryItem("limit", "40");
            qq.addQueryItem("app_id", QOBUZ_APP_ID);
            qobuzUrl.setQuery(qq);

            QNetworkRequest qreq(qobuzUrl);
            qreq.setHeader(QNetworkRequest::UserAgentHeader, BROWSER_USER_AGENT);

            m_currentReply = m_networkManager->get(qreq);
            connect(m_currentReply, &QNetworkReply::finished, this, &OnlineSearchEngine::onSearchResultsReceived);
        }
    });
}

void OnlineSearchEngine::onSearchResultsReceived() {
    m_isSearching = false;
    emit searchingChanged(false);

    if (!m_currentReply) return;

    if (m_currentReply->error() == QNetworkReply::NoError) {
        QByteArray data = m_currentReply->readAll();
        QJsonObject root = QJsonDocument::fromJson(data).object();
        QJsonArray tracks = root.value("tracks").toObject().value("items").toArray();

        beginResetModel();
        for (const auto &item : tracks) {
            QJsonObject track = item.toObject();

            OnlineTrack t;
            t.title = track.value("title").toString().trimmed();
            t.artist = track.value("performer").toObject().value("name").toString().trimmed();

            t.coverUrl = track.value("album").toObject().value("image").toObject().value("large").toString();
            if (t.coverUrl.isEmpty()) {
                t.coverUrl = track.value("album").toObject().value("image").toObject().value("small").toString();
            }

            int durSec = track.value("duration").toInt();
            if (durSec > 0) {
                t.duration = QString("%1:%2").arg(durSec / 60, 2, 10, QChar('0')).arg(durSec % 60, 2, 10, QChar('0'));
            } else {
                t.duration = "03:45";
            }

            qint64 trackId = track.value("id").toVariant().toLongLong();
            t.playCount = formatRankToPlays(650000, trackId);
            t.streamUrl = "";

            if (!t.title.isEmpty() && !t.artist.isEmpty()) {
                m_results.append(t);
            }
        }
        endResetModel();

        m_statusText = m_results.isEmpty() ? "No tracks found." : QString("Discovered %1 studio tracks.").arg(m_results.size());
    } else {
        m_statusText = "Search failed: " + m_currentReply->errorString();
    }

    emit statusTextChanged(m_statusText);
    m_currentReply->deleteLater();
    m_currentReply = nullptr;
}

void OnlineSearchEngine::resolveAndPlay(const QString &title, const QString &artist, const QString &coverUrl) {
    resolveInternal(title, artist, coverUrl, false);
}

void OnlineSearchEngine::resolveAndDownload(const QString &title, const QString &artist, const QString &coverUrl) {
    resolveInternal(title, artist, coverUrl, true);
}

void OnlineSearchEngine::resolveInternal(const QString &title, const QString &artist, const QString &coverUrl, bool isDownload) {
    quint64 token = ++m_activePlaybackToken;
    abortActiveResolution();

    qDebug() << "[OnlineEngine] Resolving (Active Token #" << token << ") for:" << title << "-" << artist << "Download:" << isDownload;
    fetchPersianDirectWeb(this, token, m_networkManager, title, artist, coverUrl, isDownload);
}