package config

import "github.com/surajgoraicse/notify/libs/go_libs/dotenv"

type Config struct {
	ServiceName string
	Environment string
	Port        int
}

func NewConfig() *Config {
	return &Config{
		ServiceName: dotenv.GetEnvOrDefault("SERVICE_NAME", "notification"),
		Environment: dotenv.GetEnvOrDefault("ENVIRONMENT", "dev"),
		Port:        dotenv.GetEnvNumberOrDefault("PORT", 8080),
	}
}
