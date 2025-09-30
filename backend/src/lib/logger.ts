const colors = {
  reset: "\x1b[0m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  magenta: "\x1b[35m",
};

function getTimestamp() {
  return new Date().toLocaleString('sv');
}

function log(level: string, color: string, message: any, ...args: any[]) {
  const coloredLevel = `[${color}${level.padEnd(5)}${colors.reset}]`;
  const finalMessage = typeof message === 'string' ? message : JSON.stringify(message, null, 2);
  console.log(`${getTimestamp()} ${coloredLevel} -`, finalMessage, ...args);
}

export const logger = {
  info: (message: any, ...args: any[]) => log('INFO', colors.blue, message, ...args),
  dev: (message: any, ...args: any[]) => log('DEV', colors.magenta, message, ...args),
  warn: (message: any, ...args: any[]) => log('WARN', colors.yellow, message, ...args),
  error: (message: any, ...args: any[]) => {
    if (message instanceof Error) {
      log('ERROR', colors.red, message.stack || (message as any).message, ...args);
    } else {
      log('ERROR', colors.red, message, ...args);
    }
  },
  raw: (message: any) => console.log(message),
}; 