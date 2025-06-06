import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import HttpBackend from 'i18next-http-backend';
import { prefGetLanguage } from "@/pref";

declare const onLanguageChanged: () => void;

i18n
  .use(HttpBackend) // load translations from public/locales
  .use(initReactI18next) // connect with React
  .init({
    fallbackLng: prefGetLanguage(),
    debug: true,
    interpolation: {
      escapeValue: false, // react already escapes
    },
    backend: {
      loadPath: '/locales/{{lng}}/translation.json',
    },
  });

export function updateLanguage() {
  const language = prefGetLanguage()
  i18n.changeLanguage(language).then(() => {
    onLanguageChanged()
  })
}

export function translate(key: string) {
  return i18n.t(key);
}

(window as any).updateLanguage = updateLanguage;
(window as any).translate = translate;

export default i18n;
