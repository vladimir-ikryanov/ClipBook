import * as React from "react"
import {Slot} from "@radix-ui/react-slot"
import {cva, type VariantProps} from "class-variance-authority"

import {cn} from "@/lib/utils"

const buttonVariants = cva(
    "cursor-default inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors disabled:pointer-events-none disabled:opacity-50",
    {
      variants: {
        variant: {
          default: "bg-primary text-primary-foreground hover:bg-primary/90",
          destructive:
              "bg-destructive text-destructive-foreground hover:bg-destructive/90",
          outline:
              "border border-input bg-background hover:bg-accent hover:text-accent-foreground",
          secondary:
              "bg-secondary text-secondary-foreground hover:bg-secondary/80",
          ghost: "hover:bg-accent hover:text-accent-foreground",
          info: "",
          tool: "focus:outline-none",
          link: "text-primary underline-offset-4 hover:underline",
          toolbar: "rounded-sm text-toolbar-button hover:bg-accent hover:text-accent-foreground",
          dropdown: "rounded-sm text-toolbar-button hover:bg-accent hover:text-accent-foreground outline-none",
          menu: "rounded-sm hover:text-accent-foreground",
          buy: "bg-settings-buyButton text-settings-buyButtonText hover:bg-settings-buyButtonHover",
          activate: "bg-settings-activateButton text-settings-activateButtonText hover:bg-settings-activateButtonHover",
        },
        size: {
          default: "h-10 px-4 py-2",
          sm: "h-9 rounded-md px-3",
          lg: "h-11 rounded-md px-8",
          icon: "h-10 w-10",
          tool: "h-8 w-8",
          toolbar: "h-10 px-2",
          dropdown: "h-10 px-1",
          menu: "h-6 w-6 p-0 m-0",
        },
      },
      defaultVariants: {
        variant: "default",
        size: "default",
      },
    }
)

export interface ButtonProps
    extends React.ButtonHTMLAttributes<HTMLButtonElement>,
        VariantProps<typeof buttonVariants> {
  asChild?: boolean
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
    ({className, variant, size, asChild = false, ...props}, ref) => {
      const Comp = asChild ? Slot : "button"
      return (
          <Comp
              className={cn(buttonVariants({variant, size, className}))}
              ref={ref}
              {...props}
          />
      )
    }
)
Button.displayName = "Button"

export {Button, buttonVariants}
