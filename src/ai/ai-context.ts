/**
 * AI Conversation Context - Manages conversation history for follow-up questions
 * 
 * This module provides a simple way to maintain context between AI requests,
 * allowing for more coherent multi-turn conversations.
 */

export interface Message {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: number;
}

export class AIConversationContext {
  private messages: Message[] = [];
  private maxMessages: number;
  
  constructor(maxMessages: number = 10) {
    this.maxMessages = maxMessages;
  }
  
  /**
   * Add a user message to the context
   */
  addUserMessage(content: string): void {
    this.addMessage('user', content);
  }
  
  /**
   * Add an assistant message to the context
   */
  addAssistantMessage(content: string): void {
    this.addMessage('assistant', content);
  }
  
  /**
   * Add a message with a specific role
   */
  private addMessage(role: 'user' | 'assistant', content: string): void {
    this.messages.push({
      role,
      content,
      timestamp: Date.now()
    });
    
    // Trim to max messages, keeping pairs intact
    if (this.messages.length > this.maxMessages) {
      // Remove oldest pair (user + assistant messages)
      this.messages = this.messages.slice(-this.maxMessages);
    }
  }
  
  /**
   * Get all messages in the context
   */
  getMessages(): Message[] {
    return [...this.messages];
  }
  
  /**
   * Get messages formatted for API calls (without timestamp)
   */
  getMessagesForAPI(): { role: 'user' | 'assistant' | 'system'; content: string }[] {
    return this.messages.map(({ role, content }) => ({ role, content }));
  }
  
  /**
   * Clear all messages
   */
  clear(): void {
    this.messages = [];
  }
  
  /**
   * Get the number of messages in context
   */
  getCount(): number {
    return this.messages.length;
  }
  
  /**
   * Check if context is empty
   */
  isEmpty(): boolean {
    return this.messages.length === 0;
  }
  
  /**
   * Get a summary of the context for display
   */
  getSummary(): string {
    const count = this.messages.length;
    if (count === 0) return 'No context';
    const exchanges = Math.floor(count / 2);
    return `${exchanges} exchange${exchanges !== 1 ? 's' : ''}`;
  }
}
