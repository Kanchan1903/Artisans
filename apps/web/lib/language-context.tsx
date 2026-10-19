"use client";

import React, { createContext, useContext, useState, useEffect, useCallback } from "react";
import {
  SupportedLocale,
  SUPPORTED_LANGUAGES,
  UI_TRANSLATIONS,
  LanguageOption,
} from "./i18n";

interface LanguageContextType {
  locale: SupportedLocale;
  setLocale: (newLocale: SupportedLocale) => void;
  t: (key: string, fallback?: string) => string;
  languages: LanguageOption[];
  currentLanguage: LanguageOption;
}

const LanguageContext = createContext<LanguageContextType | undefined>(undefined);
const STORAGE_KEY = "kalasathi_locale";

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [locale, setLocaleState] = useState<SupportedLocale>("en");

  // Load saved preference from localStorage
  useEffect(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY) as SupportedLocale | null;
      if (saved && UI_TRANSLATIONS[saved]) {
        setLocaleState(saved);
      }
    } catch (_) {}
  }, []);

  const setLocale = useCallback((newLocale: SupportedLocale) => {
    if (UI_TRANSLATIONS[newLocale]) {
      setLocaleState(newLocale);
      try {
        localStorage.setItem(STORAGE_KEY, newLocale);
        document.documentElement.lang = newLocale;
      } catch (_) {}
    }
  }, []);

  const t = useCallback(
    (key: string, fallback?: string): string => {
      const dict = UI_TRANSLATIONS[locale] || UI_TRANSLATIONS.en;
      if (dict && dict[key]) {
        return dict[key];
      }
      // Fallback to English if key missing in target language
      const enDict = UI_TRANSLATIONS.en;
      if (enDict && enDict[key]) {
        return enDict[key];
      }
      return fallback || key;
    },
    [locale]
  );

  const currentLanguage =
    SUPPORTED_LANGUAGES.find((l) => l.code === locale) || SUPPORTED_LANGUAGES[0];

  return (
    <LanguageContext.Provider
      value={{
        locale,
        setLocale,
        t,
        languages: SUPPORTED_LANGUAGES,
        currentLanguage,
      }}
    >
      {children}
    </LanguageContext.Provider>
  );
}

export function useLanguage() {
  const context = useContext(LanguageContext);
  if (!context) {
    throw new Error("useLanguage must be used within a LanguageProvider");
  }
  return context;
}
