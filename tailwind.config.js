/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ["class"],
  content: [
    './pages/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
    './app/**/*.{ts,tsx}',
    './src/**/*.{ts,tsx}',
  ],
  prefix: "",
  theme: {
    container: {
      center: true,
      padding: "2rem",
      screens: {
        "2xl": "1400px",
      },
    },
    extend: {
      colors: {
        border: "var(--border)",
        input: "var(--input)",
        ring: "var(--ring)",
        tag: "var(--tag)",
        background: "var(--background)",
        "background-solid": "var(--background-solid)",
        foreground: "var(--foreground)",
        searchHighlight: "var(--search-highlight)",
        checked: "var(--checked)",
        checkbox: "var(--checkbox)",
        "status-bar": {
          DEFAULT: "var(--status-bar-highlight-green-middle)",
          "green": "var(--status-bar-green)",
          "green-button": "var(--status-bar-green-button)",
          "highlight-green-start": "var(--status-bar-highlight-green-start)",
          "highlight-green-middle": "var(--status-bar-highlight-green-middle)",
        },
        scrollbar: {
          DEFAULT: "var(--scrollbar)",
        },
        switch: {
          checked: "var(--switch-checked)",
          unchecked: "var(--switch-unchecked)",
        },
        primary: {
          DEFAULT: "var(--primary)",
          foreground: "var(--primary-foreground)",
        },
        secondary: {
          DEFAULT: "var(--secondary)",
          solid: "var(--secondary-solid)",
          foreground: "var(--secondary-foreground)",
        },
        destructive: {
          DEFAULT: "var(--destructive)",
          foreground: "var(--destructive-foreground)",
        },
        muted: {
          DEFAULT: "var(--muted)",
          foreground: "var(--muted-foreground)",
        },
        accent: {
          DEFAULT: "var(--accent)",
          foreground: "var(--accent-foreground)",
          hover: "var(--accent-hover)",
        },
        popover: {
          DEFAULT: "var(--popover)",
          foreground: "var(--popover-foreground)",
        },
        card: {
          DEFAULT: "var(--card)",
          foreground: "var(--card-foreground)",
        },
        "shortcut-label": {
          DEFAULT: "var(--shortcut-label)",
          text: "var(--shortcut-label-text)",
          hover: "var(--shortcut-label-hover)",
          "hover-text": "var(--shortcut-label-hover-text)",
        },
        actions: {
          DEFAULT: "var(--actions-background)",
          background: "var(--actions-background)",
          selection: "var(--actions-selection)",
          danger: "var(--actions-danger)",
        },
        shortcut: {
          DEFAULT: "var(--shortcut-input)",
        },
        settings: {
          DEFAULT: "var(--settings)",
          border: "var(--settings-border)",
          selection: "var(--settings-selection)",
          sidebarSelection: "var(--settings-sidebar-selection)",
          sidebarLabel: "var(--settings-sidebar-label)",
          titleLicenseTrialLabel: "var(--settings-title-license-trial-label)",
          titleLicenseActivatedLabel: "var(--settings-title-license-activated-label)",
          tableRow: "var(--settings-table-row)",
          tableRow2: "var(--settings-table-row2)",
          inputPlaceholder: "var(--settings-input-placeholder)",
          "primary-button": "var(--primary-button-background)",
          "primary-button-hover": "var(--primary-button-background-hover)",
          "primary-button-text": "var(--primary-button-text)",
          "secondary-button": "var(--secondary-button-background)",
          "secondary-button-hover": "var(--secondary-button-background-hover)",
          "secondary-button-text": "var(--secondary-button-text)",
          "secondary-button-border": "var(--secondary-button-border)",
          "secondary-button-border-hover": "var(--secondary-button-border-hover)",
        },
        toolbar: {
          DEFAULT: "var(--toolbar-background)",
          button: "var(--toolbar-button)",
          buttonActive: "var(--toolbar-button-active)",
          buttonSelected: "var(--toolbar-button-selected)",
        },
        preview: {
          DEFAULT: "var(--preview-background)",
          border: "var(--preview-border)",
          infoBorder: "var(--preview-info-border)",
          infoLabel: "var(--preview-info-label)",
        },
        skeleton: {
          DEFAULT: "var(--skeleton-background)",
          background: "var(--skeleton-background)",
          foreground: "var(--skeleton-foreground)",
          text: "var(--skeleton-text)",
        },
        dialog: {
          shadow: "var(--dialog-shadow)",
          border: "var(--dialog-border)",
          overlay: "var(--dialog-overlay)",
          text: "var(--dialog-text)",
        },
				sidebar: {
					DEFAULT: "var(--sidebar-background)",
					"background-secondary": "var(--sidebar-background-secondary)",
					foreground: "var(--sidebar-foreground)",
					"foreground-secondary": "var(--sidebar-foreground-secondary)",
					primary: "var(--sidebar-primary)",
					"primary-foreground": "var(--sidebar-primary-foreground)",
					accent: "var(--sidebar-accent)",
					"accent-foreground": "var(--sidebar-accent-foreground)",
					border: "var(--sidebar-border)",
					ring: "var(--sidebar-ring)"
				},
        slider: {
          "track-background": "var(--slider-track-background)",
          "track-filled": "var(--slider-track-filled)",
          "thumb-background": "var(--slider-thumb-background)",
          "thumb-border": "var(--slider-thumb-border)",
          "dot-background": "var(--slider-dot-background)",
          "dot-background-filled": "var(--slider-dot-background-filled)",
        }
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
      keyframes: {
        "accordion-down": {
          from: { height: "0" },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: "0" },
        },
        blob: {
          "0%": {
            transform: "translate(0px, 0px) scale(1)",
          },
          "25%": {
            transform: "translate(-20px, 200px) scale(1.5)",
          },
          "50%": {
            transform: "translate(200px, 250px) scale(1.1)",
          },
          "75%": {
            transform: "translate(250px, 150px) scale(1.3)",
          },
          "100%": {
            transform: "translate(0px, 0px) scale(1)",
          },
        },
        blob2: {
          "0%": {
            transform: "translate(0px, 0px) scale(1)",
          },
          "25%": {
            transform: "translate(-50px, -150px) scale(1.3)",
          },
          "50%": {
            transform: "translate(100px, -200px) scale(1)",
          },
          "75%": {
            transform: "translate(100px, 200px) scale(1.3)",
          },
          "100%": {
            transform: "translate(0px, 0px) scale(1)",
          },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
        blob: "blob 20s infinite",
        blob2: "blob2 15s infinite",
      },
    },
  },
  plugins: [
      require("tailwindcss-animate"),
      require("tailwind-scrollbar"),
  ],
}
