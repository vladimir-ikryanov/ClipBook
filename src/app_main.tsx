import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import Welcome from './Welcome'
import Accessibility from './Accessibility'
import Enjoy from './Enjoy'
import Settings from './Settings'
import Privacy from "@/Privacy";
import {
  createBrowserRouter,
  RouterProvider,
} from "react-router-dom";
import './index.css'
import {ThemeProvider} from "@/components/theme-provider";

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
]);

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
    <React.StrictMode>
      <ThemeProvider defaultTheme="system">
        <RouterProvider router={router}/>
      </ThemeProvider>
    </React.StrictMode>
)
