import '../app.css';
import {Clip} from "@/db";

type PreviewImagePaneProps = {
  item: Clip
}

export default function PreviewImagePane(props: PreviewImagePaneProps) {
  const imageFile = props.item.imageFileName || props.item.filePathFileName;
  return (
      <div
          className="flex flex-grow m-4 mt-0.5 items-center justify-center outline-none resize-none overflow-hidden">
        <img src={"clipbook://images/" + imageFile} alt={props.item.content}
             className="max-h-full max-w-full object-contain"/>
      </div>
  )
}
