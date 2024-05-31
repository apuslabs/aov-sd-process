import winston from "winston";
import "winston-daily-rotate-file";

// 按天分割日志文件
const dailyRotateFileTransport = new winston.transports.DailyRotateFile({
  level: 'info',
  filename: './logs/log-%DATE%.log',
  datePattern: 'YYYY-MM-DD',
  zippedArchive: true,
  maxSize: '20m',
  maxFiles: '14d',
  createSymlink: true,
  symlinkName: 'log-current.log'
});

// 单独存储错误日志
const errorTransport = new winston.transports.DailyRotateFile({
  level: 'error',
  filename: './logs/error-%DATE%.log',
  datePattern: 'YYYY-MM-DD',
  zippedArchive: true,
  maxSize: '20m',
  maxFiles: '30d',
  createSymlink: true,
  symlinkName: 'error-current.log'
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
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.metadata(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  transports: [
    dailyRotateFileTransport,
    errorTransport,
    consoleTransport
  ],
});
