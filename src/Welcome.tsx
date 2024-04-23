import {ThemeProvider} from "@/components/theme-provider"
import * as React from "react";

export default function Welcome() {
  return (
      <ThemeProvider defaultTheme="system">
        <h1>Welcome to ClipBook</h1>
      </ThemeProvider>
  )
}
