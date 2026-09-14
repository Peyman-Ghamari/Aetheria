#include "TrackModel.h"
#include <QDirIterator>
#include <QFileInfo>
#include <QMediaPlayer>
#include <QMediaMetaData>
#include <QImage>
#include <QStandardPaths>
#include <QCryptographicHash>
#include <QEventLoop>
#include <QTimer>
#include <QSqlQuery>
#include <QSqlError>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QRandomGenerator>
#include <QDateTime>
#include <algorithm>
#include <QSet>
#include <QHash>
#include <QDebug>
#include <QSettings>

TrackModel::TrackModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_networkManager(new QNetworkAccessManager(this)) {
    initDatabase();
    loadTracksFromDatabase();
    validateDatabaseEntriesAsync();
}

void TrackModel::initDatabase() {
    if (QSqlDatabase::contains("PMPlayerConnection")) {
        m_db = QSqlDatabase::database("PMPlayerConnection");
    } else {
        QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir().mkpath(dataDir);
        QString dbPath = dataDir + "/library.db";

        m_db = QSqlDatabase::addDatabase("QSQLITE", "PMPlayerConnection");
        m_db.setDatabaseName(dbPath);
    }

    if (!m_db.isOpen() && !m_db.open()) {
        qCritical() << "[TrackModel DB] Failed to open SQLite database:" << m_db.lastError().text();
        return;
    }


    QSqlQuery pragmaQuery(m_db);
    pragmaQuery.exec("PRAGMA journal_mode = WAL;");
    pragmaQuery.exec("PRAGMA synchronous = NORMAL;");

    QSqlQuery q(m_db);
    q.exec("CREATE TABLE IF NOT EXISTS tracks ("
           "id INTEGER PRIMARY KEY AUTOINCREMENT, "
           "title TEXT, "
           "artist TEXT, "
           "album TEXT, "
           "file_path TEXT UNIQUE, "
           "duration TEXT, "
           "cover_path TEXT, "
           "is_liked INTEGER DEFAULT 0, "
           "liked_at INTEGER DEFAULT 0, "
           "last_modified INTEGER DEFAULT 0, "
           "synced_lyrics TEXT DEFAULT '')");

    q.exec("ALTER TABLE tracks ADD COLUMN liked_at INTEGER DEFAULT 0");
    q.exec("ALTER TABLE tracks ADD COLUMN last_modified INTEGER DEFAULT 0");
    q.exec("ALTER TABLE tracks ADD COLUMN synced_lyrics TEXT DEFAULT ''");
    q.exec("CREATE INDEX IF NOT EXISTS idx_tracks_path ON tracks(file_path)");

    q.exec("CREATE TABLE IF NOT EXISTS playlists ("
           "id INTEGER PRIMARY KEY AUTOINCREMENT, "
           "name TEXT UNIQUE NOT NULL)");

    q.exec("CREATE TABLE IF NOT EXISTS playlist_tracks ("
           "id INTEGER PRIMARY KEY AUTOINCREMENT, "
           "playlist_name TEXT NOT NULL, "
           "file_path TEXT NOT NULL, "
           "UNIQUE(playlist_name, file_path))");
}

void TrackModel::loadTracksFromDatabase() {
    if (!m_db.isOpen()) return;

    m_allTracks.clear();

    QSqlQuery q("SELECT id, title, artist, album, file_path, duration, cover_path, is_liked, liked_at, last_modified FROM tracks ORDER BY id DESC", m_db);
    while (q.next()) {
        LocalTrack t;
        t.id = q.value(0).toInt();
        t.title = q.value(1).toString();
        t.artist = q.value(2).toString();
        t.album = q.value(3).toString();
        t.filePath = q.value(4).toString();
        t.duration = q.value(5).toString();
        t.coverPath = q.value(6).toString();
        t.isLiked = q.value(7).toInt() == 1;
        t.likedAt = q.value(8).toLongLong();
        t.lastModified = q.value(9).toLongLong();

        if (t.title.trimmed().isEmpty() || t.title == "Unknown Title") {
            QFileInfo fi(t.filePath);
            QString baseName = fi.completeBaseName();
            t.title = baseName.contains(" - ") ? baseName.section(" - ", 1, -1).trimmed() : baseName;
        }

        m_allTracks.append(t);
    }

    applyFilter();
    emit playlistNamesChanged();
}

void TrackModel::validateDatabaseEntriesAsync() {

    QTimer::singleShot(1500, this, [this]() {
        for (const auto &t : m_allTracks) {
            if (t.coverPath.isEmpty()) {
                QString folderCover = findLocalFolderCover(t.filePath);
                if (!folderCover.isEmpty()) {
                    updateCoverInDb(t.filePath, folderCover);
                } else {
                    fetchMissingCover(t.filePath, t.title, t.artist);
                }
            }
        }
    });
}

int TrackModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(m_filteredTracks.size());
}

QVariant TrackModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_filteredTracks.size())
        return QVariant();

    const LocalTrack &track = m_filteredTracks.at(index.row());
    switch (role) {
    case IdRole: return track.id;
    case TitleRole: return track.title;
    case ArtistRole: return track.artist;
    case AlbumRole: return track.album;
    case FilePathRole: return track.filePath;
    case DurationRole: return track.duration;
    case CoverPathRole: return track.coverPath;
    case IsLikedRole: return track.isLiked;
    case LikedAtRole: return track.likedAt;
    default: return QVariant();
    }
}

QHash<int, QByteArray> TrackModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[IdRole] = "trackId";
    roles[TitleRole] = "title";
    roles[ArtistRole] = "artist";
    roles[AlbumRole] = "album";
    roles[DurationRole] = "duration";
    roles[FilePathRole] = "filePath";
    roles[CoverPathRole] = "coverPath";
    roles[IsLikedRole] = "isLiked";
    roles[LikedAtRole] = "likedAt";
    return roles;
}

int TrackModel::count() const {
    return static_cast<int>(m_filteredTracks.size());
}

int TrackModel::currentIndex() const {
    return m_currentIndex;
}

QString TrackModel::filterText() const {
    return m_filterText;
}

void TrackModel::setFilterText(const QString &filter) {
    if (m_filterText != filter) {
        m_filterText = filter;
        emit filterTextChanged();
        applyFilter();
    }
}

bool TrackModel::showOnlyLiked() const {
    return m_showOnlyLiked;
}

void TrackModel::setShowOnlyLiked(bool onlyLiked) {
    if (m_showOnlyLiked != onlyLiked) {
        m_showOnlyLiked = onlyLiked;
        if (m_showOnlyLiked) m_currentPlaylist = "";
        emit showOnlyLikedChanged();
        emit currentPlaylistChanged();
        applyFilter();
    }
}

QString TrackModel::currentPlaylist() const {
    return m_currentPlaylist;
}

void TrackModel::setCurrentPlaylist(const QString &playlist) {
    if (m_currentPlaylist != playlist) {
        m_currentPlaylist = playlist;
        if (!m_currentPlaylist.isEmpty()) m_showOnlyLiked = false;
        emit currentPlaylistChanged();
        emit showOnlyLikedChanged();
        applyFilter();
    }
}

QStringList TrackModel::playlistNames() const {
    QStringList list;
    if (!m_db.isOpen()) return list;
    QSqlQuery q("SELECT name FROM playlists ORDER BY id DESC", m_db);
    while (q.next()) {
        list.append(q.value(0).toString());
    }
    return list;
}

void TrackModel::applyFilter() {
    beginResetModel();
    m_filteredTracks.clear();

    const QString query = m_filterText.trimmed().toLower();

    if (!m_currentPlaylist.isEmpty() && m_db.isOpen()) {
        QSqlQuery q(m_db);
        q.prepare("SELECT file_path FROM playlist_tracks WHERE playlist_name = :p ORDER BY id DESC");
        q.bindValue(":p", m_currentPlaylist);

        QVector<QString> orderedPaths;
        if (q.exec()) {
            while (q.next()) {
                orderedPaths.append(q.value(0).toString());
            }
        }

        QHash<QString, const LocalTrack*> trackMap;
        trackMap.reserve(m_allTracks.size());
        for (const auto &t : m_allTracks) {
            trackMap.insert(t.filePath, &t);
        }

        for (const QString &path : orderedPaths) {
            auto it = trackMap.find(path);
            if (it != trackMap.end()) {
                const LocalTrack *track = it.value();
                if (!query.isEmpty()) {
                    bool matches = track->title.toLower().contains(query) ||
                                   track->artist.toLower().contains(query) ||
                                   track->album.toLower().contains(query);
                    if (!matches) continue;
                }
                m_filteredTracks.append(*track);
            }
        }
    } else {
        for (const auto &track : m_allTracks) {
            if (m_showOnlyLiked && !track.isLiked) {
                continue;
            }

            if (!query.isEmpty()) {
                bool matches = track.title.toLower().contains(query) ||
                               track.artist.toLower().contains(query) ||
                               track.album.toLower().contains(query);
                if (!matches) continue;
            }

            m_filteredTracks.append(track);
        }

        if (m_showOnlyLiked) {
            std::sort(m_filteredTracks.begin(), m_filteredTracks.end(), [](const LocalTrack &a, const LocalTrack &b) {
                return a.likedAt > b.likedAt;
            });
        }
    }

    endResetModel();
    emit countChanged();
}

void TrackModel::setCurrentIndex(int index) {
    if (index >= 0 && index < m_filteredTracks.size()) {
        m_currentIndex = index;
        emit currentIndexChanged(m_currentIndex);
        const auto &track = m_filteredTracks.at(index);
        emit trackSelected(track.title, track.artist, track.filePath, track.coverPath);
    }
}

void TrackModel::playNext() {
    playNextTrack(false);
}

void TrackModel::playNextTrack(bool isShuffle) {
    if (m_filteredTracks.isEmpty()) return;

    if (isShuffle && m_filteredTracks.size() > 1) {
        int randIdx = m_currentIndex;
        while (randIdx == m_currentIndex) {
            randIdx = QRandomGenerator::global()->bounded(static_cast<int>(m_filteredTracks.size()));
        }
        setCurrentIndex(randIdx);
    } else {
        int nextIdx = (m_currentIndex + 1) % m_filteredTracks.size();
        setCurrentIndex(nextIdx);
    }
}

void TrackModel::playPrevious() {
    if (m_filteredTracks.isEmpty()) return;
    int prevIdx = (m_currentIndex - 1 + m_filteredTracks.size()) % m_filteredTracks.size();
    setCurrentIndex(prevIdx);
}

QVariantMap TrackModel::getTrackAt(int index) const {
    QVariantMap map;
    if (index >= 0 && index < m_filteredTracks.size()) {
        const auto &track = m_filteredTracks.at(index);
        map["title"] = track.title;
        map["artist"] = track.artist;
        map["album"] = track.album;
        map["duration"] = track.duration;
        map["filePath"] = track.filePath;
        map["coverPath"] = track.coverPath;
        map["isLiked"] = track.isLiked;
    }
    return map;
}

QVariantList TrackModel::getAllTracks() const {
    QVariantList list;
    list.reserve(m_allTracks.size());
    for (const auto &t : m_allTracks) {
        QVariantMap map;
        map["title"] = t.title;
        map["artist"] = t.artist;
        map["album"] = t.album;
        map["duration"] = t.duration;
        map["filePath"] = t.filePath;
        map["coverPath"] = t.coverPath;
        map["isLiked"] = t.isLiked;
        list.append(map);
    }
    return list;
}

void TrackModel::toggleLike(int index) {
    if (index < 0 || index >= m_filteredTracks.size()) return;
    toggleLikeByPath(m_filteredTracks[index].filePath);
}

void TrackModel::toggleLikeByPath(const QString &filePath) {
    bool newStatus = false;
    qint64 now = QDateTime::currentMSecsSinceEpoch();

    for (auto &t : m_allTracks) {
        if (t.filePath == filePath) {
            t.isLiked = !t.isLiked;
            t.likedAt = t.isLiked ? now : 0;
            newStatus = t.isLiked;
            break;
        }
    }

    if (m_db.isOpen()) {
        QSqlQuery q(m_db);
        q.prepare("UPDATE tracks SET is_liked = :liked, liked_at = :likedAt WHERE file_path = :path");
        q.bindValue(":liked", newStatus ? 1 : 0);
        q.bindValue(":likedAt", newStatus ? now : 0);
        q.bindValue(":path", filePath);
        q.exec();
    }

    if (m_showOnlyLiked) {
        applyFilter();
    } else {
        for (int i = 0; i < m_filteredTracks.size(); ++i) {
            if (m_filteredTracks[i].filePath == filePath) {
                m_filteredTracks[i].isLiked = newStatus;
                m_filteredTracks[i].likedAt = newStatus ? now : 0;
                QModelIndex idx = index(i, 0);
                emit dataChanged(idx, idx, {IsLikedRole, LikedAtRole});
                break;
            }
        }
    }

    emit likeStatusChanged(filePath, newStatus);
}

bool TrackModel::isTrackLiked(const QString &filePath) const {
    for (const auto &t : m_allTracks) {
        if (t.filePath == filePath) {
            return t.isLiked;
        }
    }
    return false;
}

void TrackModel::clear() {
    if (m_db.isOpen()) {
        QSqlQuery q(m_db);
        q.exec("DELETE FROM tracks");
        q.exec("DELETE FROM playlists");
        q.exec("DELETE FROM playlist_tracks");
    }
    m_allTracks.clear();
    applyFilter();
    emit playlistNamesChanged();
}

bool TrackModel::updateTrackMetadata(const QString &filePath, const QString &newTitle, const QString &newArtist, const QString &newAlbum) {
    if (filePath.isEmpty()) return false;

    QFileInfo fi(filePath);
    QString cleanTitle = newTitle.trimmed();
    if (cleanTitle.isEmpty() || cleanTitle == "Unknown Title") {
        cleanTitle = fi.completeBaseName();
        if (cleanTitle.contains(" - ")) cleanTitle = cleanTitle.section(" - ", 1, -1).trimmed();
    }

    QString cleanArtist = newArtist.trimmed().isEmpty() ? "Unknown Artist" : newArtist.trimmed();
    QString cleanAlbum = newAlbum.trimmed().isEmpty() ? "Single Track" : newAlbum.trimmed();

    if (m_db.isOpen()) {
        QSqlQuery q(m_db);
        q.prepare("UPDATE tracks SET title = :title, artist = :artist, album = :album WHERE file_path = :path");
        q.bindValue(":title", cleanTitle);
        q.bindValue(":artist", cleanArtist);
        q.bindValue(":album", cleanAlbum);
        q.bindValue(":path", filePath);
        q.exec();
    }

    QString currentCover = "";
    for (auto &t : m_allTracks) {
        if (t.filePath == filePath) {
            t.title = cleanTitle;
            t.artist = cleanArtist;
            t.album = cleanAlbum;
            currentCover = t.coverPath;
            break;
        }
    }

    applyFilter();

    if (currentCover.isEmpty()) {
        fetchMissingCover(filePath, cleanTitle, cleanArtist);
    }

    return true;
}

QString TrackModel::findLocalFolderCover(const QString &filePath) {
    QFileInfo fi(filePath);
    QDir dir = fi.dir();

    const QString baseName = fi.completeBaseName();
    QStringList candidates;
    candidates << "cover.jpg" << "cover.png" << "cover.jpeg"
               << "folder.jpg" << "folder.png" << "album.jpg" << "album.png"
               << baseName + ".jpg" << baseName + ".png";

    for (const QString &c : candidates) {
        if (dir.exists(c)) {
            return QUrl::fromLocalFile(dir.filePath(c)).toString();
        }
    }
    return "";
}

void TrackModel::updateCoverInDb(const QString &filePath, const QString &coverPath) {
    for (auto &t : m_allTracks) {
        if (t.filePath == filePath) {
            t.coverPath = coverPath;
            break;
        }
    }

    if (m_db.isOpen()) {
        QSqlQuery q(m_db);
        q.prepare("UPDATE tracks SET cover_path = :cover WHERE file_path = :path");
        q.bindValue(":cover", coverPath);
        q.bindValue(":path", filePath);
        q.exec();
    }

    for (int i = 0; i < m_filteredTracks.size(); ++i) {
        if (m_filteredTracks[i].filePath == filePath) {
            m_filteredTracks[i].coverPath = coverPath;
            QModelIndex idx = index(i, 0);
            emit dataChanged(idx, idx, {CoverPathRole});
            break;
        }
    }

    emit coverUpdated(filePath, coverPath);
}

void TrackModel::fetchMissingCover(const QString &filePath, const QString &title, const QString &artist) {
    static const QRegularExpression noiseRx(
        "@[a-zA-Z0-9_]+|_Radio Songs_|_Radio_|_Songs_|_|\\(320\\)|\\[320\\]|\\(128\\)|\\[128\\]|\\b(official|audio|video|remix|version|radio edit)\\b",
        QRegularExpression::CaseInsensitiveOption
    );

    QString cleanTitle = title;
    cleanTitle.replace('_', ' ');
    cleanTitle.remove(noiseRx);
    cleanTitle = cleanTitle.simplified().trimmed();

    QString cleanArtist = (artist == "Local Artist" || artist == "Official Track" || artist == "Unknown Artist") ? "" : artist;
    cleanArtist.replace('_', ' ');
    cleanArtist.remove(noiseRx);
    cleanArtist = cleanArtist.simplified().trimmed();

    if (cleanTitle.contains(" - ")) {
        if (cleanArtist.isEmpty()) {
            cleanArtist = cleanTitle.section(" - ", 0, 0).trimmed();
        }
        cleanTitle = cleanTitle.section(" - ", 1, -1).trimmed();
    }

    QString query = cleanArtist.isEmpty() ? cleanTitle : (cleanArtist + " " + cleanTitle);
    query = query.simplified().trimmed();
    if (query.isEmpty()) return;

    QUrl deezerUrl("https://api.deezer.com/search");
    QUrlQuery dq;
    dq.addQueryItem("q", query);
    dq.addQueryItem("limit", "1");
    deezerUrl.setQuery(dq);

    QNetworkRequest req(deezerUrl);
    req.setHeader(QNetworkRequest::UserAgentHeader, "Mozilla/5.0 (Windows NT 10.0; Win64; x64)");
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, true);

    QNetworkReply *reply = m_networkManager->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, filePath, query]() {
        QString coverUrl = "";
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            QJsonObject obj = QJsonDocument::fromJson(data).object();
            QJsonArray dataArr = obj.value("data").toArray();
            if (!dataArr.isEmpty()) {
                coverUrl = dataArr.first().toObject().value("album").toObject().value("cover_big").toString();
            }
        }
        reply->deleteLater();

        if (!coverUrl.isEmpty()) {
            QNetworkRequest dlReq((QUrl(coverUrl)));
            dlReq.setAttribute(QNetworkRequest::Http2AllowedAttribute, true);
            QNetworkReply *dlReply = m_networkManager->get(dlReq);
            connect(dlReply, &QNetworkReply::finished, this, [this, dlReply, filePath]() {
                if (dlReply->error() == QNetworkReply::NoError) {
                    QImage img;
                    img.loadFromData(dlReply->readAll());
                    if (!img.isNull()) {
                        QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/covers";
                        QDir().mkpath(cacheDir);
                        QString hash = QString(QCryptographicHash::hash(filePath.toUtf8(), QCryptographicHash::Md5).toHex());
                        QString localPath = cacheDir + "/" + hash + ".jpg";
                        img.scaled(320, 320, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(localPath, "JPG", 85);
                        updateCoverInDb(filePath, QUrl::fromLocalFile(localPath).toString());
                    }
                }
                dlReply->deleteLater();
            });
        } else {

            QUrl itunesUrl("https://itunes.apple.com/search");
            QUrlQuery iq;
            iq.addQueryItem("term", query);
            iq.addQueryItem("media", "music");
            iq.addQueryItem("limit", "1");
            itunesUrl.setQuery(iq);

            QNetworkRequest iReq(itunesUrl);
            iReq.setHeader(QNetworkRequest::UserAgentHeader, "Mozilla/5.0 (Windows NT 10.0; Win64; x64)");
            iReq.setAttribute(QNetworkRequest::Http2AllowedAttribute, true);

            QNetworkReply *iReply = m_networkManager->get(iReq);
            connect(iReply, &QNetworkReply::finished, this, [this, iReply, filePath]() {
                if (iReply->error() == QNetworkReply::NoError) {
                    QByteArray iData = iReply->readAll();
                    QJsonObject iObj = QJsonDocument::fromJson(iData).object();
                    QJsonArray resArr = iObj.value("results").toArray();
                    if (!resArr.isEmpty()) {
                        QString rawArt = resArr.first().toObject().value("artworkUrl100").toString();
                        rawArt.replace("100x100bb.jpg", "600x600bb.jpg");

                        QNetworkRequest artReq((QUrl(rawArt)));
                        artReq.setAttribute(QNetworkRequest::Http2AllowedAttribute, true);
                        QNetworkReply *artReply = m_networkManager->get(artReq);
                        connect(artReply, &QNetworkReply::finished, this, [this, artReply, filePath]() {
                            if (artReply->error() == QNetworkReply::NoError) {
                                QImage img;
                                img.loadFromData(artReply->readAll());
                                if (!img.isNull()) {
                                    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/covers";
                                    QDir().mkpath(cacheDir);
                                    QString hash = QString(QCryptographicHash::hash(filePath.toUtf8(), QCryptographicHash::Md5).toHex());
                                    QString localPath = cacheDir + "/" + hash + ".jpg";
                                    img.scaled(320, 320, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(localPath, "JPG", 85);
                                    updateCoverInDb(filePath, QUrl::fromLocalFile(localPath).toString());
                                }
                            }
                            artReply->deleteLater();
                        });
                    }
                }
                iReply->deleteLater();
            });
        }
    });
}

void TrackModel::scanDirectory(const QUrl &folderUrl) {
    QString localPath = folderUrl.toLocalFile();
    if (localPath.isEmpty()) {
        localPath = folderUrl.toString();
        if (localPath.startsWith("file:///")) localPath = localPath.mid(8);
        else if (localPath.startsWith("file://")) localPath = localPath.mid(7);
    }

    localPath = QDir::fromNativeSeparators(localPath);
    QDir dir(localPath);
    if (!dir.exists()) return;

    QStringList nameFilters;
    nameFilters << "*.mp3" << "*.flac" << "*.wav" << "*.m4a" << "*.aac" << "*.ogg" << "*.wma";

    QDirIterator it(localPath, nameFilters, QDir::Files, QDirIterator::Subdirectories);


    QHash<QString, qint64> existingTracksMap;
    for (const auto &ex : m_allTracks) {
        existingTracksMap.insert(ex.filePath, ex.lastModified);
    }

    m_db.transaction();
    QSqlQuery insertOrUpdateQuery(m_db);
    insertOrUpdateQuery.prepare("INSERT INTO tracks (title, artist, album, file_path, duration, cover_path, is_liked, liked_at, last_modified) "
                                "VALUES (:title, :artist, :album, :path, :duration, :cover, 0, 0, :lastMod) "
                                "ON CONFLICT(file_path) DO UPDATE SET "
                                "title = excluded.title, artist = excluded.artist, album = excluded.album, "
                                "duration = excluded.duration, cover_path = excluded.cover_path, last_modified = excluded.last_modified");

    bool hasAnyChanges = false;

    while (it.hasNext()) {
        QString file = QDir::fromNativeSeparators(it.next());
        QFileInfo fi(file);
        qint64 fileLastMod = fi.lastModified().toMSecsSinceEpoch();

        if (existingTracksMap.contains(file) && existingTracksMap.value(file) == fileLastMod) {
            continue;
        }

        hasAnyChanges = true;
        LocalTrack track;
        track.filePath = file;
        track.lastModified = fileLastMod;

        QString baseName = fi.completeBaseName();
        if (baseName.contains(" - ")) {
            track.artist = baseName.section(" - ", 0, 0).trimmed();
            track.title = baseName.section(" - ", 1, -1).trimmed();
        } else {
            track.title = baseName;
            track.artist = "Local Artist";
        }

        track.album = "Single Track";
        track.duration = "--:--";
        track.coverPath = "";
        track.isLiked = false;
        track.likedAt = 0;

        parseFileMetaData(file, track);

        if (track.coverPath.isEmpty()) {
            QString folderCover = findLocalFolderCover(file);
            if (!folderCover.isEmpty()) {
                track.coverPath = folderCover;
            } else {
                fetchMissingCover(file, track.title, track.artist);
            }
        }

        insertOrUpdateQuery.bindValue(":title", track.title);
        insertOrUpdateQuery.bindValue(":artist", track.artist);
        insertOrUpdateQuery.bindValue(":album", track.album);
        insertOrUpdateQuery.bindValue(":path", track.filePath);
        insertOrUpdateQuery.bindValue(":duration", track.duration);
        insertOrUpdateQuery.bindValue(":cover", track.coverPath);
        insertOrUpdateQuery.bindValue(":lastMod", track.lastModified);
        insertOrUpdateQuery.exec();
    }
    m_db.commit();

    if (hasAnyChanges) {
        loadTracksFromDatabase();
    }
}

void TrackModel::parseFileMetaData(const QString &filePath, LocalTrack &track) {
    QMediaPlayer player;
    player.setSource(QUrl::fromLocalFile(filePath));

    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);

    QObject::connect(&player, &QMediaPlayer::metaDataChanged, &loop, &QEventLoop::quit);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);


    timer.start(350);
    loop.exec();

    QMediaMetaData meta = player.metaData();
    if (!meta.isEmpty()) {
        QString t = meta.value(QMediaMetaData::Title).toString().trimmed();
        if (!t.isEmpty()) track.title = t;

        QString a = meta.value(QMediaMetaData::ContributingArtist).toString().trimmed();
        if (a.isEmpty()) a = meta.value(QMediaMetaData::Author).toString().trimmed();
        if (!a.isEmpty()) track.artist = a;

        QString al = meta.value(QMediaMetaData::AlbumTitle).toString().trimmed();
        if (!al.isEmpty()) track.album = al;

        qint64 durMs = meta.value(QMediaMetaData::Duration).toLongLong();
        if (durMs > 0) {
            int durSec = static_cast<int>(durMs / 1000);
            track.duration = QString("%1:%2").arg(durSec / 60, 2, 10, QChar('0')).arg(durSec % 60, 2, 10, QChar('0'));
        }

        QVariant coverVar = meta.value(QMediaMetaData::CoverArtImage);
        if (!coverVar.isValid()) coverVar = meta.value(QMediaMetaData::ThumbnailImage);

        if (coverVar.isValid() && coverVar.canConvert<QImage>()) {
            QImage img = coverVar.value<QImage>();
            if (!img.isNull()) {
                QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/covers";
                QDir().mkpath(cacheDir);

                QString hash = QString(QCryptographicHash::hash(filePath.toUtf8(), QCryptographicHash::Md5).toHex());
                QString coverFilePath = cacheDir + "/" + hash + ".jpg";

                if (!QFile::exists(coverFilePath)) {
                    img.scaled(320, 320, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(coverFilePath, "JPG", 85);
                }
                track.coverPath = QUrl::fromLocalFile(coverFilePath).toString();
            }
        }
    }

    if (track.title.trimmed().isEmpty() || track.title == "Unknown Title") {
        QFileInfo fi(filePath);
        QString baseName = fi.completeBaseName();
        track.title = baseName.contains(" - ") ? baseName.section(" - ", 1, -1).trimmed() : baseName;
    }
}

void TrackModel::createNewPlaylist(const QString &name) {
    if (name.trimmed().isEmpty() || !m_db.isOpen()) return;
    QSqlQuery q(m_db);
    q.prepare("INSERT OR IGNORE INTO playlists (name) VALUES (:name)");
    q.bindValue(":name", name.trimmed());
    if (q.exec()) {
        emit playlistNamesChanged();
    }
}

void TrackModel::removePlaylist(const QString &name) {
    if (!m_db.isOpen()) return;
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM playlists WHERE name = :name");
    q.bindValue(":name", name);
    q.exec();

    q.prepare("DELETE FROM playlist_tracks WHERE playlist_name = :name");
    q.bindValue(":name", name);
    q.exec();

    if (m_currentPlaylist == name) {
        m_currentPlaylist = "";
        emit currentPlaylistChanged();
    }
    emit playlistNamesChanged();
    applyFilter();
}

void TrackModel::addToPlaylist(const QString &playlistName, const QString &filePath) {
    if (!m_db.isOpen()) return;
    QSqlQuery q(m_db);
    q.prepare("INSERT OR IGNORE INTO playlist_tracks (playlist_name, file_path) VALUES (:p, :f)");
    q.bindValue(":p", playlistName);
    q.bindValue(":f", filePath);
    q.exec();

    if (m_currentPlaylist == playlistName) {
        applyFilter();
    }
}

void TrackModel::addMultipleToPlaylist(const QString &playlistName, const QVariantList &filePaths) {
    if (!m_db.isOpen()) return;
    m_db.transaction();
    QSqlQuery q(m_db);
    q.prepare("INSERT OR IGNORE INTO playlist_tracks (playlist_name, file_path) VALUES (:p, :f)");
    for (const auto &v : filePaths) {
        q.bindValue(":p", playlistName);
        q.bindValue(":f", v.toString());
        q.exec();
    }
    m_db.commit();

    if (m_currentPlaylist == playlistName) {
        applyFilter();
    }
}

void TrackModel::removeFromPlaylist(const QString &playlistName, const QString &filePath) {
    if (!m_db.isOpen()) return;
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM playlist_tracks WHERE playlist_name = :p AND file_path = :f");
    q.bindValue(":p", playlistName);
    q.bindValue(":f", filePath);
    q.exec();

    if (m_currentPlaylist == playlistName) {
        applyFilter();
    }
}

void TrackModel::deleteTrackFromLibrary(int index) {
    if (index < 0 || index >= m_filteredTracks.size()) return;
    QString path = m_filteredTracks[index].filePath;

    if (m_db.isOpen()) {
        QSqlQuery q(m_db);
        q.prepare("DELETE FROM tracks WHERE file_path = :path");
        q.bindValue(":path", path);
        q.exec();

        q.prepare("DELETE FROM playlist_tracks WHERE file_path = :path");
        q.bindValue(":path", path);
        q.exec();
    }

    for (int i = 0; i < m_allTracks.size(); ++i) {
        if (m_allTracks[i].filePath == path) {
            m_allTracks.removeAt(i);
            break;
        }
    }

    applyFilter();
}

void TrackModel::playExternalFile(const QString &filePath) {
    if (filePath.trimmed().isEmpty()) return;

    QString cleanPath = QDir::fromNativeSeparators(filePath.trimmed());
    if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.mid(8);
    else if (cleanPath.startsWith("file://")) cleanPath = cleanPath.mid(7);

    QFileInfo fi(cleanPath);
    if (!fi.exists() || !fi.isFile()) return;

    int existingAllIndex = -1;
    for (int i = 0; i < m_allTracks.size(); ++i) {
        if (m_allTracks[i].filePath == cleanPath) {
            existingAllIndex = i;
            break;
        }
    }

    if (existingAllIndex == -1) {
        LocalTrack track;
        track.filePath = cleanPath;
        track.lastModified = fi.lastModified().toMSecsSinceEpoch();

        QString baseName = fi.completeBaseName();
        if (baseName.contains(" - ")) {
            track.artist = baseName.section(" - ", 0, 0).trimmed();
            track.title = baseName.section(" - ", 1, -1).trimmed();
        } else {
            track.title = baseName;
            track.artist = "Local Artist";
        }

        track.album = "Single Track";
        track.duration = "--:--";
        track.coverPath = "";
        track.isLiked = false;
        track.likedAt = 0;

        parseFileMetaData(cleanPath, track);

        if (track.coverPath.isEmpty()) {
            QString folderCover = findLocalFolderCover(cleanPath);
            if (!folderCover.isEmpty()) {
                track.coverPath = folderCover;
            } else {
                fetchMissingCover(cleanPath, track.title, track.artist);
            }
        }

        if (m_db.isOpen()) {
            QSqlQuery insertQuery(m_db);
            insertQuery.prepare("INSERT INTO tracks (title, artist, album, file_path, duration, cover_path, is_liked, liked_at, last_modified) "
                                "VALUES (:title, :artist, :album, :path, :duration, :cover, 0, 0, :lastMod) "
                                "ON CONFLICT(file_path) DO NOTHING");
            insertQuery.bindValue(":title", track.title);
            insertQuery.bindValue(":artist", track.artist);
            insertQuery.bindValue(":album", track.album);
            insertQuery.bindValue(":path", track.filePath);
            insertQuery.bindValue(":duration", track.duration);
            insertQuery.bindValue(":cover", track.coverPath);
            insertQuery.bindValue(":lastMod", track.lastModified);
            if (insertQuery.exec()) {
                track.id = insertQuery.lastInsertId().toInt();
            }
        }

        m_allTracks.prepend(track);
    }

    m_currentPlaylist = "";
    m_showOnlyLiked = false;
    m_filterText = "";
    emit currentPlaylistChanged();
    emit showOnlyLikedChanged();
    emit filterTextChanged();

    applyFilter();

    for (int i = 0; i < m_filteredTracks.size(); ++i) {
        if (m_filteredTracks[i].filePath == cleanPath) {
            setCurrentIndex(i);
            break;
        }
    }
}


void TrackModel::saveLyricsToDb(const QString &filePath, const QString &lyrics) {
    if (filePath.isEmpty() || !m_db.isOpen()) return;

    QSqlQuery q(m_db);
    q.prepare("UPDATE tracks SET synced_lyrics = :lyrics WHERE file_path = :path");
    q.bindValue(":lyrics", lyrics);
    q.bindValue(":path", filePath);
    q.exec();
}


QString TrackModel::getCachedLyricsFromDb(const QString &filePath) {
    if (filePath.isEmpty() || !m_db.isOpen()) return "";

    QSqlQuery q(m_db);
    q.prepare("SELECT synced_lyrics FROM tracks WHERE file_path = :path LIMIT 1");
    q.bindValue(":path", filePath);
    if (q.exec() && q.next()) {
        return q.value(0).toString();
    }
    return "";
}

QString TrackModel::lastSelectedFolder() const {
    QSettings settings("Aetheria", "MusicPlayer");
    return settings.value("lastMusicFolder", QStandardPaths::writableLocation(QStandardPaths::MusicLocation)).toString();
}

void TrackModel::setLastSelectedFolder(const QString &folder) {
    QString localPath = folder;
    if (localPath.startsWith("file:///")) {
        localPath = QUrl(localPath).toLocalFile();
    } else if (localPath.startsWith("file://")) {
        localPath = localPath.mid(7);
    }

    localPath = QDir::fromNativeSeparators(localPath);

    QSettings settings("Aetheria", "MusicPlayer");
    if (settings.value("lastMusicFolder").toString() != localPath) {
        settings.setValue("lastMusicFolder", localPath);
        emit lastSelectedFolderChanged();
    }
}