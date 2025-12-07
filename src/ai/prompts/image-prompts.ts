/**
 * Image Action Prompts - For vision/image analysis
 * 
 * These prompts are used with GPT-4o for analyzing images
 * in the clipboard history.
 */

export interface ImageAction {
  id: string;
  label: string;
  description: string;
  prompt: string;
  maxTokens?: number;
}

export const IMAGE_ACTIONS: ImageAction[] = [
  {
    id: 'describeImage',
    label: 'Describe Image',
    description: 'Get a detailed description',
    prompt: 'Describe this image in detail. What do you see? Be specific about objects, text, colors, and layout.',
    maxTokens: 1000,
  },
  {
    id: 'extractText',
    label: 'Extract Text',
    description: 'Extract all visible text',
    prompt: 'Extract ALL text visible in this image. Return only the text content, preserving the original formatting and line breaks where possible. If there is no text, say "No text found."',
    maxTokens: 2000,
  },
  {
    id: 'analyzeContent',
    label: 'Analyze Content',
    description: 'Understand the context',
    prompt: 'Analyze this image. What is it showing? What is the context or purpose? Provide insights about the content.',
    maxTokens: 1500,
  },
  {
    id: 'summarizeDocument',
    label: 'Summarize Document',
    description: 'Summarize document or screenshot',
    prompt: 'This appears to be a document, screenshot, or text content. Summarize the key information in bullet points. Focus on the main topics and important details.',
    maxTokens: 1000,
  },
  {
    id: 'extractData',
    label: 'Extract Data',
    description: 'Extract structured data',
    prompt: 'Extract any structured data from this image (tables, lists, forms, etc). Format the output in a clear, organized way. If it\'s a table, try to preserve the structure.',
    maxTokens: 2000,
  },
  {
    id: 'explainDiagram',
    label: 'Explain Diagram',
    description: 'Explain charts or diagrams',
    prompt: 'Explain this diagram, chart, or visualization. What does it represent? What are the key takeaways or insights?',
    maxTokens: 1500,
  },
];

export function getImageActionById(id: string): ImageAction | undefined {
  return IMAGE_ACTIONS.find(action => action.id === id);
}

export function getImageActionPrompt(id: string): string {
  const action = getImageActionById(id);
  return action?.prompt || IMAGE_ACTIONS[0].prompt;
}
