import '../app.css';
import React from "react";
import TagIcon, {Tag} from "@/tags";
import {Button} from "@/components/ui/button";

type ItemTagsProps = {
  tags: Tag[]
}

export default function ItemTags(props: ItemTagsProps) {
  return (
      <div className="flex flex-wrap justify-end items-end space-x-2 space-y-1">
        {
          props.tags.map(tag => {
            return <Button key={tag.id} variant="badge" size="badge" className="px-1.5 bg-tag">
              <TagIcon className="w-4 h-4 mr-1" style={{color: tag.color}}/>
              {tag.name}
            </Button>
          })
        }
      </div>
  )
}
