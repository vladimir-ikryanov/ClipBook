import './App.css';
import * as React from 'react';
import {
    ToggleGroup,
    ToggleGroupItem,
} from "@/components/ui/toggle-group"
import {Button} from "@/components/ui/button"

function Sidebar() {
    const [value, setValue] = React.useState('a');

    return (
        <div className="flex flex-col p-2 border-r border-gray-100">
            <ToggleGroup
                type="single"
                className="flex flex-col"
                value={value}
                onValueChange={(value) => {
                    if (value) setValue(value);
                }}>
                <ToggleGroupItem value="a">A</ToggleGroupItem>
                <ToggleGroupItem value="b">B</ToggleGroupItem>
                <ToggleGroupItem value="c">C</ToggleGroupItem>
            </ToggleGroup>
            <div className="grow"></div>
            <Button>S</Button>
        </div>
    )
}

export default Sidebar;
