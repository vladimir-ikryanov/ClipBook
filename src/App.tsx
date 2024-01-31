import './App.css';
import * as Tabs from '@radix-ui/react-tabs';

function App() {
    return (
        <div>
            <div className='draggable'></div>
            <Tabs.Root defaultValue="tab1" orientation="vertical">
                <div>
                    <Tabs.List className="max-w-xs flex flex-col">
                        <Tabs.Trigger value="tab1">One</Tabs.Trigger>
                        <Tabs.Trigger value="tab2">Two</Tabs.Trigger>
                        <Tabs.Trigger value="tab3">Three</Tabs.Trigger>
                    </Tabs.List>
                </div>
                <div>
                    <Tabs.Content value="tab1">Tab one content</Tabs.Content>
                    <Tabs.Content value="tab2">Tab two content</Tabs.Content>
                    <Tabs.Content value="tab3">Tab three content</Tabs.Content>
                </div>
            </Tabs.Root>
        </div>
    )
}

export default App;
