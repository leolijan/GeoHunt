package utils

import (
	"encoding/json"
	"fmt"
	"io"
	"math"
	"math/rand"
	"net/http"
	"net/url"
	"time"
)

type Cell struct {
	Key string
	topLeft Coordinate
	bottomRight Coordinate
	center Coordinate
	Weight float64
	cellsize float64
}

type Grid struct {
	grid map[string]Cell
	cellsize float64
	NumCells int64
	TopLeft Coordinate
	center Coordinate
}

type OverpassResponse struct {
	Elements []struct {
		Lat float64 `json:"lat"`
		Lon float64 `json:"lon"`
		Tags map[string]string `json:"tags"`
	} `json:"elements"`
}

// Generates a grid around a circle with a given center, radius and cell size in diameter
func GenerateGrid(center Coordinate, radius float64, cellsize float64) Grid  {
	radius = radius + cellsize / 2
	dLat := kmToLatDegrees(radius)
	dLon :=	kmToLonDegrees(radius, center.Lat)
	cLat := kmToLatDegrees(cellsize)
	cLon := kmToLonDegrees(cellsize, center.Lat)

	origin := Coordinate{
		Lat: center.Lat - dLat + (cLat / 2),
		Lon: center.Lon - dLon + (cLon / 2),
	}

	endpoint := Coordinate{
		Lat: center.Lat + dLat - (cLat / 2),
		Lon: center.Lon + dLon - (cLon / 2),
	}

	grid := make(map[string]Cell)
	var numCells int64 = 0

	
	var row int64 = 0
	dnLat := kmToLatDegrees(cellsize)
	for lat := origin.Lat; lat <= endpoint.Lat; lat += dnLat {
		var col int64 = 0
		for lon := origin.Lon; lon <= endpoint.Lon; lon += kmToLonDegrees(cellsize, lat) {
			cellCenter := Coordinate{
				Lat: lat,
				Lon: lon,
			}
			
			if (InsideRadius(cellCenter, center, radius)) {
				key := fmt.Sprintf("%d_%d", row, col)
				newCell := createCell(cellCenter, cellsize, key)
				grid[key] = newCell
				
				numCells++
			}
			col++
		}
		row++
	}

	newGrid := Grid{
		grid: grid,
		cellsize: cellsize,
		NumCells: numCells,
		TopLeft: Coordinate{Lat: origin.Lat, Lon: origin.Lon,},
		center: Coordinate{Lat: center.Lat, Lon: center.Lon},
	}
	return newGrid
}

// Helper function to create a cell
func createCell(center Coordinate, cellsize float64, key string) Cell {
	dLat := kmToLatDegrees(cellsize / 2)
	dLon := kmToLonDegrees(cellsize / 2, center.Lat)

	topLeft := Coordinate{
		Lat: center.Lat + dLat,
		Lon: center.Lon - dLon,
	}

	bottomRight := Coordinate{
		Lat: center.Lat - dLat,
		Lon: center.Lon + dLon,
	}

	return Cell{
		topLeft: topLeft,
		bottomRight: bottomRight,
		center: center,
		Weight: 0.0,
		Key: key,
		cellsize: cellsize,
	}
}

// Checks if a coordinate is inside the radius of a circle
func InsideRadius(location Coordinate, center Coordinate, radius float64) bool {
	return DistanceBetweenCoords(location, center) <= radius 
}

// Checks if a given coordinate is inside a geographical box
func insideBox(p Coordinate, topLeft Coordinate, bottomRight Coordinate) bool {
	return p.Lat <= topLeft.Lat && p.Lat >= bottomRight.Lat && p.Lon <= topLeft.Lon && p.Lon >= bottomRight.Lon
}

// Fetches a cell from a grid given a coordinate
func CellFromCoords(location Coordinate, grid Grid) (Cell, bool) {
	origin := grid.TopLeft
	cellsize := grid.cellsize

	dLat := kmToLatDegrees(cellsize)
	dLon := kmToLonDegrees(cellsize, origin.Lat)

	row := int64((location.Lat - origin.Lat) / dLat)
	col := int64((location.Lon - origin.Lon) / dLon)

	key := fmt.Sprintf("%d_%d", row, col)
	cell, exists := grid.grid[key]
	return cell, exists
}

// Queries the overpass API with a list of filters and returns a list of coordinates in a circle
func QueryLocations(center Coordinate, radius float64, filters []string) ([]Coordinate, error) {
	query := "[out:json];("
	for _, f := range filters {
		query += fmt.Sprintf(`node(around:%f,%f,%f)[%s];`, radius * 1000, center.Lat, center.Lon, f)
	}
	query += ");out;"

	urlstr := "https://overpass-api.de/api/interpreter?data=" + url.QueryEscape(query)

	resp, err := http.Get(urlstr)
	if err != nil {
		return nil, err
	}

	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)

	var overpassRes OverpassResponse
	err = json.Unmarshal(body, &overpassRes)
	if err != nil {
		fmt.Println("response: ", string(body))
		return nil, err
	}

	var locations []Coordinate
	for _, loc := range overpassRes.Elements {
		locations = append(locations, Coordinate{ Lat: loc.Lat, Lon: loc.Lon, })
	}

	return locations, nil
}

// Gets a random location inside of a circle. Biases places of interest
func GetRandomLocation(center Coordinate, radius float64) (Coordinate, error) {
	filters := []string{
		`amenity=university`,
		`amenity=restaurant`,
		`amenity=cafe`,
		`amenity=school`,
		`amenity=place_of_worship`,
		`shop=mall`,
		`shop=supermarket`,
		`leisure=park`,
		`tourism=museum`,
		`tourism=attraction`,
		`natural=water`,
	}	

	locs, err := QueryLocations(center, radius, filters)
	if err != nil || len(locs) == 0 {
		return Coordinate{}, err
	}

	grid := GenerateGrid(center, radius, 0.05)

	err2 := AssignWeights(grid, locs, 2)
	if err2 != nil {
		return Coordinate{}, err
	}

	cell, err := WeightedSelect(grid)
	if err != nil {
		return Coordinate{}, err
	}

	return selectWithinCell(cell)
}

func selectWithinCell(cell Cell) (Coordinate, error) {
	src := rand.NewSource(time.Now().UnixNano())
	random := rand.New(src)

	size := cell.cellsize

	rLat := kmToLatDegrees(random.Float64() * size)
	rLon := kmToLonDegrees(random.Float64() * size, rLat)


	return Coordinate{
		Lat: cell.topLeft.Lat + rLat,
		Lon: cell.topLeft.Lon + rLon,
	}, nil
}

// Assigns weights to each cell of a grid, biasing cells with more locations
func AssignWeights(grid Grid, locations []Coordinate, locationBias int64) error {
	total := float64(grid.NumCells + (int64(len(locations)) * locationBias))

	// normalize grid
	for _, cell := range grid.grid {
		cell.Weight = 1.0 / total
		key := cell.Key
		grid.grid[key] = cell
	}

	// iterate through locations, add to cell weight
	for _, loc := range locations {
		cell, exists := CellFromCoords(loc, grid)
		if !exists {
			return fmt.Errorf("error: cell doesn't exist")
		}
		cell.Weight += float64(locationBias) / total
		key := cell.Key
		grid.grid[key] = cell
	}

	return nil
}

// Checks that the weights of all cells of a grid add up to 16
func CheckWeights(grid Grid) bool {
	const threshold = 1e-8

	total := float64(0.0)
	for _, cell := range grid.grid {
		total += float64(cell.Weight)
	}
	return math.Abs(total - 1.0) <= threshold
}

func WeightedSelect(grid Grid) (Cell, error) {
	src := rand.NewSource(time.Now().UnixNano())
	random := rand.New(src)

	pointer := random.Float64() // interval [0.0, 1.0]
	if !CheckWeights(grid) {
		return Cell{}, fmt.Errorf("error: weights of grid do not add up to 1")
	}

	cursor := 0.0
	for _, cell := range grid.grid {
		cursor += cell.Weight
		if cursor >= pointer {
			return cell, nil
		}
	}
	return Cell{}, fmt.Errorf("error: should never be reached")
}

