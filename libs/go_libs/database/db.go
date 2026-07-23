package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type DbConfig struct {
	DBHost                string
	DBPort                string
	DBUser                string
	DBPassword            string
	DBName                string
	DBSchema              string
	SSLMode               string
	DBMaxConn             int32
	DBMinConn             int32
	DBConnMaxLifetime     time.Duration
	DBConnMaxIdleLifetime time.Duration
	DBHealthCheckPeriod   time.Duration
	ConnectTimeout        time.Duration
}

type DatabaseService struct {
	dbConfig DbConfig
	logger   *zap.Logger
}

func NewDatabaseService(cfg *DbConfig, logger *zap.Logger) *DatabaseService {
	return &DatabaseService{
		dbConfig: *cfg,
		logger:   logger,
	}
}

func (ds *DatabaseService) Connect(ctx context.Context) (*pgxpool.Pool, error) {
	dbConfig, err := ds.withPgxConfig()
	if err != nil {
		return nil, fmt.Errorf("error parsing database configuration: %v", err)
	}

	db, err := pgxpool.NewWithConfig(context.Background(), dbConfig)
	if err != nil {
		return nil, fmt.Errorf("error connecting to database: %v", err)
	}

	connectDeadline := time.Now().Add(8 * time.Second)
	ds.logger.Info("Database connection attempt")
	for {
		err = db.Ping(ctx)
		if err == nil {
			ds.logger.Info("Successfully Pinged the database")
			ds.logger.Info("Database connection successful")
			return db, nil
		}

		if time.Now().After(connectDeadline) {
			db.Close()
			return nil, fmt.Errorf("error pinging database: %v", err)
		}

		select {
		case <-ctx.Done():
			db.Close()
			return nil, fmt.Errorf("context cancelled: %v", ctx.Err())
		case <-time.After(2000 * time.Millisecond):
			ds.logger.Info("Failed to connect to database, retrying...")
		}
	}
}

func (ds *DatabaseService) withPgxConfig() (*pgxpool.Config, error) {
	dbURLConfig, err := ds.loadDBConnectionConfig()
	if err != nil {
		return nil, fmt.Errorf("error loading database connection config: %v", err)
	}

	dbURL := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s", dbURLConfig.DBHost, dbURLConfig.DBPort, dbURLConfig.DBUser, dbURLConfig.DBPassword, dbURLConfig.DBName, dbURLConfig.SSLMode)

	dbConfig, err := pgxpool.ParseConfig(dbURL)
	if err != nil {
		return nil, fmt.Errorf("error parsing database URL: %v", err)
	}

	dbConfig.MaxConns = dbURLConfig.DBMaxConn
	dbConfig.MinConns = dbURLConfig.DBMinConn
	dbConfig.MaxConnLifetime = dbURLConfig.DBConnMaxLifetime
	dbConfig.MaxConnIdleTime = dbURLConfig.DBConnMaxIdleLifetime
	dbConfig.HealthCheckPeriod = dbURLConfig.DBHealthCheckPeriod
	dbConfig.ConnConfig.ConnectTimeout = dbURLConfig.ConnectTimeout

	// Ensure all connections use the configured application schema by default.
	if dbConfig.ConnConfig.RuntimeParams == nil {
		dbConfig.ConnConfig.RuntimeParams = make(map[string]string)
	}
	schema := dbURLConfig.DBSchema
	if schema == "" {
		schema = dbURLConfig.DBName
	}
	dbConfig.ConnConfig.RuntimeParams["search_path"] = fmt.Sprintf("%s,public", schema)

	return dbConfig, nil
}

func (ds *DatabaseService) loadDBConnectionConfig() (*DbConfig, error) {
	return &DbConfig{
		DBHost:                ds.dbConfig.DBHost,
		DBPort:                ds.dbConfig.DBPort,
		DBUser:                ds.dbConfig.DBUser,
		DBPassword:            ds.dbConfig.DBPassword,
		DBName:                ds.dbConfig.DBName,
		DBSchema:              ds.dbConfig.DBSchema,
		SSLMode:               ds.dbConfig.SSLMode,
		DBMaxConn:             ds.dbConfig.DBMaxConn,
		DBMinConn:             ds.dbConfig.DBMinConn,
		DBConnMaxLifetime:     ds.dbConfig.DBConnMaxLifetime,
		DBConnMaxIdleLifetime: ds.dbConfig.DBConnMaxIdleLifetime,
		DBHealthCheckPeriod:   ds.dbConfig.DBHealthCheckPeriod,
		ConnectTimeout:        ds.dbConfig.ConnectTimeout,
	}, nil
}
