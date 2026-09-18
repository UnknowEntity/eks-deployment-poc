package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	_ "embed"

	"github.com/pelletier/go-toml/v2"
)

type Config struct {
	Title string
	Token TokenConfig `toml:"token"`
}

type TokenConfig struct {
	Value string `toml:"value"`
}

type Server struct {
	Config Config
}

// The handler function handles incoming HTTP requests.
func (s *Server) helloHandler(w http.ResponseWriter, r *http.Request) {
	// Send a simple text response back to the client
	fmt.Fprint(w, "Hello, World! You have reached the Go server (v3).")
}

func (s *Server) tokenHandler(w http.ResponseWriter, r *http.Request) {
	// Send the token value back to the client
	fmt.Fprint(w, s.Config.Token.Value)
}

func healthzHandler(w http.ResponseWriter, r *http.Request) {
	// Send a simple health check response back to the client
	fmt.Fprint(w, "OK")
}

func readyzHandler(w http.ResponseWriter, r *http.Request) {
	// Send a simple readiness check response back to the client
	fmt.Fprint(w, "OK")
}

//go:embed "config/local.config.toml"
var defaultConfigBytes []byte

func main() {
	env := os.Getenv("ENV")
	prodConfigPath := "/etc/secret/server.config.toml"

	var fileBytes []byte
	var err error

	if env == "PROD" {
		fileBytes, err = os.ReadFile(prodConfigPath)
		if err != nil {
			log.Fatalf("Error reading file: %v", err)
		}
	} else {
		fileBytes = defaultConfigBytes
	}

	// 2. Unmarshal the data into the struct
	var config Config
	err = toml.Unmarshal(fileBytes, &config)
	if err != nil {
		log.Fatalf("Error unmarshaling TOML: %v", err)
	}

	// Create a new request multiplexer (router)
	mux := http.NewServeMux()

	// Register the handler function for the root path "/"
	server := &Server{Config: config}
	mux.HandleFunc("/", server.helloHandler)
	mux.HandleFunc("/healthz", healthzHandler)
	mux.HandleFunc("/readyz", readyzHandler)
	mux.HandleFunc("/token", server.tokenHandler)

	// Define the port to listen on
	port := ":8080"
	fmt.Printf("Server is starting and listening on port %s...\n", port)

	// Start the server and log any fatal errors if it fails to start
	if err := http.ListenAndServe(port, mux); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
