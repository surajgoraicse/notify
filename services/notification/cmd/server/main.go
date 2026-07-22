package main

import (
	"context"
	"log"

	"github.com/surajgoraicse/notify/services/notification/internal/config"
	"github.com/surajgoraicse/notify/services/notification/internal/container"
)

func main() {
	cfg := config.NewConfig()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	di, err := container.NewContainer(ctx, cfg)
	if err != nil {
		log.Fatal("failed to create container: " + err.Error())
	}
	defer di.Close()

	

}
