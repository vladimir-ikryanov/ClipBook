import mitt, {Emitter} from 'mitt';
import {TextType} from "@/app/TextTypeToggle";
import {TextFormatOperation} from "@/data";
import {Clip} from "@/db";

export type Events = {
  AddTagToItemWithId?: number;
  FilterHistory: void;
  ToggleFilter: void;
  FocusSearchInput: void;
  UpdateApps: void;
  UpdateTags: void;
  SwitchTextType: TextType;
  DeleteTagById: number;
  UpdateTagById: number;
  DeleteItemByIndex: number;
  RenameItemByIndex: number;
  UpdateItemById?: number;
  RenameSelectedItem: void;
  ShowFormatTextCommands: void;
  ShowOpenWithCommands: void;
  ShowPasteTransformationCommands: void;
  NotifyAppWindowDidHide: void;
  PasteWithTransformation: TextFormatOperation;
  FormatText: TextFormatOperation;
  OpenLinkItemInBrowserByIndex: number;
  PreviewLinkItemByIndex: number;
  CopyToClipboardByIndex: number;
  CopyTextFromImageByIndex: number;
  CopyPathToClipboardByIndex: number;
  PasteByIndex: number;
  PastePathByIndex: number;
  EditContentByIndex: number;
  EditItem: Clip;
  OpenFileItemWithApp: string;
};

export const emitter: Emitter<Events> = mitt<Events>();
