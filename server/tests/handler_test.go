package tests

import (
	"GeoHunt/server/server"
	"encoding/json"
	"fmt"
	"net/http"
	"testing"
	"time"
)

var timeout time.Duration = 5 * time.Second

// Pings the server until its ready. If not done tests may run
// when server isn't running.
func waitForServer(url string, timeout time.Duration) error {
	start := time.Now()
	for {
		// Try to make a request to the server
		resp, err := http.Get(url)
		if err == nil {
			resp.Body.Close()
			return nil // Server is ready
		}

		// Check if we've exceeded the timeout
		if time.Since(start) > timeout {
			return err // Return the last error
		}

		// Wait briefly before retrying
		time.Sleep(100 * time.Millisecond)
	}
}

func sendRequestAsAdmin(t *testing.T,url string, method string) *http.Response {
	client := &http.Client{}
		req, err := http.NewRequest(method, url, nil)
		if err != nil {
			t.Errorf("got error: %v", err)
		}

		req.Header.Add("Authorization", "admin")

		got, err := client.Do(req)
		if err != nil {
			t.Errorf("got error: %v", err)
		}
		return got
}

func TestNoHandler(t *testing.T) {
	go server.RunServer()
	waitForServer("http://localhost:8080/", timeout)

	t.Run("Authorized", func(t *testing.T) {
		got := sendRequestAsAdmin(t, "http://localhost:8080/", "GET")

		expected := http.StatusNotFound

		if got.StatusCode != expected {
			t.Errorf("got %v want %v", got.StatusCode, expected)
		}

	})
	t.Run("Unauthorized", func(t *testing.T) {
		client := &http.Client{}
		req, err := http.NewRequest("GET", "http://localhost:8080/", nil)
		if err != nil {
			t.Errorf("got error: %v", err)
		}

		req.Header.Add("Authorization", "not admin")

		got, err := client.Do(req)
		if err != nil {
			t.Errorf("got error: %v", err)
		}

		expected := http.StatusForbidden

		if got.StatusCode != expected {
			t.Errorf("got %v want %v", got.StatusCode, expected)
		}

	})
}

// TODO: Login before generating game and guessing
func TestGenerateGameAndGuessLocation(t *testing.T) {
	go server.RunServer()
	client := &http.Client{}

	waitForServer("http://localhost:8080/", timeout)

	t.Run("Login", func(t *testing.T) {
		got  :=  sendRequestAsAdmin(t, "http://localhost:8080/Login", "POST")

		var gotJsn map[string]interface{}
		json.NewDecoder(got.Body).Decode(&gotJsn)

		var expected float64 = 0

		result, ok :=gotJsn["Points"].(float64)
		if !ok {
			t.Errorf("Not ok")
		}

		if result != expected {
			t.Errorf("got %v want %v", got.StatusCode, expected)
		}
	})

	t.Run("GenerateGame", func(t *testing.T) {
		req, err := http.NewRequest("GET", "http://localhost:8080/GenerateGame?lat=1&lon=1&rad=1", nil)
		if err != nil {
			t.Errorf("got error: %v", err)
		}

		req.Header.Add("Authorization", "admin")

		got, err := client.Do(req)
		if err != nil {
			t.Errorf("got error: %v", err)
		}

		if got == nil {
			t.Errorf("Didn't get image as response")
		}
	})

	t.Run("GuessLocation", func(t *testing.T) {
		req, err := http.NewRequest("GET", "http://localhost:8080/GuessLocation?lat=1&lon=1", nil)
		if err != nil {
			t.Errorf("got error: %v", err)
		}

		req.Header.Add("Authorization", "admin")

		got, err := client.Do(req)
		if err != nil {
			t.Errorf("got error: %v", err)
		}

		if got == nil {
			t.Errorf("Oh no!")
		}
		fmt.Println(got)
	})
}

//TODO: Add test for checking concurrent requests
