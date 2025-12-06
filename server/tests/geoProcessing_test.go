package tests

import (
	"GeoHunt/server/utils"
	"math/rand"
	"os"
	"testing"
	"time"
)

func TestMain(m *testing.M) {
	rand.New(rand.NewSource(time.Now().UnixNano()))
	os.Exit(m.Run())
}

func TestDistanceBetweenSamePoint(t *testing.T) {
	var firstPoint utils.Coordinate = utils.Coordinate {
		Lat: 10,
		Lon: 10,
	}

	if utils.DistanceBetweenCoords(firstPoint, firstPoint) != 0 {
		t.Errorf("is wrong")
	}
}


func TestDistanceBetweenDifferentPoints(t *testing.T) {
	firstPoint := utils.Coordinate {
		Lat: 10,
		Lon: 10,
	}

	secondPoint := utils.Coordinate {
		Lat: 20,
		Lon: 10,
	}

	if utils.DistanceBetweenCoords(firstPoint, secondPoint) != 1111.9492664455872 {
		t.Errorf("is wrong")
	}
}

func TestGridGeneration(t *testing.T) {
	center := utils.Coordinate {
		Lat: 59.839635,
		Lon: 17.646952,
	}

	cellsize := 0.05

	testGrid := utils.GenerateGrid(center, 1, cellsize)
	if testGrid.NumCells == 0 {
		t.Errorf("numCells == 0")
	}
	// cell := utils.CellFromCoords(center, testGrid)


}

func TestQueryOverpass(t *testing.T) {
	center := utils.Coordinate {
		Lat: 59.839635,
		Lon: 17.646952,
	}

	filters := []string{
		`amenity=university`,
	}
	locs, err := utils.QueryLocations(center, 5, filters)
	if err != nil {
		t.Fatalf("Failed to query Overpass: %v", err)
	}

	if len(locs) == 0 {
		t.Errorf("Expected at least one location, got 0")
	}

	for _, loc := range locs {
		t.Logf("Found location: Lat: %f, Lon: %f", loc.Lat, loc.Lon)
	}
}

func TestRandomLoc(t *testing.T) {
	center := utils.Coordinate {
		Lat: 59.839635,
		Lon: 17.646952,
	}

	grid := utils.GenerateGrid(center, 2, 0.1)
	if grid.NumCells == 0 {
		t.Errorf("grid not generated")
	}
	
	loc, err := utils.GetRandomLocation(center, 2)
	if err != nil {
		t.Errorf("no locations found")
	}
	t.Logf("location: %f, %f", loc.Lat, loc.Lon)

	cell, exists := utils.CellFromCoords(loc, grid)
	if exists == false {
		t.Errorf("cell doesn't exist")
	}
	t.Logf("Weight: %f", cell.Weight)
}

func TestAssignWeights(t *testing.T) {
	center := utils.Coordinate {
		Lat: 59.839635,
		Lon: 17.646952,
	}

	grid := utils.GenerateGrid(center, 2, 0.05)
	if grid.NumCells == 0 {
		t.Errorf("grid generation failed")
	}

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

	locs, err := utils.QueryLocations(center, 2, filters)
	if err != nil {
		t.Fatalf("location query failed")
	}

	utils.AssignWeights(grid, locs, 2)

	check := utils.CheckWeights(grid)
	if check != true {
		
		t.Errorf("Error: weights do not add up to 1")
	}
}

func TestWeightedSelect(t *testing.T) {
	center := utils.Coordinate {
		Lat: 59.839635,
		Lon: 17.646952,
	}

	grid := utils.GenerateGrid(center, 2, 0.05)
	if grid.NumCells == 0 {
		t.Errorf("grid generation failed")
	}

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

	locs, err := utils.QueryLocations(center, 2, filters)
	if err != nil {
		t.Fatalf("location query failed")
	}

	utils.AssignWeights(grid, locs, 2)

	newCell, err := utils.WeightedSelect(grid)
	if err != nil {
		t.Fatalf("weighted select failed")
	}

	t.Logf("Cell: %s; weight: %f", newCell.Key, newCell.Weight)
}