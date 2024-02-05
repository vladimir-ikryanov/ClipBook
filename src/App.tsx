import Sidebar from "@/components/Sidebar";
import History from "@/components/History";

export default function App() {
    return (
        <div className="flex h-screen">
            <Sidebar/>
            <History/>
        </div>
    )
}
