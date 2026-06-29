import {emitter} from "@/actions";
import {
  addClip,
  Clip,
  ClipType,
  getAllClips,
  getLinkPreviewDetails,
  LinkPreviewDetails,
  saveLinkPreviewDetails,
  updateClip
} from "@/db";
import {allTags, addTag, loadTags, Tag, TagColor} from "@/tags";
import {reloadHistory} from "@/data";

declare const exportClipBookArchive: (
  manifestJson: string,
  tagsJson: string,
  historyJson: string,
  assetRequests: string
) => void;
declare const importClipBookArchive: () => void;
declare const notifyClipBookArchiveImported: () => void;
declare const copyClipBookArchiveAsset: (
  archiveRoot: string,
  relativePath: string,
  linkPreview: boolean,
  fallbackFileName: string
) => string;
declare const getImagesDir: () => string;

type ArchiveManifest = {
  formatVersion: number;
  appName: string;
  appVersion?: string;
  exportedAt: string;
}

type ArchiveTag = {
  id: string;
  name: string;
  color: string;
}

type ArchiveLinkPreviewDetails = {
  url: string;
  title?: string;
  description?: string;
  imagePath?: string;
  faviconPath?: string;
  fetchedAt: string;
}

type ArchiveItem = {
  id: string;
  kind: string;
  title?: string;
  text?: string;
  rtfBase64?: string;
  html?: string;
  assetPath?: string;
  filePaths: string[];
  sourceAppName?: string;
  sourceBundleIdentifier?: string;
  sourceAppPath?: string;
  copiedAt: string;
  firstCopiedAt: string;
  byteSize: number;
  isFavorite: boolean;
  tagIDs: string[];
  tagNames: string[];
  copyCount: number;
  linkPreviewDetails?: ArchiveLinkPreviewDetails;
  copySequenceID?: string;
  copySequenceOrder?: number;
  imageWidth?: number;
  imageHeight?: number;
  imageText?: string;
  fileFolder?: boolean;
}

type ArchiveAssetRequest = {
  sourcePath: string;
  relativePath: string;
}

type ImportPayload = {
  archiveRoot: string;
  manifestJson: string;
  tagsJson: string;
  historyJson: string;
}

export type ArchiveImportResult = {
  itemCount: number;
  tagCount: number;
}

const supportedFormatVersion = 1;

export async function exportHistoryArchive(): Promise<string | undefined> {
  loadTags();
  const clips = await getAllClips();
  const tags = allTags();
  const assetRequests: ArchiveAssetRequest[] = [];
  const archiveTags = tags.map(archiveTag);
  const archiveItems = await Promise.all(clips.map(clip => archiveItem(clip, tags, assetRequests)));
  const manifest: ArchiveManifest = {
    formatVersion: supportedFormatVersion,
    appName: "ClipBook",
    exportedAt: new Date().toISOString()
  };

  return new Promise((resolve, reject) => {
    window.clipBookArchiveExportDidFinish = (success, message) => {
      window.clipBookArchiveExportDidFinish = undefined;
      if (message === "__CANCELED__") {
        resolve(undefined);
        return;
      }
      if (success) {
        resolve(message);
      } else {
        reject(new Error(message));
      }
    };

    exportClipBookArchive(
      JSON.stringify(manifest, null, 2),
      JSON.stringify(archiveTags, null, 2),
      JSON.stringify(archiveItems, null, 2),
      assetRequests.map(request => `${request.sourcePath}\t${request.relativePath}`).join("\n")
    );
  });
}

export async function importHistoryArchive(): Promise<ArchiveImportResult | undefined> {
  return new Promise((resolve, reject) => {
    window.clipBookArchiveImportDidLoad = async (archiveRoot, manifestJson, tagsJson, historyJson) => {
      clearImportCallbacks();
      try {
        resolve(await importArchivePayload({archiveRoot, manifestJson, tagsJson, historyJson}));
      } catch (error) {
        reject(error);
      }
    };
    window.clipBookArchiveImportDidFail = message => {
      clearImportCallbacks();
      if (message === "__CANCELED__") {
        resolve(undefined);
        return;
      }
      reject(new Error(message));
    };

    importClipBookArchive();
  });
}

async function importArchivePayload(payload: ImportPayload): Promise<ArchiveImportResult> {
  const manifest = JSON.parse(payload.manifestJson) as ArchiveManifest;
  if (manifest.formatVersion > supportedFormatVersion) {
    throw new Error(`ClipBook archive version ${manifest.formatVersion} is not supported.`);
  }

  loadTags();
  const archiveTags = JSON.parse(payload.tagsJson) as ArchiveTag[];
  const archiveItems = JSON.parse(payload.historyJson) as ArchiveItem[];
  const tagIdsByArchiveId = importTags(archiveTags);
  const existingClips = await getAllClips();

  for (const archiveItem of archiveItems) {
    const clip = importArchiveItem(archiveItem, payload.archiveRoot, tagIdsByArchiveId);
    const existingClip = findExistingClip(existingClips, clip);
    if (existingClip?.id !== undefined) {
      clip.id = existingClip.id;
      await updateClip(existingClip.id, clip);
      Object.assign(existingClip, clip);
    } else {
      await addClip(clip);
      existingClips.push(clip);
    }

    if (archiveItem.linkPreviewDetails) {
      await importLinkPreviewDetails(archiveItem.linkPreviewDetails, payload.archiveRoot);
    }
  }

  await reloadHistory();
  emitter.emit("UpdateTags");
  emitter.emit("FilterHistory");
  notifyClipBookArchiveImported();
  return {itemCount: archiveItems.length, tagCount: archiveTags.length};
}

function clearImportCallbacks() {
  window.clipBookArchiveImportDidLoad = undefined;
  window.clipBookArchiveImportDidFail = undefined;
}

function archiveTag(tag: Tag): ArchiveTag {
  return {
    id: String(tag.id),
    name: tag.name,
    color: tag.color
  };
}

async function archiveItem(clip: Clip, tags: Tag[], assetRequests: ArchiveAssetRequest[]): Promise<ArchiveItem> {
  const kind = archiveKind(clip);
  const imageAssetPath = archiveImageAssetPath(clip.imageFileName, assetRequests);
  const linkPreviewDetails = kind === "link" ? await archiveLinkPreviewDetails(clip.content, assetRequests) : undefined;

  return {
    id: stableArchiveID(clip.id),
    kind,
    title: clip.name || undefined,
    text: archiveText(clip),
    rtfBase64: clip.rtf ? encodeBase64(clip.rtf) : undefined,
    html: clip.html || undefined,
    assetPath: imageAssetPath,
    filePaths: clip.type === ClipType.File ? [clip.filePath || clip.content].filter(Boolean) : [],
    sourceAppName: sourceAppName(clip.sourceApp),
    sourceAppPath: clip.sourceApp || undefined,
    copiedAt: dateToISOString(clip.lastTimeCopy),
    firstCopiedAt: dateToISOString(clip.firstTimeCopy),
    byteSize: archiveByteSize(clip),
    isFavorite: clip.favorite,
    tagIDs: (clip.tags || []).map(String),
    tagNames: (clip.tags || []).map(tagID => tags.find(tag => tag.id === tagID)?.name).filter((name): name is string => Boolean(name)),
    copyCount: clip.numberOfCopies,
    linkPreviewDetails,
    copySequenceID: clip.sequenceId ? new Date(clip.sequenceId).toISOString() : undefined,
    copySequenceOrder: clip.sequenceOrder,
    imageWidth: clip.imageWidth,
    imageHeight: clip.imageHeight,
    imageText: clip.imageText || undefined,
    fileFolder: clip.fileFolder
  };
}

function importTags(archiveTags: ArchiveTag[]): Map<string, number> {
  const tagIdsByArchiveId = new Map<string, number>();
  for (const archiveTag of archiveTags) {
    const existingTag = allTags().find(tag => tag.name.localeCompare(archiveTag.name, undefined, {sensitivity: "accent"}) === 0);
    if (existingTag) {
      tagIdsByArchiveId.set(archiveTag.id, existingTag.id);
      continue;
    }

    const tag = new Tag(archiveTag.name, archiveTag.color || TagColor.Blue);
    addTag(tag);
    tagIdsByArchiveId.set(archiveTag.id, tag.id);
  }
  return tagIdsByArchiveId;
}

function importArchiveItem(archiveItem: ArchiveItem, archiveRoot: string, tagIdsByArchiveId: Map<string, number>): Clip {
  const type = clipType(archiveItem.kind);
  const content = archiveContent(archiveItem);
  const clip = new Clip(type, content, archiveItem.sourceAppPath || "");
  clip.name = archiveItem.title || "";
  clip.favorite = archiveItem.isFavorite;
  clip.tags = archiveItem.tagIDs.map(tagID => tagIdsByArchiveId.get(tagID)).filter((tagID): tagID is number => tagID !== undefined);
  clip.firstTimeCopy = new Date(archiveItem.firstCopiedAt || archiveItem.copiedAt);
  clip.lastTimeCopy = new Date(archiveItem.copiedAt);
  clip.numberOfCopies = archiveItem.copyCount || 1;
  clip.rtf = archiveItem.rtfBase64 ? decodeBase64(archiveItem.rtfBase64) : "";
  clip.html = archiveItem.html || "";
  clip.imageFileName = archiveItem.assetPath
    ? copyClipBookArchiveAsset(archiveRoot, archiveItem.assetPath, false, `${archiveItem.id}.png`)
    : "";
  clip.imageThumbFileName = clip.imageFileName;
  clip.imageWidth = archiveItem.imageWidth || 0;
  clip.imageHeight = archiveItem.imageHeight || 0;
  clip.imageSizeInBytes = type === ClipType.Image ? archiveItem.byteSize : 0;
  clip.imageText = archiveItem.imageText || "";
  clip.filePath = archiveItem.filePaths[0] || "";
  clip.filePathFileName = "";
  clip.filePathThumbFileName = "";
  clip.fileSizeInBytes = type === ClipType.File ? archiveItem.byteSize : 0;
  clip.fileFolder = archiveItem.fileFolder || false;
  clip.sequenceId = archiveItem.copySequenceID ? new Date(archiveItem.copySequenceID).getTime() : undefined;
  clip.sequenceOrder = archiveItem.copySequenceOrder;
  return clip;
}

async function importLinkPreviewDetails(details: ArchiveLinkPreviewDetails, archiveRoot: string) {
  await saveLinkPreviewDetails(new LinkPreviewDetails(
    details.url,
    details.title || "",
    details.description || "",
    details.imagePath ? copyClipBookArchiveAsset(archiveRoot, details.imagePath, true, "preview.png") : "",
    details.faviconPath ? copyClipBookArchiveAsset(archiveRoot, details.faviconPath, true, "favicon.png") : ""
  ));
}

async function archiveLinkPreviewDetails(url: string, assetRequests: ArchiveAssetRequest[]): Promise<ArchiveLinkPreviewDetails | undefined> {
  const details = await getLinkPreviewDetails(url);
  if (!details) {
    return undefined;
  }

  return {
    url: details.url,
    title: details.title || undefined,
    description: details.description || undefined,
    imagePath: archiveLinkPreviewAssetPath(details.imageFileName, assetRequests),
    faviconPath: archiveLinkPreviewAssetPath(details.faviconFileName, assetRequests),
    fetchedAt: new Date().toISOString()
  };
}

function archiveImageAssetPath(fileName: string, assetRequests: ArchiveAssetRequest[]): string | undefined {
  if (!fileName) {
    return undefined;
  }

  const relativePath = `assets/images/${fileName}`;
  assetRequests.push({sourcePath: `${getImagesDir()}/${fileName}`, relativePath});
  return relativePath;
}

function archiveLinkPreviewAssetPath(fileName: string, assetRequests: ArchiveAssetRequest[]): string | undefined {
  if (!fileName) {
    return undefined;
  }

  const relativePath = `assets/link-previews/${fileName}`;
  assetRequests.push({sourcePath: `${getImagesDir()}/links/${fileName}`, relativePath});
  return relativePath;
}

function archiveKind(clip: Clip): string {
  switch (clip.type) {
    case ClipType.Link:
      return "link";
    case ClipType.Email:
      return "email";
    case ClipType.Color:
      return "color";
    case ClipType.Image:
      return "image";
    case ClipType.File:
      return "file";
    case ClipType.Text:
    default:
      return clip.rtf || clip.html ? "richText" : "text";
  }
}

function clipType(kind: string): ClipType {
  switch (kind) {
    case "link":
      return ClipType.Link;
    case "email":
      return ClipType.Email;
    case "color":
      return ClipType.Color;
    case "image":
      return ClipType.Image;
    case "file":
      return ClipType.File;
    case "richText":
    case "text":
    default:
      return ClipType.Text;
  }
}

function archiveText(clip: Clip): string | undefined {
  if (clip.type === ClipType.Image) {
    return clip.imageText || undefined;
  }
  if (clip.type === ClipType.File) {
    return undefined;
  }
  return clip.content || undefined;
}

function archiveContent(archiveItem: ArchiveItem): string {
  if (archiveItem.kind === "file") {
    return archiveItem.filePaths[0] || "";
  }
  if (archiveItem.kind === "image") {
    return "";
  }
  return archiveItem.text || "";
}

function archiveByteSize(clip: Clip): number {
  if (clip.type === ClipType.Image) {
    return clip.imageSizeInBytes;
  }
  if (clip.type === ClipType.File) {
    return clip.fileSizeInBytes;
  }
  return clip.content.length;
}

function findExistingClip(clips: Clip[], importedClip: Clip): Clip | undefined {
  if (importedClip.type === ClipType.Image) {
    if (!importedClip.imageFileName) {
      return undefined;
    }
    return clips.find(clip => clip.type === ClipType.Image && clip.imageFileName === importedClip.imageFileName);
  }

  if (importedClip.type === ClipType.File) {
    if (!importedClip.filePath) {
      return undefined;
    }
    return clips.find(clip => clip.type === ClipType.File && clip.filePath === importedClip.filePath);
  }

  if (!importedClip.content) {
    return undefined;
  }
  return clips.find(clip => clip.type === importedClip.type && clip.content === importedClip.content);
}

function sourceAppName(sourceAppPath: string): string | undefined {
  if (!sourceAppPath) {
    return undefined;
  }
  const lastPathComponent = sourceAppPath.split("/").filter(Boolean).pop();
  return lastPathComponent?.replace(/\.app$/, "");
}

function stableArchiveID(id: number | undefined): string {
  if (id === undefined) {
    return crypto.randomUUID();
  }

  const hexID = id.toString(16).padStart(12, "0").slice(-12);
  return `00000000-0000-4000-8000-${hexID}`;
}

function dateToISOString(date: Date | string | number): string {
  return new Date(date).toISOString();
}

function encodeBase64(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

function decodeBase64(value: string): string {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return new TextDecoder().decode(bytes);
}

declare global {
  interface Window {
    clipBookArchiveExportDidFinish?: (success: boolean, message: string) => void;
    clipBookArchiveImportDidLoad?: (
      archiveRoot: string,
      manifestJson: string,
      tagsJson: string,
      historyJson: string
    ) => void;
    clipBookArchiveImportDidFail?: (message: string) => void;
  }
}
