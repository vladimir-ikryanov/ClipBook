import mitt, {Emitter} from 'mitt';
import {TextType} from "@/app/TextTypeToggle";
import {TextFormatOperation} from "@/data";

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
  UpdateItemById?: number;
  RenameSelectedItem: void;
  ShowFormatTextCommands: void;
  ShowOpenWithCommands: void;
  ShowPasteTransformationCommands: void;
  NotifyAppWindowDidHide: void;
  PasteWithTransformation: TextFormatOperation;
  FormatText: TextFormatOperation;
};

export const emitter: Emitter<Events> = mitt<Events>();
