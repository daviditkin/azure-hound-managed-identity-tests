package main

import (
	"context"
	"test-managed-identity/client/config"
	foo "github.com/bloodhoundad/azurehound/v2/config"
	"github.com/bloodhoundad/azurehound/v2/logger"
	"github.com/go-logr/logr"
	"test-managed-identity/client/rest"
)

// TIP To run your code, right-click the code and select <b>Run</b>. Alternatively, click
// the <icon src="AllIcons.Actions.Execute"/> icon in the gutter and select the <b>Run</b> menu item from here.
var log logr.Logger

func setupLogger() {
	if logger, err := logger.GetLogger(); err != nil {
		panic(err)
	} else {
		log = *logger
	}
}

func main() {
	foo.JsonLogs.Set(true)
	setupLogger()
	log.Info("starting azurehound service...")
	// "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net"
	// ManagedIdentity: "",
	c := config.Config{
		// Put stuff here
	}
	client, err := rest.NewRestClient("https://graph.microsoft.com", c)
	if err != nil {
		return
	}
	_, err = client.Get(context.TODO(), "/foo", nil, nil)
	if err != nil {
		log.Error(err, "failed to get foo")
	}
}