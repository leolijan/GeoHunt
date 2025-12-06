package middleware


import (
	"context"
	"fmt"
	"net/http"

	db "GeoHunt/server/database"

)

// Returns a HTTP handler that checks if the Authorization header of the HTTP request
// contains a valid firebase token
//
// On successful authentication the context contains the UID of the user 
// who sent the request in the "uid" key.
//
// Otherwise the the user gets the following headers written in the following cases
// 401: Missing Authorization header
// 403: Verification of the token fails
func AuthenticationHandler(handler http.Handler) http.Handler {
    app, err := db.InitializeFirebaseApp() 
    if err != nil {
        fmt.Println("Error initializing Firebase app:", err)
        return nil
    }
    
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        authHeader := r.Header.Get("Authorization")
        if authHeader == "" {
            fmt.Println("Failed to authorize: missing Authorization header")
            w.WriteHeader(http.StatusUnauthorized)
            return
        }

        // Remove "Bearer " prefix if present
        const bearerPrefix = "Bearer "
        var idToken string
        if len(authHeader) > len(bearerPrefix) && authHeader[:len(bearerPrefix)] == bearerPrefix {
            idToken = authHeader[len(bearerPrefix):]
        } else {
            idToken = authHeader
        }

        ctx := r.Context()
        // Remove later: Admin bypass
        if idToken == "admin" {
            ctxWithToken := context.WithValue(ctx, "uid", "admin")
            r = r.WithContext(ctxWithToken)
            handler.ServeHTTP(w, r)
            return
        }

        client, err := app.Auth(ctx)
        if err != nil {
            fmt.Println("Error getting Auth client:", err)
            w.WriteHeader(http.StatusUnauthorized)
            return
        }
        
        token, err := client.VerifyIDToken(ctx, idToken)
        if err != nil {
            fmt.Println("Error verifying ID token:", err)
            w.WriteHeader(http.StatusForbidden)
            return
        }
        
        ctxWithToken := context.WithValue(ctx, "uid", token.UID)
        r = r.WithContext(ctxWithToken)

        handler.ServeHTTP(w, r)
    })
}
