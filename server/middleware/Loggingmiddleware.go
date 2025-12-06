package middleware

import (
	"net/http"
	"time"
	"log"

)

type CustomResponseWriter struct {
	http.ResponseWriter
	StatusCode int
	Size	   int
}

func (crw *CustomResponseWriter) WriteHeader(code int) {
	crw.StatusCode = code
	crw.ResponseWriter.WriteHeader(code)
}

func (crw *CustomResponseWriter) Write(data []byte) (int, error) {
	size, err := crw.ResponseWriter.Write(data)
	crw.Size += size
	return size, err
}

// Returns a HTTP handler that logs details about each HTTP request and response.
//
// The middleware logs the following information:
//
// - Date and time of the request
//
// - HTTP status code of the response, with color-coded output based on the status range
//
// - HTTP method of the request, with color-coded output
//
// - Request URI
//
// - Client's IP address
//
// - Time taken to process the request in nanoseconds
func LoggingMiddleware(handler http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		reset := "\033[0m"

		startTime := time.Now()
		
		crw := &CustomResponseWriter{ResponseWriter: w, StatusCode: http.StatusOK}
		
		handler.ServeHTTP(crw, r)

		duration := time.Since(startTime)

		httpStatus := crw.StatusCode
		httpColor := getStatusColor(httpStatus)
		methodColor := getMethodColor(r.Method)

		log.Printf("\nStatus: %s%d%s | %s%s%s %s | Client address: %s%s%s | Time taken: %d ns\n", 
			httpColor, httpStatus, reset,	
			methodColor, r.Method, reset, 
			r.RequestURI,
			reset, r.RemoteAddr , reset,
			duration.Nanoseconds(),
		)
	})
}

// Static. Helper address for LoggingMiddleware() that returns a color based on
// a given HTTP status code 
func getStatusColor(httpStatus int) string {
	//color codes
	greenBG := "\033[42m"
	yellowBG := "\033[43m"
	redBG := "\033[41m"
	reset := "\033[0m"

	if httpStatus >= 200 && httpStatus < 300 {
		return greenBG
	} else if httpStatus >= 400 && httpStatus < 500 {
		return yellowBG
	} else if httpStatus >= 500 {
		return redBG
	}
	return reset
}

// Static. Helper address for LoggingMiddleware() that returns a color based on
// a given HTTP method 
func getMethodColor(method string) string {
	//color codes
	greenBG := "\033[42m"
	yellowBG := "\033[43m"
	redBG := "\033[41m"
	reset := "\033[0m"

	if method == "GET" {
		return greenBG
	} else if method == "POST" {
		return yellowBG
	} else if method == "PUT" {
		return yellowBG
	} else if method == "DELETE" {
		return redBG
	} else {
		return reset
	}
}