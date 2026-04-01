#include "folders.h"

#include <QDebug>
#include <QDir>
#include <QDirIterator>

#include <MauiKit4/FileBrowsing/fmstatic.h>

Folders::Folders(QObject *parent)
    : MauiList(parent)
{}

const FMH::MODEL_LIST &Folders::items() const
{
    return this->list;
}

void Folders::setFolders(const QList<QUrl> &folders)
{
    if (m_folders == folders)
        return;

    m_folders = folders;
    Q_EMIT this->foldersChanged();
}

QList<QUrl> Folders::folders() const
{
    return m_folders;
}

void Folders::refresh()
{
    this->setFolders(m_folders);
}

void Folders::componentComplete()
{
    connect (this, &Folders::foldersChanged, this, &Folders::setList);
    setList();
}

void Folders::setList()
{
    Q_EMIT this->preListChanged();
    this->list.clear();

    for (const auto &folder : (m_folders))
    {
        auto item = FMStatic::getFileInfoModel(folder);
        item[FMH::MODEL_KEY::PREVIEW] = getPreviews(item[FMH::MODEL_KEY::PATH]).join(",");
        this->list << item;
    }

    Q_EMIT this->postListChanged();
    Q_EMIT this->countChanged();
}

QStringList Folders::getPreviews(const QString &path)
{
    QStringList res;
    const QString localPath = QUrl::fromUserInput(path).toLocalFile();

    qDebug() << "GET PREVIEWS" << path << localPath;

    QDirIterator it(localPath,
                    QStringList() << FMStatic::FILTER_LIST[FMStatic::FILTER_TYPE::IMAGE],
                    QDir::Files,
                    QDirIterator::NoIteratorFlags);

    while (it.hasNext() && res.size() < 4)
    {
        res << QUrl::fromLocalFile(it.next()).toString();
    }

    qDebug() << "GET PREVIEWS" << res;

    return res;
}


