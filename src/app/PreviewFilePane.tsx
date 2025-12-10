import '../app.css';

type PreviewFilePaneProps = {
  filePath: string
  imageFileName: string
  fileSizeInBytes: number
  isFolder: boolean
}

export default function PreviewFilePane(props: PreviewFilePaneProps) {
  return (
      <div className="flex flex-grow mx-4 mb-4 items-center justify-center overflow-auto">
          <img src={"clipbook://images/" + props.imageFileName} className="w-full h-full object-contain"
               alt="Application icon"/>
      </div>
  )
}
