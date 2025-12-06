package utils

import (
	"errors"
	"math"
	"math/rand"
	"time"
)

var earthRadiusKm float64 = 6371 //in km
var timeout uint16 = 50000


type Coordinate struct {
	Lat float64
	Lon float64
}

type Circle struct {
	Coords Coordinate
	Rad float64
}

// Static. Helper function to convert degrees to radians
func degreesToRadians(d float64) float64 {
	return d * math.Pi / 180
}

func kmToLatDegrees(d float64) float64 {
	return d / 110.0
}

func kmToLonDegrees(d float64, lat float64) float64 {
	return d / (111 * math.Cos(degreesToRadians(lat)))
}


// Returns the distance between two given coordinates (Lon/Lat) in km using the Haversine formula
func DistanceBetweenCoords(p1 Coordinate, p2 Coordinate) float64 {

	lat1 := degreesToRadians(p1.Lat)
	lon1 := degreesToRadians(p1.Lon)
	lat2 := degreesToRadians(p2.Lat)
	lon2 := degreesToRadians(p2.Lon)

	diffLat := lat2 - lat1
	diffLon := lon2 - lon1

	a := math.Pow(math.Sin(diffLat/2), 2) + math.Cos(lat1)*math.Cos(lat2)*
		math.Pow(math.Sin(diffLon/2), 2)

	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return c * earthRadiusKm
}

func GenerateRandomCoords(center Coordinate, maxRadiusInMeters float64) Coordinate {
	src := rand.NewSource(time.Now().UnixNano())
	random := rand.New(src)

	maxRadiusInDegrees := maxRadiusInMeters / 111000

	u := random.Float64()
	randomScalar := random.Float64()
	w := maxRadiusInDegrees * math.Sqrt(u)
	randomAngle := 2 * math.Pi * randomScalar
	x := w * math.Cos(randomAngle)
	y := w * math.Sin(randomAngle)

	new_x := x / math.Cos(center.Lat*math.Pi/180)

	return Coordinate{center.Lat + y, center.Lon + new_x}
}


func GenerateSubCircle(centerCircle Circle, hintRadius float64, coordInSubCircle Coordinate, circleNum string) (jsonNotMarshalled map[string]interface{}, err error) {
	for range timeout { //TODO: dont just try shit


		tempCoords := GenerateRandomCoords(centerCircle.Coords, (centerCircle.Rad - hintRadius) * 1000)
		if InsideRadius(tempCoords, coordInSubCircle, hintRadius) {
			var newCircle map[string]interface{} = make(map[string]interface{})
			newCircle["Type"] = circleNum
			newCircle["Lat"] = tempCoords.Lat
			newCircle["Lon"] = tempCoords.Lon
			newCircle["Rad"] = hintRadius

			return newCircle, nil
		}
	}
	return nil, errors.New("failed to generate circle")
}