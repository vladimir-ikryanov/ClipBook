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
import {ThemeProvider} from "@/app/ThemeProvider";
import Privacy from "@/settings/Privacy";
import Shortcuts from "@/settings/Shortcuts";

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
    element: <Settings/>,
  },
  {
    path: "/settings/privacy",
    element: <Privacy/>,
  },
  {
    path: "/settings/shortcuts",
    element: <Shortcuts/>,
  },
]);

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
    <React.StrictMode>
      <ThemeProvider defaultTheme="system">
        <RouterProvider router={router}/>
      </ThemeProvider>
    </React.StrictMode>
)
