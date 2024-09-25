import Dexie, {Table} from 'dexie';
import {getClipType} from "@/lib/utils";

export enum ClipType {
  Text,
  Link,
  Email,
  Color,
  Image
}

export class Clip {
  id?: number;
  content: string;
  type: ClipType = ClipType.Text;
  sourceApp: string;
  favorite: boolean = false;
  firstTimeCopy: Date = new Date();
  lastTimeCopy: Date = new Date();
  numberOfCopies: number = 1;
  imageFileName?: string;
  imageThumbFileName?: string;
  imageWidth?: number;
  imageHeight?: number;
  imageSizeInBytes?: number;

  constructor(content: string, sourceApp: string, imageFileName?: string) {
    this.content = content;
    this.sourceApp = sourceApp;
    this.imageFileName = imageFileName;
    this.type = imageFileName ? ClipType.Image : getClipType(content);
  }
}

class AppDatabase extends Dexie {
  public history!: Table<Clip, number>;

  constructor() {
    super('ClipBookDB');
    this.version(1).stores({
      history: '++id, content, type, sourceApp, favorite, firstTimeCopy, lastTimeCopy, numberOfCopies, imageFileName, imageThumbFileName, imageWidth, imageHeight, imageSizeInBytes'
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
