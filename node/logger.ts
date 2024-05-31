import  *  as  winston  from  'winston';
import DailyRotateFile from 'winston-daily-rotate-file';

// 按天分割日志文件
const dailyRotateFileTransport = new DailyRotateFile({
  level: 'info',
  filename: './logs/log-%DATE%.log',
  datePattern: 'YYYY-MM-DD',
  zippedArchive: true,
  maxSize: '20m',
  maxFiles: '14d',
  createSymlink: true,
  symlinkName: 'log-current.log',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.metadata(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
});

// 单独存储错误日志
const errorTransport = new DailyRotateFile({
  level: 'error',
  filename: './logs/error-%DATE%.log',
  datePattern: 'YYYY-MM-DD',
  zippedArchive: true,
  maxSize: '20m',
  maxFiles: '30d',
  createSymlink: true,
  symlinkName: 'error-current.log',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.metadata(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
});

const consoleTransport = new winston.transports.Console({
  level: 'debug',
  format: winston.format.combine(
    winston.format.colorize(),
    winston.format.simple(),
    winston.format.timestamp(),
    winston.format.metadata(),
  )
});


export const logger = winston.createLogger({
  level: "debug",
  transports: [
    dailyRotateFileTransport,
    errorTransport,
    consoleTransport
  ],
});
