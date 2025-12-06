package server

import (
	db "GeoHunt/server/database"
	utils "GeoHunt/server/utils"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"sync"
	//"time"
)

var toMeters int64 = 1000
var userDataLocks = sync.Map{}
var circle1Scale float64 = 0.65
var circle2Scale float64 = 0.50

func getLockForUser(userId string) *sync.Mutex {
	mu, _ := userDataLocks.LoadOrStore(userId, &sync.Mutex{})
	return mu.(*sync.Mutex)
}

// Static func
func getCoords(r *http.Request) (utils.Coordinate, error) {
	result := utils.Coordinate{}

	lat, err := strconv.ParseFloat(r.URL.Query().Get("lat"), 64)
	if err != nil {
		return result, err
	}
	result.Lat = lat

	lon, err := strconv.ParseFloat(r.URL.Query().Get("lon"), 64)
	if err != nil {
		return result, err
	}
	result.Lon = lon

	return result, nil
}

// Static func for hint system to get distance from user to game coordinate
func getDistance(r *http.Request, gameDataJson map[string]interface{}) (result map[string]interface{}) {
	coords, invalidURI := getCoords(r)
	if invalidURI != nil {
		log.Fatal(invalidURI)
	}

	actualLocation := utils.Coordinate{
		Lat: gameDataJson["Location"].([]interface{})[0].(float64),
		Lon: gameDataJson["Location"].([]interface{})[1].(float64),
	}
	var distance map[string]interface{} = make(map[string]interface{})

	distance["Type"] = "Distance"
	distance["Distance"] = int64(utils.DistanceBetweenCoords(coords, actualLocation) * float64(toMeters))

	return distance
}

// Helper function for generating the circle hint
func getHintCircle(gameDataJson map[string]interface{}, newRadius float64, circleNum string) (newCircleJsn map[string]interface{}, updatedGamedata map[string]interface{}, err error) {
	var POILocation utils.Coordinate
	var middleCircle utils.Circle
	POILocation.Lat = gameDataJson["Location"].([]interface{})[0].(float64)
	POILocation.Lon = gameDataJson["Location"].([]interface{})[1].(float64)
	middleCircle.Coords.Lat = gameDataJson["CurrentCenter"].([]interface{})[0].(float64)
	middleCircle.Coords.Lon = gameDataJson["CurrentCenter"].([]interface{})[1].(float64)
	middleCircle.Rad = gameDataJson["Radius"].(float64)
	

	newCircle, err := utils.GenerateSubCircle(middleCircle, newRadius, POILocation, circleNum)
	if err != nil {
		return nil, nil, err
	}

	gameDataJson["CurrentCenter"].([]interface{})[0] = newCircle["Lat"].(float64)
	gameDataJson["CurrentCenter"].([]interface{})[1] = newCircle["Lon"].(float64)
	gameDataJson["Radius"] = newCircle["Rad"].(float64)

	return newCircle, gameDataJson, nil
}

// TODO: This point system doesn't make any sense
// Static point algorithm
func pointAlgorithm(distanceMeter int64) int64 {
	points := 100 - distanceMeter //arbitrary number
	if points <= 0 {
		return 0
	}
	return points * 10
}

// Handler for generating a users' game. On success responds with the image
// of the randomly generated location based on the users location, being
// located within a given radius (TODO: random generation of location)
//
// Requires that the HTTP request is sent to the URL with the following query parameters:
//
// lat: the latitude of the user
//
// lon: the longitude of the user
//
// rad: radius of the area within which the random location will be generated
func generateGame(w http.ResponseWriter, r *http.Request) {
	coords, err := getCoords(r)
	rad := r.URL.Query().Get("rad")
	if err != nil || rad == "" {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	radAsFloat, err := strconv.ParseFloat(rad, 64)
	if err != nil {
		log.Fatal(err)
	}

	uid := r.Context().Value("uid")
	if uid == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	type StreetViewMetadata struct {
		Location struct {
			Lat float64 `json:"lat"`
			Lng float64 `json:"lng"`
		} `json:"location"`
		Status string `json:"status"`
	}

	client, err := db.AccessFirestoreClient()
	if err != nil {
		log.Fatal(err)
	}

	var jsn map[string]interface{} = make(map[string]interface{})

	//Mutex lock
	mu := getLockForUser(uid.(string))
	mu.Lock()
	defer mu.Unlock() //Unlocks the mutex lock when the handler is done

	userDataJson, err := db.ReadDocument(client, context.Background(), "UserData", uid.(string))
	if err != nil {
		log.Fatal(err)
	} else if userDataJson["CurrentGame"] != "" {
		// Resume game

		gameDataJson, err := db.ReadDocument(client, context.Background(), "GameData", userDataJson["CurrentGame"].(string))
		if err != nil {
			log.Fatal(err)
		}

		jsn["Latitude"] = gameDataJson["Location"].([]interface{})[0].(float64)
		jsn["Longitude"] = gameDataJson["Location"].([]interface{})[1].(float64)

	} else {
		// Generate a new game

		var metadata StreetViewMetadata
		metadata.Status = "ZERO_RESULTS"
		counter := 0

		for {
			if metadata.Status == "OK" || counter > 30 {
				break // Breaks the loop if photo found or if no photos can be found
			} else {
				fmt.Println(metadata.Status)

				radius := 500 // This is just for sensitivity on the google maps API

				// TODO: this random value should be inside radius that user sends as a parameter

				// randomCoords := utils.GenerateRandomCoords(coords, radAsFloat*1000)
				randomCoords, err := utils.GetRandomLocation(coords, radAsFloat)
				if err != nil {
					fmt.Errorf("failed to get random location: %s", err)
				}
				fmt.Println(randomCoords)

				url := fmt.Sprintf("https://maps.googleapis.com/maps/api/streetview/metadata?location=%f,%f&radius=%d&key=AIzaSyDj3hkMFFJMA1I1W8C-MhJZhnzm4ChshiY", randomCoords.Lat, randomCoords.Lon, radius)

				resp, err := http.Get(url)
				if err != nil {
					log.Fatal(err)
				}
				defer resp.Body.Close()
				body, _ := io.ReadAll(resp.Body)

				err = json.Unmarshal(body, &metadata)
				if err != nil {
					log.Fatal(err)
				}

				counter++
			}
		}

		var gameDataJson map[string]interface{} = make(map[string]interface{})
		gameDataJson["Location"] = []interface{}{metadata.Location.Lat, metadata.Location.Lng}
		gameDataJson["Radius"] = radAsFloat
		gameDataJson["HintsTaken"] = 0
		gameDataJson["CurrentCenter"] = []interface{}{coords.Lat, coords.Lon}

		docId, err := db.CreateDocumentRandomId(client, context.Background(), "GameData", gameDataJson)
		if err != nil {
			log.Fatal(err)
		}

		db.UpdateDocument(client, context.Background(), "UserData", uid.(string), map[string]interface{}{
			"CurrentGame": docId,
		})

		jsn["Latitude"] = metadata.Location.Lat
		jsn["Longitude"] = metadata.Location.Lng
	}

	sendBackJsn, err := json.Marshal(&jsn)
	w.Write(sendBackJsn)
}

// Handler for guessing a location through a HTTP request. On success responds with
// a json containing the the points acquired for the guess, the total points and the distance
// between the guessed location and the actual location
//
// Requires that the HTTP request is sent to a URL with the following query parameters:
//
// lat: the latitude of the guessed location
//
// lon: the longitude of the guessed location
func guessLocation(w http.ResponseWriter, r *http.Request) {
	clientLocation, err := getCoords(r)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	uid := r.Context().Value("uid")
	if uid == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	client, err := db.AccessFirestoreClient()
	if err != nil {
		log.Fatal(err)
	}

	//Mutex lock
	mu := getLockForUser(uid.(string))
	mu.Lock()
	defer mu.Unlock() //Unlocks the mutex lock when the handler is done

	//Checks if CurrentGame is a field
	userDataJson, err := db.ReadDocument(client, context.Background(), "UserData", uid.(string))
	if err != nil {
		log.Fatal(err)
	} else if userDataJson["CurrentGame"] == nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	//Reads GameData
	gameDataJson, err := db.ReadDocument(client, context.Background(), "GameData", userDataJson["CurrentGame"].(string))
	if err != nil {
		log.Fatal(err)
	}

	db.DeleteDocument(client, context.Background(), "GameData", userDataJson["CurrentGame"].(string))

	actualLocation := utils.Coordinate{
		Lat: gameDataJson["Location"].([]interface{})[0].(float64),
		Lon: gameDataJson["Location"].([]interface{})[1].(float64),
	}

	fmt.Println(utils.DistanceBetweenCoords(clientLocation, actualLocation))
	distance := utils.DistanceBetweenCoords(clientLocation, actualLocation)
	distanceInMeters := int64(distance * float64(toMeters))
	distanceStr := fmt.Sprintf("%v", distanceInMeters)

	db.UpdateDocument(client, context.Background(), "UserData", uid.(string), map[string]interface{}{
		"CurrentGame": "",
		"Points":      userDataJson["Points"].(int64) + pointAlgorithm(distanceInMeters),
	})

	//Builds a json file to send back to client
	var finishedGameJsn map[string]interface{} = make(map[string]interface{})
	finishedGameJsn["Points"] = pointAlgorithm(distanceInMeters)
	finishedGameJsn["TotalPoints"] = userDataJson["Points"].(int64) + pointAlgorithm(distanceInMeters)
	finishedGameJsn["Distance"] = distanceStr
	// skicka lat och lon för att displaya på kartan
	finishedGameJsn["Latitude"] = actualLocation.Lat
	finishedGameJsn["Longitude"] = actualLocation.Lon
	sendBackJsn, err := json.Marshal(&finishedGameJsn)
	if err != nil {
		log.Fatal(err)
	}

	w.Write(sendBackJsn)

}

// Handler for logging a user in. Makes sure UserData document exists and responds
// with the users points
func login(w http.ResponseWriter, r *http.Request) {
	uid := r.Context().Value("uid")
	if uid == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	client, err := db.AccessFirestoreClient()
	if err != nil {
		log.Fatal(err)
	}

	//Mutex lock
	mu := getLockForUser(uid.(string))
	mu.Lock()
	defer mu.Unlock() //Unlocks the mutex lock when the handler is done

	userDataJson, err := db.ReadDocument(client, context.Background(), "UserData", uid.(string))
	if err != nil {
		db.UpdateDocument(client, context.Background(), "UserData", uid.(string), map[string]interface{}{
			"CurrentGame":    "",
			"Points":         0,
			"Friends":        []string{},
			"FriendRequests": []string{},
		})
	}
	var jsn map[string]interface{} = make(map[string]interface{})
	if userDataJson != nil {
		jsn["Points"] = userDataJson["Points"].(int64)
	} else {
		jsn["Points"] = 0
	}
	sendBackJsn, err := json.Marshal(&jsn)
	if err != nil {
		log.Fatal(err)
	}

	w.Write(sendBackJsn)
}

// Handler for giving up an active game if one exists. In that case the data for the active game is subsequently
// deleted and users total points are sent back.
func giveUp(w http.ResponseWriter, r *http.Request) {
	uid := r.Context().Value("uid")
	if uid == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	client, err := db.AccessFirestoreClient()
	if err != nil {
		log.Fatal(err)
	}

	//Mutex lock
	mu := getLockForUser(uid.(string))
	mu.Lock()
	defer mu.Unlock() //Unlocks the mutex lock when the handler is done

	userDataJson, err := db.ReadDocument(client, context.Background(), "UserData", uid.(string))
	if err != nil {
		log.Fatal(err)
	} else if userDataJson["CurrentGame"] == nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	db.DeleteDocument(client, context.Background(), "GameData", userDataJson["CurrentGame"].(string))

	db.UpdateDocument(client, context.Background(), "UserData", uid.(string), map[string]interface{}{
		"CurrentGame": "",
	})

	var jsn map[string]interface{} = make(map[string]interface{})
	jsn["Points"] = userDataJson["Points"].(int64)
	sendBackJsn, err := json.Marshal(&jsn)
	if err != nil {
		log.Fatal(err)
	}
	w.Write(sendBackJsn)
}

// Handler for updating the leaderboard. On success responds with json containing two field:
//
// "Names": an array with the names for all users on the leaderboard
//
// "Points": an array with the points for each corresponding user in the "Names" array
//
// (Don't need to use mutex lock because it is only reading the userdata and creating a leaderboard array.
//
//	Will in worst case generate a slightly older version of the leaderboard.)
func updateLeaderboard(w http.ResponseWriter, r *http.Request) {
	client, err := db.AccessFirestoreClient()
	if err != nil {
		log.Fatal(err)
	}

	leaderboard, err := db.GetLeaderboard(client, context.Background(), "UserData")
	if err != nil {
		log.Fatal(err)
	}

	length := len(leaderboard)
	newLeaderboardNames := make([]string, length)
	newLeaderboardPoints := make([]int64, length)
	for i := 0; i < length; i++ {
		rawName, exists := leaderboard[i]["DisplayName"]
		if !exists {
			continue
		}

		displayName, ok := rawName.(string)
		if !ok {
			continue
		}

		rawPts, exists := leaderboard[i]["Points"]
		if !exists {
			continue
		}

		pts, ok := rawPts.(int64)
		if !ok {
			continue
		}

		newLeaderboardNames[i] = displayName
		newLeaderboardPoints[i] = pts
	}

	var jsn map[string]interface{} = make(map[string]interface{})
	jsn["Names"] = newLeaderboardNames
	jsn["Points"] = newLeaderboardPoints
	sendBackJsn, err := json.Marshal(&jsn)
	if err != nil {
		log.Fatal(err)
	}
	w.Write(sendBackJsn)
}

// Handler to updating the display name for the corresponding user.
// This requires the name to be unused by all other users.
// In the case where no other user has the given display name
// the users "displayName" field in the database is updated .
//
// Requires that the HTTP request is sent to a URL with the following query parameters:
//
// - name: the new desired display name
func updateDisplayName(w http.ResponseWriter, r *http.Request) {
	displayName := r.URL.Query().Get("name")
	if displayName == "" {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	displayName = strings.ToUpper(displayName)

	uid := r.Context().Value("uid")
	if uid == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	client, err := db.AccessFirestoreClient()
	if err != nil {
		log.Fatal(err)
	}

	//Mutex lock
	mu := getLockForUser(uid.(string))
	mu.Lock()
	defer mu.Unlock() //Unlocks the mutex lock when the handler is done

	userDataId, err := db.ReadDisplayName(client, context.Background(), "UserData", displayName)
	if userDataId == "" {
		updateFailed := db.UpdateDocument(client, context.Background(), "UserData", uid.(string), map[string]interface{}{
			"DisplayName": displayName,
		})
		if updateFailed != nil {
			w.WriteHeader(http.StatusConflict)
		}
		w.Write([]byte("Available"))
	} else {
		w.Write([]byte("Used"))
	}
}

func answerFriendRequest(w http.ResponseWriter, r *http.Request) {
	//kolla om konton finns kvar
	friendName := r.URL.Query().Get("name")
	if friendName == "" {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	friendName = strings.ToUpper(friendName)
	answer := r.URL.Query().Get("ans")
	if answer == "" {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	uid := r.Context().Value("uid")
	if uid == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	client, err := db.AccessFirestoreClient()
	if err != nil {
		log.Fatal(err)
	}

	friendUserDataId, err := db.ReadDisplayName(client, context.Background(), "UserData", friendName)
	if friendUserDataId == "" {
		w.Write([]byte("No player found")) //TODO: better response
	} else {

		//TODO: Can result in deadlock? gets one lock and waits for another.
		//Mutex lock for friend userdata
		mu1 := getLockForUser(friendUserDataId)
		mu1.Lock()
		defer mu1.Unlock() //Unlocks the mutex lock when the handler is done

		friendUserDataJson, err := db.ReadDocument(client, context.Background(), "UserData", friendUserDataId)
		if err != nil {
			log.Fatal(err)
		}

		//Mutex lock for own userdata
		mu2 := getLockForUser(uid.(string))
		mu2.Lock()
		defer mu2.Unlock() //Unlocks the mutex lock when the handler is done

		userDataJson, err := db.ReadDocument(client, context.Background(), "UserData", uid.(string))
		if err != nil {
			log.Fatal(err)
		}

		friendRequests := userDataJson["FriendRequests"].([]interface{})
		var friendRequestsUpdated []string
		valid := false
		for _, req := range friendRequests {
			if req != friendUserDataId {
				friendRequestsUpdated = append(friendRequestsUpdated, req.(string))
			} else {
				valid = true
			}
		}
		if !valid {
			return // If there was no friend request we can't add them and we return here
		}
		if friendRequestsUpdated == nil {
			friendRequestsUpdated = []string{}
		}
		db.UpdateDocument(client, context.Background(), "UserData", uid.(string), map[string]interface{}{
			"FriendRequests": friendRequestsUpdated,
		})

		if answer == "accept" {
			// Add self to friends friendlist
			friendFriendlist := friendUserDataJson["Friends"].([]interface{})
			var friendFriendlistUpdated []string
			for _, friend := range friendFriendlist {
				if friend == uid.(string) {
					return // If we are already friends we don't add them and return here
				}
				friendFriendlistUpdated = append(friendFriendlistUpdated, friend.(string))
			}
			friendFriendlistUpdated = append(friendFriendlistUpdated, uid.(string))
			db.UpdateDocument(client, context.Background(), "UserData", friendUserDataId, map[string]interface{}{
				"Friends": friendFriendlistUpdated,
			})

			// Add friend to own friendlist
			userFriendlist := userDataJson["Friends"].([]interface{})
			var userFriendlistUpdated []string
			for _, friend := range userFriendlist {
				userFriendlistUpdated = append(userFriendlistUpdated, friend.(string))
			}
			userFriendlistUpdated = append(userFriendlistUpdated, friendUserDataId)
			db.UpdateDocument(client, context.Background(), "UserData", uid.(string), map[string]interface{}{
				"Friends": userFriendlistUpdated,
			})
			w.Write([]byte("Friend added")) //TODO: better response
		} else if answer == "reject" {
			w.Write([]byte("Friend not added")) //TODO: better response
		}
	}
}

func sendFriendRequest(w http.ResponseWriter, r *http.Request) {
	friendName := r.URL.Query().Get("name")
	if friendName == "" {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	friendName = strings.ToUpper(friendName)

	uid := r.Context().Value("uid")
	if uid == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	client, err := db.AccessFirestoreClient()
	if err != nil {
		log.Fatal(err)
	}

	friendUserDataId, err := db.ReadDisplayName(client, context.Background(), "UserData", friendName)
	if friendUserDataId == "" {
		w.Write([]byte("No player found"))
	} else if friendUserDataId == uid.(string) {
		w.Write([]byte("Can't add yourself"))
	} else {

		//Mutex lock
		mu := getLockForUser(friendUserDataId)
		mu.Lock()
		defer mu.Unlock() //Unlocks the mutex lock when the handler is done

		friendUserDataJson, err := db.ReadDocument(client, context.Background(), "UserData", friendUserDataId)
		if err != nil {
			log.Fatal(err)
		}
		friendList := friendUserDataJson["Friends"].([]interface{})
		for _, friend := range friendList {
			if friend == uid.(string) {
				w.Write([]byte("Already friends")) //TODO: better response
				return
			}
		}

		friendRequests := friendUserDataJson["FriendRequests"].([]interface{})
		var friendRequestsUpdated []string
		for _, req := range friendRequests {
			if req == uid.(string) {
				w.Write([]byte("Already sent friend request")) //TODO: better response
				return
			}
			friendRequestsUpdated = append(friendRequestsUpdated, req.(string))
		}
		friendRequestsUpdated = append(friendRequestsUpdated, uid.(string))
		db.UpdateDocument(client, context.Background(), "UserData", friendUserDataId, map[string]interface{}{
			"FriendRequests": friendRequestsUpdated,
		})
		w.Write([]byte("Friend request sent")) //TODO: better response
	}
}

// Only uses mutex lock for accessing its own data to make sure it receives the friend requests correctly.
// Doesn't use a mutex lock for searching up the display names of the users that have sent a friend request.
// (Would use a lot of mutex locks and will instead, in worst case, show an old name).
func getFriendRequests(w http.ResponseWriter, r *http.Request) {
	//hämta listan, userData
	uid := r.Context().Value("uid")
	if uid == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	client, err := db.AccessFirestoreClient()
	if err != nil {
		log.Fatal(err)
	}

	//Mutex lock
	mu := getLockForUser(uid.(string))
	mu.Lock()
	defer mu.Unlock() //Unlocks the mutex lock when the handler is done

	userDataJson, err := db.ReadDocument(client, context.Background(), "UserData", uid.(string))
	if err != nil {
		log.Fatal(err)
	}

	FriendRequests := userDataJson["FriendRequests"].([]interface{})

	// Can optimize this and do it in one loop?

	// var FriendRequestsNames []string
	// for _, req := range FriendRequests {
	// 	friendDataJson, err := db.ReadDocument(client, context.Background(), "UserData", req.(string))
	// 	if err == nil {
	// 		FriendRequestsNames = append(FriendRequestsNames, friendDataJson["DisplayName"].(string))
	// 	}
	// }

	var FriendRequestsNames []string
	var pointsList []int64

	for _, req := range FriendRequests {
		friendDataJson, err := db.ReadDocument(client, context.Background(), "UserData", req.(string))
		if err == nil {
			FriendRequestsNames = append(FriendRequestsNames, friendDataJson["DisplayName"].(string))
			pointsList = append(pointsList, friendDataJson["Points"].(int64))
		}
	}

	// To here.

	var jsn map[string]interface{} = make(map[string]interface{})
	jsn["FriendRequests"] = FriendRequestsNames
	jsn["Points"] = pointsList
	sendBackJsn, err := json.Marshal(&jsn)
	w.Write(sendBackJsn)
}

// Only uses mutex lock for accessing its own data to make sure it receives the friend list correctly.
// Doesn't use a mutex lock for searching up the display names of the friends.
// (Would use a lot of mutex locks and will instead, in worst case, show an old name).
func getFriendList(w http.ResponseWriter, r *http.Request) {
	//hämta listan, sparad i userData
	uid := r.Context().Value("uid")
	if uid == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	client, err := db.AccessFirestoreClient()
	if err != nil {
		log.Fatal(err)
	}

	//Mutex lock
	mu := getLockForUser(uid.(string))
	mu.Lock()
	defer mu.Unlock() //Unlocks the mutex lock when the handler is done

	userDataJson, err := db.ReadDocument(client, context.Background(), "UserData", uid.(string))
	if err != nil {
		log.Fatal(err)
	}

	Friends := userDataJson["Friends"].([]interface{})

	// Can also optimize this in the same way?

	// var FriendNames []string
	// for _, req := range Friends {
	// 	friendDataJson, err := db.ReadDocument(client, context.Background(), "UserData", req.(string))
	// 	if err == nil {
	// 		FriendNames = append(FriendNames, friendDataJson["DisplayName"].(string))
	// 	}
	// }

	var FriendNames []string
	var pointsList []int64

	for _, req := range Friends {
		friendDataJson, err := db.ReadDocument(client, context.Background(), "UserData", req.(string))
		if err == nil {
			FriendNames = append(FriendNames, friendDataJson["DisplayName"].(string))
			pointsList = append(pointsList, friendDataJson["Points"].(int64))
		}
	}

	// To here.

	var jsn map[string]interface{} = make(map[string]interface{})
	jsn["Friends"] = FriendNames
	jsn["Points"] = pointsList
	sendBackJsn, err := json.Marshal(&jsn)
	w.Write(sendBackJsn)
}

func removeFriend(w http.ResponseWriter, r *http.Request) {
	friendName := r.URL.Query().Get("name")
	if friendName == "" {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	uid := r.Context().Value("uid")
	if uid == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	client, err := db.AccessFirestoreClient()
	if err != nil {
		log.Fatal(err)
	}

	friendUserDataId, err := db.ReadDisplayName(client, context.Background(), "UserData", friendName)
	if friendUserDataId == "" {
		w.Write([]byte("No player found"))
	} else {
		//Mutex lock for friend userdata
		mu1 := getLockForUser(friendUserDataId)
		mu1.Lock()
		defer mu1.Unlock() //Unlocks the mutex lock when the handler is done

		//Mutex lock for own userdata
		mu2 := getLockForUser(uid.(string))
		mu2.Lock()
		defer mu2.Unlock() //Unlocks the mutex lock when the handler is done

		friendUserDataJson, err := db.ReadDocument(client, context.Background(), "UserData", friendUserDataId)
		if err != nil {
			log.Fatal(err)
		}
		userDataJson, err := db.ReadDocument(client, context.Background(), "UserData", uid.(string))
		if err != nil {
			log.Fatal(err)
		}

		// Remove self from friends friendlist
		friendFriendlist := friendUserDataJson["Friends"].([]interface{})
		var friendFriendlistUpdated []string
		for _, friend := range friendFriendlist {
			if friend != uid.(string) {
				friendFriendlistUpdated = append(friendFriendlistUpdated, friend.(string))
			}
		}
		if friendFriendlistUpdated == nil {
			friendFriendlistUpdated = []string{}
		}
		db.UpdateDocument(client, context.Background(), "UserData", friendUserDataId, map[string]interface{}{
			"Friends": friendFriendlistUpdated,
		})

		// Remove friend from own friendlist
		userFriendlist := userDataJson["Friends"].([]interface{})
		var userFriendlistUpdated []string
		for _, friend := range userFriendlist {
			if friend != friendUserDataId {
				userFriendlistUpdated = append(userFriendlistUpdated, friend.(string))
			}
		}
		if userFriendlistUpdated == nil {
			userFriendlistUpdated = []string{}
		}
		db.UpdateDocument(client, context.Background(), "UserData", uid.(string), map[string]interface{}{
			"Friends": userFriendlistUpdated,
		})
		w.Write([]byte("Friend added")) //TODO: better response
	}
}

// Handler for managing the hint system. On success sends a JSON back with a 'Type' field
// revealing what type of hint is returned. Other fields returned may vary based on what hint is returned
//
// Requires that the HTTP request is sent to a URL with the following query parameters:
//
//	'lat' - latitude float64
//
//	'lon' - longitude float64
//
// Possible fields in JSON:
//
//	Type - 'Distance':
//		'Distance' - number int64
//
//	Type - 'Circle"number"':
//		'Lat' - longitude float64
//		'Lon' - longitude float64
//		'Rad' - radius float64

func getHint(w http.ResponseWriter, r *http.Request) {
	//TODO: check for correct URI

	uid := r.Context().Value("uid")
	if uid == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	//Access firebase
	client, err := db.AccessFirestoreClient()
	if err != nil {
		log.Fatal(err)
	}

	//Read doc for currentgame
	userDataJson, err := db.ReadDocument(client, context.Background(), "UserData", uid.(string))
	if err != nil {
		log.Fatal(err)
	} else if userDataJson["CurrentGame"] == nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	//Reads GameData
	gameDataJson, err := db.ReadDocument(client, context.Background(), "GameData", userDataJson["CurrentGame"].(string))
	if err != nil {
		log.Fatal(err)
	}

	var hintJsn map[string]interface{}
	var updatedGamedata map[string]interface{} = gameDataJson
	var timeoutErr error = nil
	hintsTaken := gameDataJson["HintsTaken"].(int64)

	fmt.Println(hintsTaken)
	switch hintsTaken {
	case 0:
		gameRadius := gameDataJson["Radius"].(float64)
		hintJsn, updatedGamedata, timeoutErr = getHintCircle(gameDataJson, circle1Scale*gameRadius, "Circle1")
	case 1:
		hintJsn = getDistance(r, gameDataJson)
		updatedGamedata = gameDataJson		
	case 2:
		gameRadius := gameDataJson["Radius"].(float64)
		hintJsn, updatedGamedata, timeoutErr = getHintCircle(gameDataJson, circle2Scale*gameRadius, "Circle2")	
	}

	if timeoutErr != nil || hintJsn == nil{
		w.WriteHeader(http.StatusConflict)
		return
	}

	updatedGamedata["HintsTaken"] = (gameDataJson["HintsTaken"]).(int64) + 1
	
	failedUpdate := db.UpdateDocument(client, context.Background(), "GameData", userDataJson["CurrentGame"].(string), updatedGamedata)
	if failedUpdate != nil {
		w.WriteHeader(http.StatusConflict)
		return
	}
	
	sendBackJsn, badJSONerr := json.Marshal(&hintJsn)
	if badJSONerr != nil {
		w.WriteHeader(http.StatusConflict)
		return
	}
	w.Write(sendBackJsn)
}

// // Creates a duel request in the server which the other user then can use to start a game together with
// // (Only started)
// func sendDuelRequest(w http.ResponseWriter, r *http.Request) {
// 	coords, err := getCoords(r)
// 	if err != nil {
// 		log.Fatal(err)
// 	}
// 	friendName := r.URL.Query().Get("name")
// 	if friendName == "" {
// 		w.WriteHeader(http.StatusBadRequest)
// 		return
// 	}
// 	friendName = strings.ToUpper(friendName)

// 	uid := r.Context().Value("uid")
// 	if uid == nil {
// 		w.WriteHeader(http.StatusUnauthorized)
// 		return
// 	}

// 	client, err := db.AccessFirestoreClient()
// 	if err != nil {
// 		log.Fatal(err)
// 	}

// 	friendUserDataId, err := db.ReadDisplayName(client, context.Background(), "UserData", friendName)
// 	if friendUserDataId == "" {
// 		w.Write([]byte("No player found"))
// 	} else if friendUserDataId == uid.(string) {
// 		w.Write([]byte("Can't duel yourself"))
// 	} else {
// 		// Create a new duel in the database

// 		var gameDataJson map[string]interface{} = make(map[string]interface{})
// 		gameDataJson["LocationUser1"] = []interface{}{coords.Lat, coords.Lon}

// 		docId, err := db.CreateDocumentRandomId(client, context.Background(), "GameData", gameDataJson)
// 		if err != nil {
// 			log.Fatal(err)
// 		}

// 		db.UpdateDocument(client, context.Background(), "UserData", uid.(string), map[string]interface{}{
// 			"CurrentDuel": docId,
// 		})

// 		db.UpdateDocument(client, context.Background(), "UserData", friendUserDataId, map[string]interface{}{
// 			"CurrentDuel": docId,
// 		})
// 	}
// }

// func acceptDuelRequest(w http.ResponseWriter, r *http.Request) {
// 	coords, err := getCoords(r)
// 	rad := r.URL.Query().Get("rad")
// 	if err != nil || rad == "" {
// 		w.WriteHeader(http.StatusBadRequest)
// 		return
// 	}
// 	radAsFloat, err := strconv.ParseFloat(rad, 64)
// 	if err != nil {
// 		log.Fatal(err)
// 	}

// 	uid := r.Context().Value("uid")
// 	if uid == nil {
// 		w.WriteHeader(http.StatusUnauthorized)
// 		return
// 	}

// 	client, err := db.AccessFirestoreClient()
// 	if err != nil {
// 		log.Fatal(err)
// 	}

// 	userDataJson, err := db.ReadDocument(client, context.Background(), "UserData", uid.(string))
// 	if err != nil {
// 		log.Fatal(err)
// 	} else if userDataJson["CurrentDuel"] == nil {
// 		w.Write([]byte("No duel found"))
// 		return
// 	}

// 	gameDataJson, err := db.ReadDocument(client, context.Background(), "GameData", userDataJson["CurrentDuel"].(string))
// 	if err != nil {
// 		log.Fatal(err)
// 	}

// 	type StreetViewMetadata struct {
// 		Location struct {
// 			Lat float64 `json:"lat"`
// 			Lng float64 `json:"lng"`
// 		} `json:"location"`
// 		Status string `json:"status"`
// 	}

// 	var jsn map[string]interface{} = make(map[string]interface{})
// 	var Location utils.Coordinate

// 	// Use location in between user1 and user2
// 	Location.Lat = (gameDataJson["LocationUser1"].([]interface{})[0].(float64) + coords.Lat) / 2
// 	Location.Lon = (gameDataJson["LocationUser1"].([]interface{})[1].(float64) + coords.Lon) / 2

// 	// Generate a new game

// 	var metadata StreetViewMetadata
// 	metadata.Status = "ZERO_RESULTS"
// 	counter := 0

// 	for {
// 		if metadata.Status == "OK" || counter > 30 {
// 			break // Breaks the loop if photo found or if no photos can be found
// 		} else {
// 			fmt.Println(metadata.Status)

// 			radius := 500 // This is just for sensitivity on the google maps API

// 			// TODO: this random value should be inside radius that user sends as a parameter

// 			// randomCoords := utils.GenerateRandomCoords(coords, radAsFloat*1000)
// 			randomCoords, err := utils.GetRandomLocation(Location, radAsFloat)
// 			if err != nil {
// 				fmt.Errorf("failed to get random location: %s", err)
// 			}
// 			fmt.Println(randomCoords)

// 			url := fmt.Sprintf("https://maps.googleapis.com/maps/api/streetview/metadata?location=%f,%f&radius=%d&key=AIzaSyDj3hkMFFJMA1I1W8C-MhJZhnzm4ChshiY", randomCoords.Lat, randomCoords.Lon, radius)

// 			resp, err := http.Get(url)
// 			if err != nil {
// 				log.Fatal(err)
// 			}
// 			defer resp.Body.Close()
// 			body, _ := io.ReadAll(resp.Body)

// 			err = json.Unmarshal(body, &metadata)
// 			if err != nil {
// 				log.Fatal(err)
// 			}

// 			counter++
// 		}
// 	}

// 	//var gameDataJson map[string]interface{} = make(map[string]interface{})
// 	gameDataJson["Location"] = []interface{}{metadata.Location.Lat, metadata.Location.Lng}
// 	gameDataJson["Radius"] = radAsFloat
// 	//gameDataJson["HintsTaken"] = 0
// 	//gameDataJson["CurrentCenter"] = []interface{}{coords.Lat, coords.Lon}

// 	db.UpdateDocument(client, context.Background(), "GameData", userDataJson["CurrentDuel"].(string), gameDataJson)

// 	jsn["Latitude"] = metadata.Location.Lat
// 	jsn["Longitude"] = metadata.Location.Lng

// 	sendBackJsn, err := json.Marshal(&jsn)
// 	w.Write(sendBackJsn)
// }

// func sendDuelRequest2(w http.ResponseWriter, r *http.Request) {
// 	coords, err := getCoords(r)
// 	if err != nil {
// 		log.Fatal(err)
// 	}

// 	friendName := r.URL.Query().Get("name")
// 	if friendName == "" {
// 		w.WriteHeader(http.StatusBadRequest)
// 		return
// 	}
// 	friendName = strings.ToUpper(friendName)

// 	uid := r.Context().Value("uid")
// 	if uid == nil {
// 		w.WriteHeader(http.StatusUnauthorized)
// 		return
// 	}

// 	client, err := db.AccessFirestoreClient()
// 	if err != nil {
// 		log.Fatal(err)
// 	}

// 	friendUserDataId, err := db.ReadDisplayName(client, context.Background(), "UserData", friendName)
// 	if err != nil {
// 		log.Printf("error reading display name: %s", err)
// 		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
// 		return
// 	}
	
// 	if friendUserDataId == "" {
// 		w.Write([]byte("No player found"))
// 		return
// 	} else if friendUserDataId == uid.(string) {
// 		w.Write([]byte("Can't duel yourself"))
// 		return
// 	} else {
// 		gameDataJson := map[string]interface{}{
// 			"LocationUser1": []interface{}{coords.Lat, coords.Lon},
// 			"Status": "pending",
// 		}

// 		gameID, err := db.CreateDocumentRandomId(client, context.Background(), "GameData", gameDataJson)
// 		if err != nil {
// 			log.Printf("error creating GameData document: %s",err)
// 			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
// 			return
// 		}

// 		// err = db.UpdateDocument(client, context.Background(), "UserData", uid.(string), map[string]interface{}{
// 		// 	"CurrentDuel": gameID,
// 		// })
// 		// if err != nil {
// 		// 	log.Printf("error updating CurrentDuel: ", err)
// 		// 	http.Error(w, "Internal Server Error", http.StatusInternalServerError)
// 		// 	return
// 		// }

// 		// err = db.UpdateDocument(client, context.Background(), "UserData", friendUserDataId, map[string]interface{}{
// 		// 	"CurrentDuel": gameID,
// 		// })
// 		// if err != nil {
// 		// 	log.Printf("error updating CurrentDuel: ", err)
// 		// 	http.Error(w, "Internal Server Error", http.StatusInternalServerError)
// 		// 	return
// 		// }
		
// 		response := awaitDuelResponse(client, gameID)
// 		if response != "accepted" {
// 			log.Printf("Duel not accepted: %s", response)
// 			w.WriteHeader(http.StatusOK)
// 			w.Write([]byte(response))
// 			return
// 		}

// 		w.WriteHeader(http.StatusOK)
// 		w.Write([]byte("accepted"))
// 	}
// }

// func awaitDuelResponse(gameID string) string {
// 	client, err := db.AccessFirestoreClient()
// 	if err != nil {
// 		log.Printf("error: %s", err)
		
// 	}

// 	ctx, cancel := context.WithTimeout(context.Background(), 30 * time.Second)
// 	defer cancel()

// 	ticker := time.NewTicker(time.Second)
// 	defer ticker.Stop()

// 	for {
// 		select {
// 		case <-ctx.Done():
// 			err := db.UpdateDocument(client, context.Background(), "GameData", gameID, map[string]interface{}{
// 				"Status": "expired",
// 			})
// 			if err != nil {
// 				log.Printf("error updating GameData document upon expiration")
// 			}
// 			return "expired"
// 		case <-ticker.C:
// 			gameData, err := db.ReadDocument(client, context.Background(), "GameData", gameID)
// 			if err != nil {
// 				log.Printf("error reading GameData")
// 				continue
// 			}

// 			status, ok := gameData["Status"].(string)
// 			if ok && status == "accepted" {
// 				return "accepted"
// 			} else if ok && status == "rejected" {
// 				return "rejected"
// 			}
// 		}
// 	}
// }

// func awaitDuelRequests(w http.ResponseWriter, r *http.Request) {
// 	uid := r.Context().Value("uid")
// 	if uid == nil {
// 		w.WriteHeader(http.StatusUnauthorized)
// 		return
// 	}

// 	client, err := db.AccessFirestoreClient()
// 	if err != nil {
// 		log.Fatal(err)
// 	}


// }

