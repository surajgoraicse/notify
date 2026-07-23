package container

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/surajgoraicse/notify/libs/go_libs/database"
	"github.com/surajgoraicse/notify/libs/go_libs/logger"
	"github.com/surajgoraicse/notify/services/notification/internal/config"
	"go.uber.org/zap"
)

type Container struct {
	Config  *config.Config
	Logger  *zap.Logger
	DBPool  *pgxpool.Pool
	Queries *db_sqlc.Queries
}

func NewContainer(ctx context.Context, config *config.Config) (*Container, error) {
	// initialize the logger
	logger, err := logger.InitLogger(config.ServiceName, config.Environment)
	if err != nil {
		log.Fatalf("Failed to initialize logger: %v\n", err)
	}

	// initialize the database
	dbConfig := getDbConfig(config)
	db := database.NewDatabaseService(dbConfig, logger)
	dbPool, err := db.Connect(ctx)
	if err != nil {
		logger.Fatal("Failed to connect to database: %v", zap.Error(err))
	}
	// queries := db_sqlc.New(dbPool)

	return &Container{
		Config: config,
		Logger: logger,
		DBPool: dbPool,
	}, nil
}

func (c *Container) Close() {
	logger.Flush()
}

// getDbConfig returns the database configuration for the scheduler service.
func getDbConfig(config *config.Config) *database.DbConfig {
	return &database.DbConfig{
		DBHost:                config.DBHost,
		DBPort:                fmt.Sprintf("%d", config.DBPort),
		DBUser:                config.DBUser,
		DBPassword:            config.DBPassword,
		DBName:                config.DBName,
		DBSchema:              config.DBSchema,
		SSLMode:               config.DBSSLMode,
		DBMaxConn:             10,
		DBMinConn:             1,
		DBConnMaxLifetime:     10 * time.Minute,
		DBConnMaxIdleLifetime: 5 * time.Minute,
		DBHealthCheckPeriod:   1 * time.Minute,
		ConnectTimeout:        5 * time.Second,
	}
}
