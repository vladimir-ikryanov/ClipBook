/**
 * CitationsPanel - Display Perplexity web search sources
 * 
 * This component shows citations returned by Perplexity AI
 * when using research or fact-check actions. It's collapsible
 * and provides links to the original sources.
 */

import React, { useState } from "react";
import { BookOpen, ChevronDown, ExternalLink } from "lucide-react";
import { useTranslation } from 'react-i18next';

export interface Citation {
  url: string;
  title?: string;
  snippet?: string;
}

interface CitationsPanelProps {
  citations: Citation[];
  expanded?: boolean;
}

export default function CitationsPanel({ citations, expanded = false }: CitationsPanelProps) {
  const { t } = useTranslation();
  const [isExpanded, setIsExpanded] = useState(expanded);
  
  // Don't render if no citations
  if (!citations || citations.length === 0) {
    return null;
  }
  
  // Extract domain from URL for display
  const getDomain = (url: string): string => {
    try {
      const parsed = new URL(url);
      return parsed.hostname.replace('www.', '');
    } catch {
      return url;
    }
  };
  
  return (
    <div className="border-t border-border">
      {/* Header - clickable to expand/collapse */}
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full px-3 py-2 flex items-center justify-between hover:bg-secondary/30 transition-colors"
      >
        <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
          <BookOpen className="h-3.5 w-3.5" />
          <span>{t('ai.citations.title', { defaultValue: 'Sources' })}</span>
          <span className="bg-secondary px-1.5 py-0.5 rounded text-[10px]">
            {citations.length}
          </span>
        </div>
        <ChevronDown 
          className={`h-3.5 w-3.5 text-muted-foreground transition-transform duration-200 ${
            isExpanded ? 'rotate-180' : ''
          }`} 
        />
      </button>
      
      {/* Citations list */}
      {isExpanded && (
        <div className="px-3 pb-2 space-y-1.5">
          {citations.map((citation, index) => (
            <a
              key={index}
              href={citation.url}
              target="_blank"
              rel="noopener noreferrer"
              className="block p-2 rounded-md bg-secondary/40 hover:bg-secondary/70 transition-colors group"
            >
              <div className="flex items-start justify-between gap-2">
                <div className="flex-1 min-w-0">
                  {/* Title or domain */}
                  <div className="text-xs font-medium text-foreground truncate">
                    {citation.title || getDomain(citation.url)}
                  </div>
                  
                  {/* Snippet if available */}
                  {citation.snippet && (
                    <div className="text-[10px] text-muted-foreground mt-0.5 line-clamp-2">
                      {citation.snippet}
                    </div>
                  )}
                  
                  {/* URL */}
                  <div className="text-[10px] text-primary/70 mt-1 truncate flex items-center gap-1">
                    <span>{getDomain(citation.url)}</span>
                    <ExternalLink className="h-2.5 w-2.5 opacity-0 group-hover:opacity-100 transition-opacity" />
                  </div>
                </div>
                
              {/* Index badge */}
              <span className="flex-shrink-0 text-[10px] text-muted-foreground bg-secondary/80 px-1.5 py-0.5 rounded font-medium">
                {index + 1}
              </span>
              </div>
            </a>
          ))}
        </div>
      )}
    </div>
  );
}
