import * as React from "react"
import { cn } from "@/lib/utils"

// Define all the steps in order
const RETENTION_STEPS = [
  { value: 0, label: "1 day", days: 1 },
  { value: 1, label: "2 days", days: 2 },
  { value: 2, label: "3 days", days: 3 },
  { value: 3, label: "4 days", days: 4 },
  { value: 4, label: "5 days", days: 5 },
  { value: 5, label: "6 days", days: 6 },
  { value: 6, label: "1 week", days: 7, isKeyPoint: true, keyLabel: "Week" },
  { value: 7, label: "2 weeks", days: 14 },
  { value: 8, label: "3 weeks", days: 21 },
  { value: 9, label: "1 month", days: 30, isKeyPoint: true, keyLabel: "Month" },
  { value: 10, label: "2 months", days: 60 },
  { value: 11, label: "3 months", days: 90 },
  { value: 12, label: "4 months", days: 120 },
  { value: 13, label: "5 months", days: 150 },
  { value: 14, label: "6 months", days: 180 },
  { value: 15, label: "7 months", days: 210 },
  { value: 16, label: "8 months", days: 240 },
  { value: 17, label: "9 months", days: 270 },
  { value: 18, label: "10 months", days: 300 },
  { value: 19, label: "11 months", days: 330 },
  { value: 20, label: "1 year", days: 365, isKeyPoint: true, keyLabel: "Year" },
  { value: 21, label: "Unlimited", days: -1, isKeyPoint: true, keyLabel: "Forever" },
] as const

// Key points for display (these are evenly spaced visually at 25% intervals)
const KEY_POINTS = [
  { value: 0, label: "Day", position: 0 },
  { value: 6, label: "Week", position: 25 },
  { value: 9, label: "Month", position: 50 },
  { value: 20, label: "Year", position: 75 },
  { value: 21, label: "Forever", position: 100 },
]

// Define the segments with their value ranges and position ranges
const SEGMENTS = [
  { startValue: 0, endValue: 6, startPos: 0, endPos: 25 },    // Day to Week: 7 steps
  { startValue: 6, endValue: 9, startPos: 25, endPos: 50 },   // Week to Month: 4 steps
  { startValue: 9, endValue: 20, startPos: 50, endPos: 75 },  // Month to Year: 12 steps
  { startValue: 20, endValue: 21, startPos: 75, endPos: 100 }, // Year to Forever: 2 steps
]

// Map slider value to visual position (0-100)
function getVisualPosition(value: number): number {
  if (value <= 0) return 0
  if (value >= 21) return 100
  
  // Find which segment the value falls into
  for (const segment of SEGMENTS) {
    if (value >= segment.startValue && value <= segment.endValue) {
      const segmentProgress = (value - segment.startValue) / (segment.endValue - segment.startValue)
      const posRange = segment.endPos - segment.startPos
      return segment.startPos + segmentProgress * posRange
    }
  }
  
  return 0
}

// Map visual position (0-100) to slider value
function getValueFromPosition(position: number): number {
  if (position <= 0) return 0
  if (position >= 100) return 21
  
  // Find which segment the position falls into
  for (const segment of SEGMENTS) {
    if (position >= segment.startPos && position <= segment.endPos) {
      const segmentProgress = (position - segment.startPos) / (segment.endPos - segment.startPos)
      const valueRange = segment.endValue - segment.startValue
      const exactValue = segment.startValue + segmentProgress * valueRange
      
      // Round to nearest integer value (step)
      return Math.round(exactValue)
    }
  }
  
  return 0
}

interface RetentionPeriodSliderProps {
  value?: number
  onValueChange?: (value: number) => void
  className?: string
}

export function RetentionPeriodSlider({
  value = 0,
  onValueChange,
  className,
}: RetentionPeriodSliderProps) {
  const trackRef = React.useRef<HTMLDivElement>(null)
  const [isDragging, setIsDragging] = React.useState(false)

  const currentStep = RETENTION_STEPS[value]
  const visualPosition = getVisualPosition(value)
  
  // Adjust thumb transform to prevent overflow at edges
  // At 0%: no transform (left edge aligns), at 100%: -100% (right edge aligns), in between: -50% (centered)
  const getThumbTransform = (position: number) => {
    if (position === 0) return "translateX(0%)"
    if (position === 100) return "translateX(-100%)"
    return "translateX(-50%)"
  }

  const updateValueFromEvent = React.useCallback(
    (clientX: number) => {
      if (!trackRef.current) return

      const rect = trackRef.current.getBoundingClientRect()
      const position = ((clientX - rect.left) / rect.width) * 100
      const clampedPosition = Math.max(0, Math.min(100, position))
      const newValue = getValueFromPosition(clampedPosition)

      if (newValue !== value && onValueChange) {
        onValueChange(newValue)
      }
    },
    [value, onValueChange]
  )

  const handleMouseDown = React.useCallback(
    (e: React.MouseEvent<HTMLDivElement>) => {
      setIsDragging(true)
      updateValueFromEvent(e.clientX)
    },
    [updateValueFromEvent]
  )

  const handleTouchStart = React.useCallback(
    (e: React.TouchEvent<HTMLDivElement>) => {
      setIsDragging(true)
      updateValueFromEvent(e.touches[0].clientX)
    },
    [updateValueFromEvent]
  )

  React.useEffect(() => {
    if (!isDragging) return

    const handleMouseMove = (e: MouseEvent) => {
      updateValueFromEvent(e.clientX)
    }

    const handleTouchMove = (e: TouchEvent) => {
      updateValueFromEvent(e.touches[0].clientX)
    }

    const handleEnd = () => {
      setIsDragging(false)
    }

    document.addEventListener("mousemove", handleMouseMove)
    document.addEventListener("touchmove", handleTouchMove)
    document.addEventListener("mouseup", handleEnd)
    document.addEventListener("touchend", handleEnd)

    return () => {
      document.removeEventListener("mousemove", handleMouseMove)
      document.removeEventListener("touchmove", handleTouchMove)
      document.removeEventListener("mouseup", handleEnd)
      document.removeEventListener("touchend", handleEnd)
    }
  }, [isDragging, updateValueFromEvent])

  // Keyboard support
  const handleKeyDown = React.useCallback(
    (e: React.KeyboardEvent) => {
      let newValue = value
      
      switch (e.key) {
        case "ArrowLeft":
        case "ArrowDown":
          newValue = Math.max(0, value - 1)
          e.preventDefault()
          break
        case "ArrowRight":
        case "ArrowUp":
          newValue = Math.min(21, value + 1)
          e.preventDefault()
          break
        case "Home":
          newValue = 0
          e.preventDefault()
          break
        case "End":
          newValue = 21
          e.preventDefault()
          break
      }
      
      if (newValue !== value && onValueChange) {
        onValueChange(newValue)
      }
    },
    [value, onValueChange]
  )

  return (
    <div className={cn("w-full space-y-4", className)}>
      {/* Labels above the slider */}
      <div className="relative h-5 px-2.5">
        {KEY_POINTS.map((point) => {
          // First label (Day) aligns left, last label (Forever) aligns right, others center
          let transform = "translateX(-50%)"
          if (point.position === 0) {
            transform = "translateX(0%)"
          } else if (point.position === 100) {
            transform = "translateX(-100%)"
          }
          
          return (
            <div
              key={point.value}
              className="absolute text-sm font-medium text-foreground"
              style={{
                left: `${point.position}%`,
                transform,
              }}
            >
              {point.label}
            </div>
          )
        })}
      </div>

      {/* Custom slider */}
      <div
        ref={trackRef}
        className="relative h-2 w-full cursor-pointer select-none touch-none"
        onMouseDown={handleMouseDown}
        onTouchStart={handleTouchStart}
        role="slider"
        aria-valuemin={0}
        aria-valuemax={21}
        aria-valuenow={value}
        aria-valuetext={currentStep?.label}
        tabIndex={0}
        onKeyDown={handleKeyDown}
      >
        {/* Track background */}
        <div className="absolute top-1/2 left-0 right-0 h-1.5 -translate-y-1/2 rounded-full bg-slider-track-background" />
        
        {/* Filled range */}
        <div
          className="absolute top-1/2 left-0 h-1.5 -translate-y-1/2 rounded-full bg-slider-track-filled"
          style={{ width: `${visualPosition}%` }}
        />
        
        {/* Step dots */}
        {RETENTION_STEPS.map((step) => {
          const dotPosition = getVisualPosition(step.value)
          // Align dots like the thumb: first dot left-aligned, last dot right-aligned, others centered
          let dotTransform = "translate(-50%, -50%)"
          let leftPosition = `${dotPosition}%`
          
          if (dotPosition === 0) {
            dotTransform = "translate(0%, -50%)"
            leftPosition = "calc(0% + 2px)" // Move first dot 2px to the right
          } else if (dotPosition === 100) {
            dotTransform = "translate(-100%, -50%)"
            leftPosition = "calc(100% - 2px)" // Move last dot 2px to the left
          }
          
          // Color dots based on whether they're in the filled part
          const isFilled = dotPosition <= visualPosition
          const dotColor = isFilled ? "bg-slider-dot-background-filled" : "bg-slider-dot-background"
          
          return (
            <div
              key={step.value}
              className={cn("absolute top-1/2 w-1 h-1 rounded-full pointer-events-none", dotColor)}
              style={{ 
                left: leftPosition,
                transform: dotTransform
              }}
            />
          )
        })}
        
        {/* Thumb */}
        <div
          className={cn(
            "absolute top-1/2 -translate-y-1/2",
            "h-4 w-4 rounded-full border-2 border-slider-thumb-border bg-slider-thumb-background",
            "ring-offset-background",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
            isDragging && "scale-110"
          )}
          style={{ 
            left: `${visualPosition}%`,
            transform: `translateY(-50%) ${getThumbTransform(visualPosition)}`
          }}
        />
      </div>

      {/* Current selection display */}
      <div className="text-center text-sm text-neutral-500">
        {currentStep?.label}
      </div>
    </div>
  )
}

export { RETENTION_STEPS }
