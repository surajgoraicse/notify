package logger

import (
	"context"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

// Define a unique private context key to avoid collisions
type ctxKey struct{}

var loggerKey = ctxKey{}

// GlobalLogger holds the base logger instance for fallback or background jobs
var GlobalLogger *zap.Logger

// InitLogger boots up a highly optimized production logger configuration
func InitLogger(serviceName, env string) (*zap.Logger, error) {
	switch env {
	case "production", "prod":
		env = "prod"
	case "development", "dev":
		env = "dev"
	default:
		env = "dev"
	}

	// 1. Define standard core metadata attached to EVERY log line
	staticFields := map[string]any{
		"service_id": serviceName,
		// "service_version": version,
		"environment": env,
	}

	config := zap.Config{
		Level:            zap.NewAtomicLevelAt(zap.InfoLevel),
		Development:      false,
		Encoding:         "json",
		OutputPaths:      []string{"stdout"},
		ErrorOutputPaths: []string{"stderr"},
		InitialFields:    staticFields,
		EncoderConfig: zapcore.EncoderConfig{
			TimeKey:        "timestamp",
			LevelKey:       "level",
			MessageKey:     "message",
			CallerKey:      "caller",
			LineEnding:     zapcore.DefaultLineEnding,
			EncodeTime:     zapcore.ISO8601TimeEncoder, // Outputs dynamic UTC ISO8601
			EncodeLevel:    zapcore.LowercaseLevelEncoder,
			EncodeCaller:   zapcore.ShortCallerEncoder,
			EncodeDuration: zapcore.MillisDurationEncoder,
		},
	}

	logger, err := config.Build(
		zap.AddCaller(),                       // Automatically includes file and line number
		zap.AddStacktrace(zapcore.ErrorLevel), // Automatically captures stack trace on ERROR or higher
	)
	if err != nil {
		return nil, err
	}

	GlobalLogger = logger
	return logger, nil
}

// Flush forces any buffered log entries to write to stdout/stderr. Call this on app shutdown.
func Flush() {
	if GlobalLogger != nil {
		_ = GlobalLogger.Sync()
	}
}

// WithContext stores a request-scoped logger (with trace IDs attached) inside the context
func WithContext(ctx context.Context, logger *zap.Logger) context.Context {
	return context.WithValue(ctx, loggerKey, logger)
}

// FromContext extracts the request-scoped logger. Falls back to GlobalLogger if missing.
func FromContext(ctx context.Context) *zap.Logger {
	if ctx == nil {
		return GlobalLogger
	}
	if logger, ok := ctx.Value(loggerKey).(*zap.Logger); ok {
		return logger
	}
	return GlobalLogger
}
