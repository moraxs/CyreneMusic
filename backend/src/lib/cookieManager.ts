import fs from 'fs/promises';
import path from 'path';

export default class CookieManager {
  private cookieFileRoot: string;
  private cookieFileDemo: string;

  constructor(cookieFile: string) {
    this.cookieFileRoot = path.resolve(process.cwd(), 'cookie', cookieFile);
    this.cookieFileDemo = path.resolve(process.cwd(), 'demo', 'cookie', cookieFile);
  }

  async readCookie(): Promise<string> {
    try {
      return await fs.readFile(this.cookieFileRoot, 'utf-8');
    } catch {}
    try {
      return await fs.readFile(this.cookieFileDemo, 'utf-8');
    } catch (error) {
      console.error(`Error reading cookie file ${this.cookieFileRoot} or ${this.cookieFileDemo}:`, error);
      return '';
    }
  }

  async writeCookie(cookieContent: string): Promise<void> {
    try {
      await fs.mkdir(path.dirname(this.cookieFileRoot), { recursive: true });
      await fs.writeFile(this.cookieFileRoot, cookieContent, 'utf-8');
    } catch (error) {
      console.error(`Error writing cookie file ${this.cookieFileRoot}:`, error);
    }
  }

  static parseCookie(text: string): Record<string, string> {
    const cookies: Record<string, string> = {};
    if (!text) return cookies;
    text.split(';').forEach((cookie) => {
      const parts = cookie.match(/(.*?)=(.*)/);
      if (parts) {
        cookies[parts[1].trim()] = (parts[2] || '').trim();
      }
    });
    return cookies;
  }

  static cookieObjectToString(cookieObj: Record<string, string>): string {
    return Object.entries(cookieObj)
      .filter(([key, _]) => key.trim() !== '')
      .map(([key, value]) => `${key}=${value}`)
      .join('; ');
  }
} 