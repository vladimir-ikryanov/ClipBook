import '../App.css';
import {Button} from "@/components/ui/button"
import {Checkbox} from "@/components/ui/checkbox"
import {ToggleGroup, ToggleGroupItem} from "@/components/ui/toggle-group"
import {Settings} from "lucide-react"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"

export default function Preferences() {
  return (
      <Dialog>
        <DialogTrigger asChild>
          <Button variant="ghost">
            <Settings className="h-4 w-4"/>
          </Button>
        </DialogTrigger>
        <DialogContent>
          <DialogHeader>
            <DialogTitle></DialogTitle>
            <DialogDescription className="pt-6 pb-4">
              <div className="flex flex-col">
                <div className="grid grid-cols-6 justify-center">
                  <div className="text-right col-span-2 mt-auto mb-auto mr-8">
                    <p>Startup</p>
                  </div>
                  <div className="col-span-4 flex space-x-2">
                    <Checkbox id="startup" className="mt-auto mb-auto rounded"/>
                    <label
                        htmlFor="startup"
                        className="font-medium leading-none peer-disabled:cursor-not-allowed mt-auto mb-auto">
                      Launch Clipboard at login
                    </label>
                  </div>
                </div>

                <div className="grid grid-cols-6 justify-center mt-6">
                  <div className="text-right col-span-2 mt-auto mb-auto mr-8">
                    <p>Menu bar icon</p>
                  </div>
                  <div className="col-span-4 flex space-x-2">
                    <Checkbox id="tray-icon" className="mt-auto mb-auto rounded"/>
                    <label
                        htmlFor="tray-icon"
                        className="font-medium leading-none peer-disabled:cursor-not-allowed mt-auto mb-auto">
                      Show Clipboard in menu bar
                    </label>
                  </div>
                </div>

                <div className="grid grid-cols-6 justify-center mt-6">
                  <div className="text-right col-span-2 mt-auto mb-auto mr-8">
                    <p>Appearance</p>
                  </div>
                  <div className="col-span-4">
                    <ToggleGroup type="single" defaultValue="a" size={"lg"}>
                      <ToggleGroupItem value="a">Light</ToggleGroupItem>
                      <ToggleGroupItem value="b">Dark</ToggleGroupItem>
                      <ToggleGroupItem value="c">System</ToggleGroupItem>
                    </ToggleGroup>
                  </div>
                </div>
              </div>
            </DialogDescription>
          </DialogHeader>
        </DialogContent>
      </Dialog>
  )
}
