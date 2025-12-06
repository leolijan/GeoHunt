package server

import (
	mw "GeoHunt/server/middleware"
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"time"
)

type JsonMessage struct {
	Message string `json:"message"`
}

func addRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /GenerateGame", generateGame)
	mux.HandleFunc("GET /GuessLocation", guessLocation)
	mux.HandleFunc("POST /Login", login)
	mux.HandleFunc("GET /GiveUp", giveUp)
	mux.HandleFunc("GET /UpdateLeaderboard", updateLeaderboard)
	mux.HandleFunc("POST /UpdateDisplayName", updateDisplayName)
	mux.HandleFunc("POST /AnswerFriendRequest", answerFriendRequest)
	mux.HandleFunc("POST /SendFriendRequest", sendFriendRequest)
	mux.HandleFunc("GET /GetFriendRequests", getFriendRequests)
	mux.HandleFunc("GET /GetFriendList", getFriendList)
	mux.HandleFunc("POST /RemoveFriend", removeFriend)
	mux.HandleFunc("GET /GetHint", getHint)

	mux.Handle("/", http.NotFoundHandler())
}

// Returns the handler containing all defined routes/endpoints, including
// middleware handlers
func NewServer() http.Handler {
	mux := http.NewServeMux()
	addRoutes(mux)

	var handler http.Handler = mux
	//middleware kan läggas till genom "handler = middleware(handler)"

	handler = mw.AuthenticationHandler(handler)
	handler = mw.LoggingMiddleware(handler)
	return handler
}

// Static. To be run concurrently when setting up server. Makes a given HTTP server listen.
func serverListen(httpserver *http.Server) {
	log.Printf("listening on %s\n", httpserver.Addr)
	//ListenAndServeTLS for https
	if err := httpserver.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		fmt.Fprintf(os.Stderr, "error listen and serve: %v\n", err)
	}
}

// Static. To be run concurrently for intercepting a SIGINT and shutdown gracefully
func gracefulShutdown(wg *sync.WaitGroup, ctx context.Context, httpserver *http.Server) {
	defer wg.Done()
	<-ctx.Done()

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := httpserver.Shutdown(shutdownCtx); err != nil {
		fmt.Fprintf(os.Stderr, "error shutting down server: %v\n", err)
	}
	log.Println("server shut down gracefully")

}

// Runs the server on port 8080 and on a new goroutine
func RunServer() {
	srv := NewServer()
	httpserver := &http.Server{
		Handler: srv, Addr: ":8080",
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	go serverListen(httpserver)

	//TODO: Måste denna vara i en separat thread?
	var wg sync.WaitGroup
	wg.Add(1)

	go gracefulShutdown(&wg, ctx, httpserver)

	wg.Wait()
}
