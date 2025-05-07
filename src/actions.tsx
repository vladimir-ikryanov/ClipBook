import mitt, {Emitter} from 'mitt';
import {AppInfo, TextFormatOperation, TextType} from "@/data";
import {Clip} from "@/db";

export type OpenFileItemWithAppByIndexArgs = {
  appPath: string;
  index: number;
}

export type OpenInAppByIndexArgs = {
  app: AppInfo | undefined;
  index: number;
}

export type FormatTextByIndexArgs = {
  operation: TextFormatOperation;
  index: number;
}

export type Events = {
  AddTagToItemWithId?: number;
  FilterHistory: void;
  ToggleFilter: void;
  ToggleFavorite: void;
  TogglePreview: void;
  ToggleDetails: void;
  FocusSearchInput: void;
  UpdateApps: void;
  UpdateTags: void;
  SwitchTextType: TextType;
  DeleteTagById: number;
  UpdateTagById: number;
  DeleteItem: void;
  DeleteItemByIndex: number;
  DeleteItems: void;
  DeleteAllItems: void;
  RenameItem: void;
  RenameItemByIndex: number;
  UpdateItemById?: number;
  RenameSelectedItem: void;
  SaveImageAsFile: void;
  ShowFormatTextCommands: void;
  ShowFormatTextCommandsByIndex: number;
  ShowOpenWithCommands: void;
  ShowOpenWithCommandsByIndex: number;
  ShowPasteTransformationCommands: void;
  ShowInFinder: void;
  ShowInFinderByIndex: number;
  ShowInHistory: Clip;
  Split: void;
  Merge: void;
  NotifyAppWindowDidHide: void;
  PasteWithTransformation: TextFormatOperation;
  FormatText: FormatTextByIndexArgs;
  OpenInBrowser: void;
  OpenInBrowserByIndex: number;
  PreviewLinkItem: void;
  PreviewLinkItemByIndex: number;
  CopyToClipboard: void;
  CopyToClipboardByIndex: number;
  CopyTextFromImage: void;
  CopyTextFromImageByIndex: number;
  CopyPathToClipboard: void;
  CopyPathToClipboardByIndex: number;
  CopyObjectToClipboard: void;
  Paste: void;
  PasteWithReturn: void;
  PasteWithTab: void;
  PasteByIndex: number;
  PastePath: void;
  PastePathByIndex: number;
  PasteObject: void;
  EditContent: void;
  EditContentByIndex: number;
  EditItem: Clip;
  OpenFileItemWithApp: string;
  OpenFileItemWithAppByIndex: OpenFileItemWithAppByIndexArgs;
  OpenInApp: AppInfo | undefined;
  OpenInAppByIndex: OpenInAppByIndexArgs;
  OpenSettings: void;
  ZoomIn: void;
  ZoomOut: void;
  ResetZoom: void;
  UpdateLinkPreview: void;
};

export const emitter: Emitter<Events> = mitt<Events>();
