/**
 * Cryptographic and random generation utilities
 */

/**
 * Generate a UUID v4 (random UUID)
 * @returns A random UUID string in the format xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
 */
export function generateUUID(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

/**
 * Generate a secure random password
 * @param length The length of the password (default: 16)
 * @returns A random password string
 */
export function generatePassword(length: number = 16): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
  const array = new Uint32Array(length);
  crypto.getRandomValues(array);
  return Array.from(array, (n) => chars[n % chars.length]).join('');
}

/**
 * Generate random hexadecimal bytes
 * @param bytes Number of bytes (default: 32)
 * @returns A hexadecimal string
 */
export function generateHex(bytes: number = 32): string {
  const array = new Uint8Array(bytes);
  crypto.getRandomValues(array);
  return Array.from(array, (b) => b.toString(16).padStart(2, '0')).join('');
}
