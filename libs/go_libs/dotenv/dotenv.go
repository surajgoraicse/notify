package dotenv

import (
	"os"
	"strconv"
)

func GetEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func GetEnvNumberOrDefault(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		val, err := strconv.Atoi(value)
		if err != nil {
			return defaultValue
		}
		return val
	}
	return defaultValue
}

func GetEnv(key string) string {
	if os.Getenv(key) == "" {
		panic("environment variable " + key + " is not set")
	}
	return os.Getenv(key)
}

func GetEnvNumber(key string) int {
	value := os.Getenv(key)
	if value == "" {
		panic("environment variable " + key + " is not set")
	}
	val, err := strconv.Atoi(value)
	if err != nil {
		panic("environment variable " + key + " is not set")
	}
	return val
}
