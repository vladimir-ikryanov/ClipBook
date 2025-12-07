import * as React from "react";
import { useState, useEffect, useMemo, useCallback } from "react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import {
  ChevronLeft,
  ChevronRight,
  Calendar as CalendarIcon,
  RefreshCw,
  Globe,
  Star,
  PartyPopper,
  Briefcase,
  Clock,
  Loader2,
  AlertCircle,
} from "lucide-react";
import { useTranslation } from 'react-i18next';
import { prefGetAIAPIKey, prefGetAIProvider } from "@/pref";

declare const closeSettingsWindow: () => void;

// Event types
interface DayEvent {
  title: string;
  type: 'holiday' | 'observance' | 'event' | 'announcement';
  description?: string;
  country?: string;
}

interface CachedEvents {
  events: Record<string, DayEvent[]>; // key: "YYYY-MM-DD"
  lastFetched: number;
  month: number;
  year: number;
}

const CACHE_KEY = 'clipbook_calendar_events';
const CACHE_DURATION = 7 * 24 * 60 * 60 * 1000; // 7 days in ms

// Month names
const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

// Event type icons
const EVENT_ICONS: Record<string, React.ReactNode> = {
  holiday: <Star className="h-3 w-3 text-yellow-500" />,
  observance: <Globe className="h-3 w-3 text-blue-500" />,
  event: <PartyPopper className="h-3 w-3 text-purple-500" />,
  announcement: <Briefcase className="h-3 w-3 text-green-500" />,
};

export default function Calendar() {
  const { t } = useTranslation();
  
  const [currentDate, setCurrentDate] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  const [events, setEvents] = useState<Record<string, DayEvent[]>>({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastFetched, setLastFetched] = useState<Date | null>(null);

  const currentMonth = currentDate.getMonth();
  const currentYear = currentDate.getFullYear();

  // Load cached events on mount
  useEffect(() => {
    loadCachedEvents();
  }, []);

  // Check if we need to fetch new events when month changes
  useEffect(() => {
    const cached = getCachedEvents();
    if (cached && cached.month === currentMonth && cached.year === currentYear) {
      // Use cached data
      setEvents(cached.events);
      setLastFetched(new Date(cached.lastFetched));
    } else if (!loading) {
      // Need to fetch for this month
      fetchEventsForMonth(currentMonth, currentYear);
    }
  }, [currentMonth, currentYear]);

  // Keyboard handler
  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        closeSettingsWindow();
        e.preventDefault();
      }
    };
    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, []);

  const loadCachedEvents = () => {
    try {
      const cached = localStorage.getItem(CACHE_KEY);
      if (cached) {
        const data: CachedEvents = JSON.parse(cached);
        const now = Date.now();
        
        // Check if cache is still valid (less than 7 days old)
        if (now - data.lastFetched < CACHE_DURATION) {
          if (data.month === currentMonth && data.year === currentYear) {
            setEvents(data.events);
            setLastFetched(new Date(data.lastFetched));
          }
        }
      }
    } catch (e) {
      console.error('Error loading cached events:', e);
    }
  };

  const getCachedEvents = (): CachedEvents | null => {
    try {
      const cached = localStorage.getItem(CACHE_KEY);
      if (cached) {
        return JSON.parse(cached);
      }
    } catch (e) {
      console.error('Error reading cache:', e);
    }
    return null;
  };

  const saveCachedEvents = (events: Record<string, DayEvent[]>, month: number, year: number) => {
    try {
      const cacheData: CachedEvents = {
        events,
        lastFetched: Date.now(),
        month,
        year,
      };
      localStorage.setItem(CACHE_KEY, JSON.stringify(cacheData));
    } catch (e) {
      console.error('Error saving cache:', e);
    }
  };

  const fetchEventsForMonth = async (month: number, year: number) => {
    const apiKey = prefGetAIAPIKey();
    const provider = prefGetAIProvider();
    
    if (!apiKey || provider !== 'perplexity') {
      setError('Please configure Perplexity API in Settings → AI to fetch events');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const monthName = MONTHS[month];
      const prompt = `List all major holidays, observances, and notable events for ${monthName} ${year}. 
Include:
- Public holidays (specify country if not global)
- International observance days
- Major global events or announcements happening this month
- Notable anniversaries

Format each event as: DATE|TYPE|TITLE|DESCRIPTION
Where DATE is the day number (1-31), TYPE is one of: holiday, observance, event, announcement
Example: 25|holiday|Christmas Day|Christian holiday celebrating the birth of Jesus

List all events, one per line. Only output the formatted list, nothing else.`;

      const response = await fetch('https://api.perplexity.ai/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`
        },
        body: JSON.stringify({
          model: 'sonar',
          messages: [
            {
              role: "system",
              content: "You are a calendar events assistant. Provide accurate holiday and event information in the exact format requested. Be comprehensive but accurate."
            },
            {
              role: "user",
              content: prompt
            }
          ],
          temperature: 0.3,
          max_tokens: 2000,
        })
      });

      if (!response.ok) {
        throw new Error('Failed to fetch events from Perplexity');
      }

      const data = await response.json();
      const content = data.choices[0]?.message?.content || '';
      
      // Parse the response
      const parsedEvents: Record<string, DayEvent[]> = {};
      const lines = content.split('\n').filter((l: string) => l.trim());
      
      for (const line of lines) {
        const parts = line.split('|');
        if (parts.length >= 3) {
          const day = parseInt(parts[0].trim());
          const type = parts[1].trim().toLowerCase() as DayEvent['type'];
          const title = parts[2].trim();
          const description = parts[3]?.trim();
          
          if (day >= 1 && day <= 31) {
            const dateKey = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
            if (!parsedEvents[dateKey]) {
              parsedEvents[dateKey] = [];
            }
            parsedEvents[dateKey].push({
              title,
              type: ['holiday', 'observance', 'event', 'announcement'].includes(type) ? type : 'event',
              description,
            });
          }
        }
      }

      setEvents(parsedEvents);
      setLastFetched(new Date());
      saveCachedEvents(parsedEvents, month, year);
      
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to fetch events');
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = () => {
    fetchEventsForMonth(currentMonth, currentYear);
  };

  const handlePrevMonth = () => {
    setCurrentDate(new Date(currentYear, currentMonth - 1, 1));
    setSelectedDate(null);
  };

  const handleNextMonth = () => {
    setCurrentDate(new Date(currentYear, currentMonth + 1, 1));
    setSelectedDate(null);
  };

  const handleToday = () => {
    const today = new Date();
    setCurrentDate(today);
    setSelectedDate(today);
  };

  // Generate calendar days
  const calendarDays = useMemo(() => {
    const firstDay = new Date(currentYear, currentMonth, 1);
    const lastDay = new Date(currentYear, currentMonth + 1, 0);
    const daysInMonth = lastDay.getDate();
    const startingDay = firstDay.getDay();
    
    const days: (number | null)[] = [];
    
    // Add empty slots for days before the first day of month
    for (let i = 0; i < startingDay; i++) {
      days.push(null);
    }
    
    // Add the days of the month
    for (let i = 1; i <= daysInMonth; i++) {
      days.push(i);
    }
    
    return days;
  }, [currentMonth, currentYear]);

  const getDateKey = (day: number) => {
    return `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  };

  const getEventsForDay = (day: number): DayEvent[] => {
    const key = getDateKey(day);
    return events[key] || [];
  };

  const isToday = (day: number) => {
    const today = new Date();
    return today.getDate() === day && 
           today.getMonth() === currentMonth && 
           today.getFullYear() === currentYear;
  };

  const isSelected = (day: number) => {
    if (!selectedDate) return false;
    return selectedDate.getDate() === day &&
           selectedDate.getMonth() === currentMonth &&
           selectedDate.getFullYear() === currentYear;
  };

  const selectedDateEvents = selectedDate 
    ? getEventsForDay(selectedDate.getDate())
    : [];

  return (
    <div className="flex flex-col h-screen">
      {/* Header */}
      <div className="px-6 py-4 border-b border-border draggable">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <CalendarIcon className="h-5 w-5 text-primary" />
            <h1 className="text-lg font-semibold">
              {t('settings.calendar.title', { defaultValue: 'Events Calendar' })}
            </h1>
          </div>
          <div className="flex items-center gap-2">
            {lastFetched && (
              <span className="text-xs text-muted-foreground flex items-center gap-1">
                <Clock className="h-3 w-3" />
                Updated: {lastFetched.toLocaleDateString()}
              </span>
            )}
            <Button 
              variant="ghost" 
              size="sm" 
              onClick={handleRefresh}
              disabled={loading}
            >
              <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
            </Button>
          </div>
        </div>
        <p className="text-sm text-muted-foreground mt-1">
          {t('settings.calendar.description', { defaultValue: 'View holidays, events, and observances worldwide' })}
        </p>
      </div>

      {/* Error message */}
      {error && (
        <div className="mx-6 mt-4 p-3 bg-destructive/10 border border-destructive/30 rounded-md flex items-center gap-2 text-destructive text-sm">
          <AlertCircle className="h-4 w-4" />
          {error}
        </div>
      )}

      {/* Main content */}
      <div className="flex-1 overflow-hidden flex p-6 gap-6">
        {/* Calendar */}
        <div className="flex-1">
          {/* Month navigation */}
          <div className="flex items-center justify-between mb-4">
            <Button variant="ghost" size="sm" onClick={handlePrevMonth}>
              <ChevronLeft className="h-4 w-4" />
            </Button>
            <div className="flex items-center gap-2">
              <h2 className="text-lg font-medium">
                {MONTHS[currentMonth]} {currentYear}
              </h2>
              <Button variant="outline" size="sm" onClick={handleToday}>
                Today
              </Button>
            </div>
            <Button variant="ghost" size="sm" onClick={handleNextMonth}>
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>

          {/* Calendar grid */}
          <div className="border border-border rounded-lg overflow-hidden">
            {/* Weekday headers */}
            <div className="grid grid-cols-7 bg-secondary-solid">
              {WEEKDAYS.map(day => (
                <div key={day} className="p-2 text-center text-sm font-medium text-muted-foreground border-b border-border">
                  {day}
                </div>
              ))}
            </div>

            {/* Days grid */}
            <div className="grid grid-cols-7">
              {calendarDays.map((day, index) => {
                const dayEvents = day ? getEventsForDay(day) : [];
                const hasEvents = dayEvents.length > 0;
                
                return (
                  <button
                    key={index}
                    className={`
                      min-h-[80px] p-1 border-b border-r border-border text-left
                      ${day ? 'hover:bg-secondary cursor-pointer' : 'bg-secondary-solid/30'}
                      ${isToday(day!) ? 'bg-primary/10' : ''}
                      ${isSelected(day!) ? 'bg-primary/20 ring-2 ring-primary ring-inset' : ''}
                    `}
                    onClick={() => day && setSelectedDate(new Date(currentYear, currentMonth, day))}
                    disabled={!day}
                  >
                    {day && (
                      <>
                        <div className={`text-sm font-medium mb-1 ${isToday(day) ? 'text-primary' : ''}`}>
                          {day}
                        </div>
                        {hasEvents && (
                          <div className="space-y-0.5">
                            {dayEvents.slice(0, 2).map((event, i) => (
                              <div 
                                key={i} 
                                className="text-[10px] truncate flex items-center gap-0.5 bg-secondary-solid px-1 rounded"
                              >
                                {EVENT_ICONS[event.type]}
                                <span className="truncate">{event.title}</span>
                              </div>
                            ))}
                            {dayEvents.length > 2 && (
                              <div className="text-[10px] text-muted-foreground">
                                +{dayEvents.length - 2} more
                              </div>
                            )}
                          </div>
                        )}
                      </>
                    )}
                  </button>
                );
              })}
            </div>
          </div>

          {loading && (
            <div className="flex items-center justify-center gap-2 mt-4 text-muted-foreground">
              <Loader2 className="h-4 w-4 animate-spin" />
              <span className="text-sm">Fetching events from Perplexity...</span>
            </div>
          )}
        </div>

        {/* Events panel */}
        <div className="w-80 border border-border rounded-lg overflow-hidden flex flex-col">
          <div className="p-3 bg-secondary-solid border-b border-border">
            <h3 className="font-medium">
              {selectedDate 
                ? selectedDate.toLocaleDateString('en-US', { 
                    weekday: 'long', 
                    month: 'long', 
                    day: 'numeric',
                    year: 'numeric'
                  })
                : 'Select a date'
              }
            </h3>
          </div>
          
          <div className="flex-1 overflow-y-auto p-3">
            {selectedDate ? (
              selectedDateEvents.length > 0 ? (
                <div className="space-y-3">
                  {selectedDateEvents.map((event, index) => (
                    <div 
                      key={index}
                      className="p-3 bg-secondary-solid rounded-lg border border-border"
                    >
                      <div className="flex items-center gap-2 mb-1">
                        {EVENT_ICONS[event.type]}
                        <span className="text-xs text-muted-foreground capitalize">{event.type}</span>
                      </div>
                      <h4 className="font-medium text-sm">{event.title}</h4>
                      {event.description && (
                        <p className="text-xs text-muted-foreground mt-1">{event.description}</p>
                      )}
                    </div>
                  ))}
                </div>
              ) : (
                <div className="flex flex-col items-center justify-center h-full text-muted-foreground">
                  <CalendarIcon className="h-12 w-12 mb-2 opacity-30" />
                  <p className="text-sm">No events on this day</p>
                </div>
              )
            ) : (
              <div className="flex flex-col items-center justify-center h-full text-muted-foreground">
                <CalendarIcon className="h-12 w-12 mb-2 opacity-30" />
                <p className="text-sm">Click a date to view events</p>
              </div>
            )}
          </div>

          {/* Legend */}
          <div className="p-3 border-t border-border bg-secondary-solid/50">
            <p className="text-xs text-muted-foreground mb-2">Event Types:</p>
            <div className="grid grid-cols-2 gap-1 text-xs">
              <div className="flex items-center gap-1">
                {EVENT_ICONS.holiday}
                <span>Holiday</span>
              </div>
              <div className="flex items-center gap-1">
                {EVENT_ICONS.observance}
                <span>Observance</span>
              </div>
              <div className="flex items-center gap-1">
                {EVENT_ICONS.event}
                <span>Event</span>
              </div>
              <div className="flex items-center gap-1">
                {EVENT_ICONS.announcement}
                <span>Announcement</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

