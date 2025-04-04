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
        foreground: "var(--foreground)",
        searchHighlight: "var(--search-highlight)",
        checked: "var(--checked)",
        checkbox: "var(--checkbox)",
        primary: {
          DEFAULT: "var(--primary)",
          foreground: "var(--primary-foreground)",
        },
        secondary: {
          DEFAULT: "var(--secondary)",
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
          primaryButton: "var(--primary-button-background)",
          primaryButtonHover: "var(--primary-button-background-hover)",
          primaryButtonText: "var(--primary-button-text)",
          secondaryButton: "var(--secondary-button-background)",
          secondaryButtonHover: "var(--secondary-button-background-hover)",
          secondaryButtonText: "var(--secondary-button-text)",
          secondaryButtonBorder: "var(--secondary-button-border)",
          secondaryButtonBorderHover: "var(--secondary-button-border-hover)",
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
					foreground: "var(--sidebar-foreground)",
					primary: "var(--sidebar-primary)",
					"primary-foreground": "var(--sidebar-primary-foreground)",
					accent: "var(--sidebar-accent)",
					"accent-foreground": "var(--sidebar-accent-foreground)",
					border: "var(--sidebar-border)",
					ring: "var(--sidebar-ring)"
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
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
}
