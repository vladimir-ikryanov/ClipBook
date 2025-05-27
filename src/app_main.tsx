import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './app/App'
import Welcome from './welcome/Welcome'
import Accessibility from './welcome/Accessibility'
import Enjoy from './welcome/Enjoy'
import Settings from './settings/Settings'
import {
  createBrowserRouter,
  RouterProvider,
} from "react-router-dom";
import './index.css'
import './i18n'
import {ThemeProvider} from "@/app/ThemeProvider";

const router = createBrowserRouter([
  {
    path: "/",
    element: <App/>,
  },
  {
    path: "/welcome",
    element: <Welcome/>,
  },
  {
    path: "/accessibility",
    element: <Accessibility/>,
  },
  {
    path: "/enjoy",
    element: <Enjoy/>,
  },
  {
    path: "/settings",
    element: <Settings selectedItemType={"General"}/>,
  },
  {
    path: "/settings/history",
    element: <Settings selectedItemType={"History"}/>,
  },
  {
    path: "/settings/privacy",
    element: <Settings selectedItemType={"Privacy"}/>,
  },
  {
    path: "/settings/shortcuts",
    element: <Settings selectedItemType={"Shortcuts"}/>,
  },
  {
    path: "/settings/license",
    element: <Settings selectedItemType={"License"}/>,
  },
  {
    path: "/settings/about",
    element: <Settings selectedItemType={"About"}/>,
  },
]);

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
    <React.StrictMode>
      <ThemeProvider defaultTheme="system">
        <RouterProvider router={router}/>
      </ThemeProvider>
    </React.StrictMode>
)
