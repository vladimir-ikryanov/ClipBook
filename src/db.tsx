import Dexie, {Table} from 'dexie';

export enum ClipType {
  Text,
  Link,
  Email,
  Color,
  Image,
  File
}

export class LinkPreviewDetails {
  id?: number;
  url: string;
  title: string;
  description: string;
  imageFileName: string;
  faviconFileName: string;

  constructor(url: string, title: string, description: string, imageFileName: string, faviconFileName: string) {
    this.url = url
    this.title = title
    this.description = description
    this.imageFileName = imageFileName
    this.faviconFileName = faviconFileName
  }
}

export class Clip {
  id?: number;
  name: string = "";
  content: string;
  type: ClipType = ClipType.Text;
  sourceApp: string;
  favorite: boolean = false;
  firstTimeCopy: Date = new Date();
  lastTimeCopy: Date = new Date();
  numberOfCopies: number = 1;
  imageFileName: string = "";
  imageThumbFileName?: string;
  imageWidth: number = 0;
  imageHeight: number = 0;
  imageSizeInBytes: number = 0;
  imageText: string = "";
  filePath: string = "";
  filePathFileName: string = "";
  filePathThumbFileName: string = "";
  fileSizeInBytes: number = 0;
  fileFolder: boolean = false;

  constructor(type: ClipType, content: string, sourceApp: string) {
    this.type = type;
    this.content = content;
    this.sourceApp = sourceApp;
  }
}

class AppDatabase extends Dexie {
  public history!: Table<Clip, number>;
  public linkPreviews!: Table<LinkPreviewDetails, number>;

  constructor() {
    super('ClipBookDB');
    this.version(1).stores({
      history: '++id, title, content, type, sourceApp, favorite, firstTimeCopy, lastTimeCopy, numberOfCopies, imageFileName, imageThumbFileName, imageWidth, imageHeight, imageSizeInBytes, imageText, filePath, filePathFileName, filePathThumbFileName, fileSizeInBytes, fileFolder',
      linkPreviews: '++id, url, title, description, imageFileName, faviconFileName'
    });
  }
}

const db = new AppDatabase();

export async function getAllClips(): Promise<Clip[]> {
  return db.history.toArray()
}

export async function addClip(clip: Clip) {
  await db.history.add(clip)
}

export async function updateClip(id: number, clip: Clip) {
  await db.history.update(id, clip)
}

export async function deleteClip(id: number) {
  await db.history.delete(id)
}

export async function deleteAllClips() {
  await db.history.clear()
}

export async function saveLinkPreviewDetails(details: LinkPreviewDetails) {
  await db.linkPreviews.where('url').equals(details.url).delete()
  await db.linkPreviews.add(details)
}

export async function deleteLinkPreviewDetails(url: string) {
  await db.linkPreviews.where('url').equals(url).delete()
}

export async function getLinkPreviewDetails(url: string): Promise<LinkPreviewDetails | undefined> {
  return db.linkPreviews.where('url').equals(url).first()
}
