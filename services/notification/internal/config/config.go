package config

import "github.com/surajgoraicse/notify/libs/go_libs/dotenv"

type Config struct {
	ServiceName string
	Environment string
	Port        int

	// Database
	DBHost     string
	DBPort     int
	DBUser     string
	DBPassword string
	DBName     string
	DBSchema   string
	DBSSLMode  string
}

func NewConfig() *Config {
	return &Config{
		ServiceName: dotenv.GetEnvOrDefault("SERVICE_NAME", "notification"),
		Environment: dotenv.GetEnvOrDefault("ENVIRONMENT", "dev"),
		Port:        dotenv.GetEnvNumberOrDefault("PORT", 8080),

		// Database
		DBHost:     dotenv.GetEnvOrDefault("DB_HOST", "localhost"),
		DBPort:     dotenv.GetEnvNumberOrDefault("DB_PORT", 5432),
		DBUser:     dotenv.GetEnvOrDefault("DB_USER", "postgres"),
		DBPassword: dotenv.GetEnvOrDefault("DB_PASSWORD", ""),
		DBName:     dotenv.GetEnvOrDefault("DB_NAME", "notification"),
		DBSchema:   dotenv.GetEnvOrDefault("DB_SCHEMA", "public"),
		DBSSLMode:  dotenv.GetEnvOrDefault("DB_SSL_MODE", "disable"),
	}
}
