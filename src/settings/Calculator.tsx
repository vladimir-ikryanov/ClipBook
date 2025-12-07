import * as React from "react";
import { useState, useEffect, useCallback } from "react";
import { Button } from "@/components/ui/button";
import { 
  Calculator as CalculatorIcon, 
  Delete, 
  Divide, 
  X, 
  Minus, 
  Plus, 
  Equal,
  Percent,
  RotateCcw,
  Copy,
  CheckIcon,
} from "lucide-react";
import { useTranslation } from 'react-i18next';

declare const closeSettingsWindow: () => void;

export default function Calculator() {
  const { t } = useTranslation();
  
  const [display, setDisplay] = useState('0');
  const [previousValue, setPreviousValue] = useState<number | null>(null);
  const [operation, setOperation] = useState<string | null>(null);
  const [waitingForOperand, setWaitingForOperand] = useState(false);
  const [history, setHistory] = useState<string[]>([]);
  const [copied, setCopied] = useState(false);

  // Handle keyboard input
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        closeSettingsWindow();
        e.preventDefault();
        return;
      }

      // Numbers
      if (/^[0-9]$/.test(e.key)) {
        inputDigit(e.key);
        e.preventDefault();
      }
      // Decimal point
      else if (e.key === '.') {
        inputDot();
        e.preventDefault();
      }
      // Operations
      else if (e.key === '+') {
        performOperation('+');
        e.preventDefault();
      }
      else if (e.key === '-') {
        performOperation('-');
        e.preventDefault();
      }
      else if (e.key === '*') {
        performOperation('×');
        e.preventDefault();
      }
      else if (e.key === '/') {
        performOperation('÷');
        e.preventDefault();
      }
      else if (e.key === '%') {
        inputPercent();
        e.preventDefault();
      }
      // Enter/Equal
      else if (e.key === 'Enter' || e.key === '=') {
        performEquals();
        e.preventDefault();
      }
      // Backspace
      else if (e.key === 'Backspace') {
        backspace();
        e.preventDefault();
      }
      // Clear
      else if (e.key === 'c' || e.key === 'C') {
        clearAll();
        e.preventDefault();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [display, previousValue, operation, waitingForOperand]);

  const clearAll = () => {
    setDisplay('0');
    setPreviousValue(null);
    setOperation(null);
    setWaitingForOperand(false);
  };

  const backspace = () => {
    if (waitingForOperand) return;
    if (display.length === 1 || (display.length === 2 && display[0] === '-')) {
      setDisplay('0');
    } else {
      setDisplay(display.slice(0, -1));
    }
  };

  const inputDigit = (digit: string) => {
    if (waitingForOperand) {
      setDisplay(digit);
      setWaitingForOperand(false);
    } else {
      setDisplay(display === '0' ? digit : display + digit);
    }
  };

  const inputDot = () => {
    if (waitingForOperand) {
      setDisplay('0.');
      setWaitingForOperand(false);
      return;
    }
    if (!display.includes('.')) {
      setDisplay(display + '.');
    }
  };

  const toggleSign = () => {
    const value = parseFloat(display);
    setDisplay(String(-value));
  };

  const inputPercent = () => {
    const value = parseFloat(display);
    if (previousValue !== null) {
      // Calculate percentage of previous value
      setDisplay(String((previousValue * value) / 100));
    } else {
      setDisplay(String(value / 100));
    }
  };

  const performOperation = (nextOperation: string) => {
    const inputValue = parseFloat(display);

    if (previousValue === null) {
      setPreviousValue(inputValue);
    } else if (operation) {
      const currentValue = previousValue;
      const newValue = calculate(currentValue, inputValue, operation);
      
      setDisplay(String(newValue));
      setPreviousValue(newValue);
    }

    setWaitingForOperand(true);
    setOperation(nextOperation);
  };

  const calculate = (left: number, right: number, op: string): number => {
    switch (op) {
      case '+':
        return left + right;
      case '-':
        return left - right;
      case '×':
        return left * right;
      case '÷':
        return right !== 0 ? left / right : NaN;
      default:
        return right;
    }
  };

  const performEquals = () => {
    if (operation === null || previousValue === null) return;

    const inputValue = parseFloat(display);
    const result = calculate(previousValue, inputValue, operation);
    
    // Add to history
    const historyEntry = `${previousValue} ${operation} ${inputValue} = ${result}`;
    setHistory(prev => [historyEntry, ...prev].slice(0, 10));
    
    setDisplay(String(result));
    setPreviousValue(null);
    setOperation(null);
    setWaitingForOperand(true);
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(display);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const formatDisplay = (value: string) => {
    const num = parseFloat(value);
    if (isNaN(num)) return 'Error';
    if (!isFinite(num)) return '∞';
    
    // Format with thousand separators for display
    if (value.includes('.')) {
      const [int, dec] = value.split('.');
      return `${parseInt(int).toLocaleString()}.${dec}`;
    }
    return parseInt(value).toLocaleString();
  };

  // Button component
  const CalcButton = ({ 
    children, 
    onClick, 
    variant = 'default',
    span = 1,
  }: { 
    children: React.ReactNode; 
    onClick: () => void; 
    variant?: 'default' | 'operation' | 'function' | 'equals';
    span?: number;
  }) => {
    const baseClasses = "h-14 text-lg font-medium rounded-lg transition-all active:scale-95";
    const variantClasses = {
      default: "bg-secondary hover:bg-secondary/80",
      operation: "bg-primary/20 hover:bg-primary/30 text-primary",
      function: "bg-secondary-solid hover:bg-secondary text-muted-foreground",
      equals: "bg-primary hover:bg-primary/90 text-primary-foreground",
    };

    return (
      <button
        className={`${baseClasses} ${variantClasses[variant]} ${span === 2 ? 'col-span-2' : ''}`}
        onClick={onClick}
      >
        {children}
      </button>
    );
  };

  return (
    <div className="flex flex-col h-screen">
      {/* Header */}
      <div className="px-6 py-4 border-b border-border draggable">
        <div className="flex items-center gap-2">
          <CalculatorIcon className="h-5 w-5 text-primary" />
          <h1 className="text-lg font-semibold">
            {t('settings.calculator.title', { defaultValue: 'Calculator' })}
          </h1>
        </div>
        <p className="text-sm text-muted-foreground mt-1">
          {t('settings.calculator.description', { defaultValue: 'Quick calculations - use keyboard or click buttons' })}
        </p>
      </div>

      {/* Main content */}
      <div className="flex-1 overflow-hidden flex p-6 gap-6">
        {/* Calculator */}
        <div className="w-80">
          {/* Display */}
          <div className="bg-secondary-solid rounded-xl p-4 mb-4">
            {/* Operation indicator */}
            <div className="text-right text-sm text-muted-foreground h-5 mb-1">
              {previousValue !== null && operation && (
                <span>{previousValue} {operation}</span>
              )}
            </div>
            {/* Main display */}
            <div className="flex items-center justify-between">
              <Button 
                variant="ghost" 
                size="sm" 
                onClick={handleCopy}
                className="h-8 px-2"
              >
                {copied ? (
                  <CheckIcon className="h-4 w-4 text-green-500" />
                ) : (
                  <Copy className="h-4 w-4" />
                )}
              </Button>
              <div className="text-right text-3xl font-semibold truncate flex-1 ml-2">
                {formatDisplay(display)}
              </div>
            </div>
          </div>

          {/* Buttons grid */}
          <div className="grid grid-cols-4 gap-2">
            {/* Row 1 */}
            <CalcButton onClick={clearAll} variant="function">AC</CalcButton>
            <CalcButton onClick={toggleSign} variant="function">±</CalcButton>
            <CalcButton onClick={inputPercent} variant="function">
              <Percent className="h-5 w-5 mx-auto" />
            </CalcButton>
            <CalcButton onClick={() => performOperation('÷')} variant="operation">
              <Divide className="h-5 w-5 mx-auto" />
            </CalcButton>

            {/* Row 2 */}
            <CalcButton onClick={() => inputDigit('7')}>7</CalcButton>
            <CalcButton onClick={() => inputDigit('8')}>8</CalcButton>
            <CalcButton onClick={() => inputDigit('9')}>9</CalcButton>
            <CalcButton onClick={() => performOperation('×')} variant="operation">
              <X className="h-5 w-5 mx-auto" />
            </CalcButton>

            {/* Row 3 */}
            <CalcButton onClick={() => inputDigit('4')}>4</CalcButton>
            <CalcButton onClick={() => inputDigit('5')}>5</CalcButton>
            <CalcButton onClick={() => inputDigit('6')}>6</CalcButton>
            <CalcButton onClick={() => performOperation('-')} variant="operation">
              <Minus className="h-5 w-5 mx-auto" />
            </CalcButton>

            {/* Row 4 */}
            <CalcButton onClick={() => inputDigit('1')}>1</CalcButton>
            <CalcButton onClick={() => inputDigit('2')}>2</CalcButton>
            <CalcButton onClick={() => inputDigit('3')}>3</CalcButton>
            <CalcButton onClick={() => performOperation('+')} variant="operation">
              <Plus className="h-5 w-5 mx-auto" />
            </CalcButton>

            {/* Row 5 */}
            <CalcButton onClick={() => inputDigit('0')} span={2}>0</CalcButton>
            <CalcButton onClick={inputDot}>.</CalcButton>
            <CalcButton onClick={performEquals} variant="equals">
              <Equal className="h-5 w-5 mx-auto" />
            </CalcButton>
          </div>

          {/* Keyboard hint */}
          <p className="text-xs text-muted-foreground text-center mt-4">
            Use keyboard: 0-9, +, -, *, /, %, Enter, Backspace, C
          </p>
        </div>

        {/* History panel */}
        <div className="flex-1 border border-border rounded-lg overflow-hidden flex flex-col">
          <div className="p-3 bg-secondary-solid border-b border-border flex items-center justify-between">
            <h3 className="font-medium">History</h3>
            {history.length > 0 && (
              <Button 
                variant="ghost" 
                size="sm" 
                onClick={() => setHistory([])}
                className="h-7 px-2 text-xs"
              >
                <RotateCcw className="h-3 w-3 mr-1" />
                Clear
              </Button>
            )}
          </div>
          <div className="flex-1 overflow-y-auto p-3">
            {history.length > 0 ? (
              <div className="space-y-2">
                {history.map((entry, index) => (
                  <div 
                    key={index}
                    className="p-2 bg-secondary-solid rounded-md text-sm font-mono"
                  >
                    {entry}
                  </div>
                ))}
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center h-full text-muted-foreground">
                <CalculatorIcon className="h-12 w-12 mb-2 opacity-30" />
                <p className="text-sm">No calculations yet</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

