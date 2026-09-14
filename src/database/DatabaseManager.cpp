#include "DatabaseManager.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>

DatabaseManager::DatabaseManager(QObject *parent)
    : QObject(parent) {
    initDatabase();
}

bool DatabaseManager::initDatabase() {

    if (QSqlDatabase::contains("PMPlayerConnection")) {
        m_db = QSqlDatabase::database("PMPlayerConnection");
    } else {
        m_db = QSqlDatabase::addDatabase("QSQLITE", "PMPlayerConnection");
        QString dbPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir().mkpath(dbPath);
        m_db.setDatabaseName(QDir(dbPath).filePath("library.db"));
    }

    if (!m_db.isOpen() && !m_db.open()) {
        qWarning() << "[DatabaseManager] Failed to open DB:" << m_db.lastError().text();
        return false;
    }


    QSqlQuery qPragma(m_db);
    qPragma.exec("PRAGMA journal_mode = WAL;");
    qPragma.exec("PRAGMA synchronous = NORMAL;");

    QSqlQuery q(m_db);
    q.exec("CREATE TABLE IF NOT EXISTS playlists ("
           "id INTEGER PRIMARY KEY AUTOINCREMENT, "
           "name TEXT UNIQUE NOT NULL)");

    q.exec("CREATE TABLE IF NOT EXISTS playlist_tracks ("
           "id INTEGER PRIMARY KEY AUTOINCREMENT, "
           "playlist_name TEXT NOT NULL, "
           "file_path TEXT NOT NULL, "
           "UNIQUE(playlist_name, file_path))");

    return true;
}

bool DatabaseManager::createPlaylist(const QString &name) {
    if (name.trimmed().isEmpty()) return false;
    QSqlQuery q(m_db);
    q.prepare("INSERT OR IGNORE INTO playlists (name) VALUES (:name)");
    q.bindValue(":name", name.trimmed());
    return q.exec();
}

bool DatabaseManager::deletePlaylist(const QString &name) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM playlists WHERE name = :name");
    q.bindValue(":name", name);
    q.exec();

    q.prepare("DELETE FROM playlist_tracks WHERE playlist_name = :name");
    q.bindValue(":name", name);
    return q.exec();
}

QStringList DatabaseManager::getPlaylists() {
    QStringList list;
    QSqlQuery q("SELECT name FROM playlists ORDER BY id DESC", m_db);
    while (q.next()) {
        list.append(q.value(0).toString());
    }
    return list;
}

bool DatabaseManager::addTrackToPlaylist(const QString &playlistName, const QString &filePath) {
    QSqlQuery q(m_db);
    q.prepare("INSERT OR IGNORE INTO playlist_tracks (playlist_name, file_path) VALUES (:p, :f)");
    q.bindValue(":p", playlistName);
    q.bindValue(":f", filePath);
    return q.exec();
}

bool DatabaseManager::addTracksToPlaylist(const QString &playlistName, const QStringList &filePaths) {
    m_db.transaction();
    QSqlQuery q(m_db);
    q.prepare("INSERT OR IGNORE INTO playlist_tracks (playlist_name, file_path) VALUES (:p, :f)");
    for (const QString &f : filePaths) {
        q.bindValue(":p", playlistName);
        q.bindValue(":f", f);
        q.exec();
    }
    return m_db.commit();
}

bool DatabaseManager::removeTrackFromPlaylist(const QString &playlistName, const QString &filePath) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM playlist_tracks WHERE playlist_name = :p AND file_path = :f");
    q.bindValue(":p", playlistName);
    q.bindValue(":f", filePath);
    return q.exec();
}

QStringList DatabaseManager::getPlaylistTracks(const QString &playlistName) {
    QStringList list;
    QSqlQuery q(m_db);
    q.prepare("SELECT file_path FROM playlist_tracks WHERE playlist_name = :p");
    q.bindValue(":p", playlistName);
    if (q.exec()) {
        while (q.next()) {
            list.append(q.value(0).toString());
        }
    }
    return list;
}

bool DatabaseManager::setTrackLiked(const QString &filePath, bool liked) {
    QSqlQuery q(m_db);
    q.prepare("UPDATE tracks SET is_liked = :liked WHERE file_path = :path");
    q.bindValue(":liked", liked ? 1 : 0);
    q.bindValue(":path", filePath);
    return q.exec();
}

bool DatabaseManager::isTrackLiked(const QString &filePath) {
    QSqlQuery q(m_db);
    q.prepare("SELECT is_liked FROM tracks WHERE file_path = :path LIMIT 1");
    q.bindValue(":path", filePath);
    if (q.exec() && q.next()) {
        return q.value(0).toInt() == 1;
    }
    return false;
}

QStringList DatabaseManager::getLikedTracks() {
    QStringList list;
    QSqlQuery q("SELECT file_path FROM tracks WHERE is_liked = 1", m_db);
    while (q.next()) {
        list.append(q.value(0).toString());
    }
    return list;
}